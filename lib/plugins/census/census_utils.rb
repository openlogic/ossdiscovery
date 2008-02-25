# census_utils.rb
#
# LEGAL NOTICE
# -------------
# 
# OSS Discovery is a tool that finds installed open source software.
#    Copyright (C) 2007 OpenLogic, Inc.
#  
# OSS Discovery is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License version 3 as 
# published by the Free Software Foundation.  
#  
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License version 3 (discovery2-client/license/OSSDiscoveryLicense.txt) 
# for more details.
#  
# You should have received a copy of the GNU Affero General Public License along with this program.  
# If not, see http://www.gnu.org/licenses/
#  
# You can learn more about OSSDiscovery or contact the team at www.ossdiscovery.com.
# You can contact OpenLogic at info@openlogic.com.
#
#--------------------------------------------------------------------------------------------------

require 'erb'
require 'digest/md5'

module CensusUtils
        
  # figure out if SHA256 is available through either the 
  # Ruby 'openssl' module or through Java via JRuby
  begin
    # if we're running under JRuby, we can still make SHA256 work
    require 'java'
    JAVA_SHA256_AVAILABLE = true
  rescue LoadError
    JAVA_SHA256_AVAILABLE = false
  end

  # if we're using Java, use its SHA256.  The pure ruby link or even jruby link with native OpenSSL on 
  # host machine may not work - 0.9.7 doesn't have SHA256 in it for example.  So, don't rely on native
  # openssl if this is running under jruby

  if JAVA_SHA256_AVAILABLE
    RUBY_SHA256_AVAILABLE = false
  else
    begin
      # not all ruby installs and builds contain openssl, so degrade
      # gracefully if it can't be pulled in.
      require 'openssl'

      # this line will throw an uninitialized constant exception for < 0.9.8 openssl since SHA256 doesn't exist in 0.9.7
      OpenSSL::Digest::SHA256.new
      RUBY_SHA256_AVAILABLE = true

    rescue LoadError => e
      RUBY_SHA256_AVAILABLE = false
    end
  end

  # we can use SHA256 if it's available through either Ruby or Java
  SHA256_AVAILABLE = RUBY_SHA256_AVAILABLE || JAVA_SHA256_AVAILABLE


=begin rdoc
  Implement ISO 7064 mod(97,10) check digits to prevent accidental and some
  malicious tampering with data that will be sent to the OSS Census
  collection site.
=end
  def add_check_digits(hex_str)
    hex_str_as_base_10_number = hex_str.hex
    check_number = (98 - ((hex_str_as_base_10_number * 100) % 97)) % 97
    result = hex_str_as_base_10_number.to_s + ("%02d" % check_number)

    # make sure we did it right
    raise "add check digits failed" unless result.to_i % 97 == 1

    # convert the big long decimal string into a shorter hexadecimal string
    result.to_i.to_s(16) #.rjust(34, "0")
  end

=begin rdoc
  Output the report we'll submit to the census.
=end
  def machine_report(destination, packages, client_version, machine_id,
                     directory_count, file_count, sym_link_count,
                     permission_denied_count, files_of_interest_count,
                     start_time, end_time, distro, os_family, os,
		     os_version, machine_architecture, kernel, 
		     production_scan, include_paths, preview_results, census_code,
                     universal_rules_md5, universal_rules_version, geography)
    io = nil
    if (destination == STDOUT) then
      io = STDOUT
    else 
      io = File.new(destination, "w")
    end

    # if SHA256 isn't available, we can't submit to the Census server 
    # because the results would be rejected as invalid
    unless SHA256_AVAILABLE
      message = "OpenSSL 0.9.8 with SHA256 is required in order to properly write machine scan results.\nYour machine is either running a version of OpenSSL that is less than 0.9.8 or you need to install the ruby openssl gem"
      puts(message) unless io == STDOUT
      printf(message, io)
      io.close unless io == STDOUT
      return
    end

    production_scan = false unless production_scan == true

    template = %{
      report_type:             census
      census_plugin_version:   <%= CENSUS_PLUGIN_VERSION %>
      client_version:          <%= client_version %>
      machine_id:              <%= machine_id %>
      directory_count:         <%= directory_count %>
      file_count:              <%= file_count %>
      sym_link_count:          <%= sym_link_count %>
      permission_denied_count: <%= permission_denied_count %>
      files_of_interest:       <%= files_of_interest_count %>
      start_time:              <%= start_time.to_i %>
      end_time:                <%= end_time.to_i %>
      elapsed_time:            <%= end_time - start_time %>
      packages_found_count:    <%= packages.length %>
      distro:                  <%= distro %>
      os_family:               <%= os_family %>
      os:                      <%= os %>
      os_version:              <%= os_version %>
      machine_architecture:    <%= machine_architecture %>
      kernel:                  <%= kernel %>
      ruby_platform:           <%= RUBY_PLATFORM %>
      production_scan:         <%= production_scan %>
      group_code:              <%= census_code %>
      geography:               <%= geography %>
      universal_rules_md5:     <%= universal_rules_md5 %>
      universal_rules_version: <%= universal_rules_version %>
      package,version
      % if packages.length > 0
      %   packages.sort.each do |package|
      %     package.version.split(",").sort.each do |version|
      %       version.gsub!(" ", "")
      %       version.tr!("\0", "")
              <%= package.name %>,<%= version %>
      %     end
      %   end
      % end
    }

    # strip off leading whitespace and compress all other spaces in 
    # the rendered template so it's more efficient for sending
    template = template.gsub(/^\s+/, "").squeeze(" ")
    text = ERB.new(template, 0, "%").result(binding)

    # in RodC's code, the above "\n" was being appended after the integrity check which hoses up the server side computation

    printf(io, "integrity_check: #{create_integrity_check(text,universal_rules_md5)}\n")

    # TODO - when a rogue rule runs afoul and matches too much text on a package, it will blow chunks here
    begin
      printf(io, text )
    rescue Exception => e
      printf(io, "Possible bad rule matching too much text.  Sorry, can't write the machine report\n")
    end
    
    io.close unless io == STDOUT
  
    if preview_results && io != STDOUT
      printf("\nThese are the actual machine scan results from the file, %s, that would be delivered by --deliver-results option\n", destination)
      puts File.new(destination).read
    end
  end

  # create a secure checksum of the results to use as an integrity check
  # on the server side.  Do this by combining the current OpenLogic rules
  # file checksum with a constant to create a secret key.  This secret key
  # is then blended into the results of an SHA256 hash of the file contents
  # to produce a cryptographically strong hash that we can use on the server
  # to make sure the file contents have not been tampered with.  
  # Note that this mechanism can provide only minor defense against a
  # motivated attacker seeking to skew the results of the census.
  
  def create_integrity_check(text,universal_rules_md5)

    secret = universal_rules_md5 + CENSUS_PLUGIN_VERSION_KEY

    if RUBY_SHA256_AVAILABLE
      hmac = OpenSSL::HMAC.new(secret, OpenSSL::Digest::SHA256.new)
      hmac.update(text)
      mac = hmac.to_s
    else # Java
      algorithm = "HmacSHA256"
      key_spec = javax.crypto.spec.SecretKeySpec.new(java.lang.String.new(secret).get_bytes, algorithm)
      hmac = javax.crypto.Mac.get_instance(algorithm)
      hmac.init(key_spec)
      raw_mac = hmac.do_final(java.lang.String.new(text).get_bytes)
      mac = hexify(raw_mac)
    end

    # printf("integrity_text size: #{text.size}\n")
    # printf("mac before adding check digits:\n#{mac}, #{mac.size}\n")

    result = add_check_digits(mac)

    # printf("results: #{result}, #{result.size}\n")

    return result
  end

  # turn a raw array of bytes into a hex string
  def hexify(bytes)
    sb = java.lang.StringBuffer.new
    bytes.each do |it|
      sb.append(java.lang.Integer.to_hex_string(0x00ff & it).rjust(2, "0"))
    end
    sb.to_string
  end

  module_function :add_check_digits
  module_function :create_integrity_check
  module_function :hexify
  module_function :machine_report

end

# TODO technical debt - opening Object like this feels wrong
# The proper solution to this would be to ensure that the methods that are being overridden via the mixin are defined in a Class or Module.

# We have to open class Object here because the method we
# want to alias is defined outside of any class or module and
# is therefore automatically defined on class Object.
class Object
  # change the make_machine_id method to return a machine id
  # with check digits added to prevent accidental and some
  # malicious tampering.
  alias_method :orig_make_machine_id, :make_machine_id
  def make_machine_id(*args)
    CensusUtils.add_check_digits(orig_make_machine_id(*args))
  end
    
  def machine_report(*args)
    CensusUtils.machine_report(*args)
  end
    
end
