# census_plugin.rb
#
# LEGAL NOTICE
# -------------
# 
# OSS Discovery is a tool that finds installed open source software.
#    Copyright (C) 2007-2008 OpenLogic, Inc.
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
require 'integrity'
require "pathname"

class CensusPlugin

  def initialize
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
    unless Integrity.sha256_available?
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

    printf(io, "integrity_check: #{Integrity.create_integrity_check(text,universal_rules_md5,CENSUS_PLUGIN_VERSION_KEY)}\n")

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
end
