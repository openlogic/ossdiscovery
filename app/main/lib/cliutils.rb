# cliutils.rb
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
# You can learn more about OSSDiscovery, report bugs and get the latest versions at www.ossdiscovery.org.
# You can contact the OSS Discovery team at info@ossdiscovery.org.
# You can contact OpenLogic at info@openlogic.com.


# --------------------------------------------------------------------------------------------------
#
#  cliutils.rb contains methods to support CLI command processing and output
#

require 'scan_rules_updater'

require 'base64'   # used for java proxy authentication properties
require 'erb'
require 'fileutils'
require 'find'
require 'net/http'
require 'pp'
require 'rbconfig'
require 'uri'
require 'integrity'
require 'scan_data'

MAX_GEO_NUM = 195

begin
  # if we're running under JRuby use the apache httpclient for https posts
  require 'java'
  require "#{ENV['OSSDISCOVERY_HOME']}/jruby/lib/commons-httpclient-3.1.jar"

  JAVA_HTTPS_AVAILABLE = true

rescue LoadError
  JAVA_HTTPS_AVAILABLE = false
end

# if we're using Java, the Ruby version of HTTPS 
# supplied through OpenSSL won't work, so don't try to use it
if JAVA_HTTPS_AVAILABLE
  RUBY_HTTPS_AVAILABLE = false
else
  begin
    # not all ruby installs and builds contain openssl, so degrade
    # gracefully if https can't be pulled in.
    require 'net/https'
    RUBY_HTTPS_AVAILABLE = true
  rescue LoadError => e
    RUBY_HTTPS_AVAILABLE = false
  end
end


# we can use HTTPS if it's available through either Ruby or Java
HTTPS_AVAILABLE = RUBY_HTTPS_AVAILABLE || JAVA_HTTPS_AVAILABLE

begin
    require 'win32/registry'
    NOT_WINDOWS = false
rescue LoadError
    NOT_WINDOWS = true
end

require 'digest/md5' 

#--------------------------------------------------------------------------------------
# this will suppress Ruby warnings on machines that have world writable directories.
# common on Solaris machines we've seen
$VERBOSE = nil


#----------------------------------------- CLI help methods -------------------------------------------------

=begin rdoc
    dumps the discovery CLI usage statements
=end

def help()

  # TODO - refactor help
  # normally, the scripts that launch the app will dump the --help text direct from a file
  # so that the ruby or jvm/jruby runtimes don't have to get involved to get quick help

  # this is here if the script is called directly with ruby from the cli and not through one
  # of the wrappers

  # read and dump the help.txt file for the app
  puts File.new("#{ENV['OSSDISCOVERY_HOME']}/help.txt","r").read

  # read and dump the help.txt file for each of the plugins if the plugin is enabled

end

=begin rdoc
    returns a standard version string to use throughout discovery    
=end

def version
  return @discovery_name + " v" + @discovery_version
end

=begin rdoc
    dumps the audit report to the console in the form of simple ASCII text
=end

def report_audit_records( records )
  io = nil
  if (@results == STDOUT) then
    io = STDOUT
  else 
    io = File.new(@results, "a")
  end
  
  r_strings = Array.new
  records.each {|r| r_strings << r.to_s}
  r_strings.sort!
  printf(io, "##### Audit Info ###############################################################\n")
  audit_info = RuleAnalyzer.analyze_audit_records(records)
  if (audit_info.nil? or audit_info.size == 0) then
    printf(io, "no audit info\n")
  else
    audit_info.each_pair {|file, versions| printf(io, "Unique file (#{file}) produced multiple version matches: #{versions.inspect}\n")}
  end
  printf(io, "##### Raw Audit Data ###########################################################\n")
  r_strings.each {|r| printf(io, r.to_s + "\n")}
  
  if (io != STDOUT) then io.close end
end


=begin rdoc
  returns true or false. if the speed argument is valid, it returns true, otherwise false
=end

def validate_speed( speedarg )
  
  if ( speedarg == "1" || speedarg == "2" || speedarg == "3" )
    return true
  end  
  
  return false
end

=begin rdoc
  normalize path will take a given path and if there are backslashes in it (windows cases), they will be 
  transformed to for
=end

def normalize_path!( thepath )
  # thepath.gsub!("\\",'/')
  
  return File.expand_path( thepath )
end


=begin rdoc
  get the major platform on which this instance of the app is running.  possible return values are:
  linux, solaris, windows, macosx
=end

def major_platform()
  case
  when ( RUBY_PLATFORM =~ /linux/ )    # ie: x86_64-linux
    return "linux"
  when ( RUBY_PLATFORM =~ /solaris/ )  # ie: sparc-solaris2.8
    return "solaris"
  when ( RUBY_PLATFORM =~ /mswin/ )    # ie: i386-mswin32
    return "windows"
  when ( RUBY_PLATFORM =~ /darwin/ )   # ie: powerpc-darwin8.10.0
    return "macosx"
  when ( RUBY_PLATFORM =~ /cygwin/ )
    return "cygwin"    
  when ( RUBY_PLATFORM =~ /freebsd/ )
    return "freebsd"
  when ( RUBY_PLATFORM =~ /java/ )     # JRuby returns java regardless of platform so we need to turn this into a real platform string

    # DEBUG
    # pp RbConfig::CONFIG

    case 
    when RbConfig::CONFIG['host_os'] == "Mac OS X" || RbConfig::CONFIG['host_os'] == "darwin" 
      # "host_os"=>"Mac OS X",
      return "macosx"

    when RbConfig::CONFIG['host_os'].match("inux")
      # "host_os"=>"Linux",  # some platforms return "linux" others "Linux"
      return "linux"      

    when RbConfig::CONFIG['host_os'].match("Windows")
      return "jruby-windows"

    when RbConfig::CONFIG['host_os'].match("SunOS")
      return "solaris"

    when RbConfig::CONFIG['host_os'].downcase.include?('freebsd')
      return "freebsd"

    end

  end
end


=begin rdoc
  this method dumps the set of inclusion and exclusion filters out to the console
=end

def dump_filters()
  
  # dumps the contents of the inclusion and exclusion filters

  printf("\nExcluded files and directories filters:\n")
  @dir_exclusion_filters.each{ | description, filter |
    printf("%-25s: %s\n", description, filter)
    }

  @file_exclusion_filters.each{ | description, filter |
    printf("%-25s: %s\n", description, filter)
    }
    
  printf("\n")
end

=begin rdoc
  this method takes a result set and a hash of key/value pairs to override in the file, then replaces them and 
  recalculates the integrity check
=end

def apply_override(results, overrides, version_key)

  if Integrity.verify_integrity_check(results, version_key)
    #Now let's override various parts of the results file and recalculate the integrity check
    
    overrides.each do |key, value|
      results=results.sub(/#{key}:.*/,"#{key}: #{value}")
    end
   
    #Get rid of the existing check
    results=results.sub(/\n*integrity_check:.*\n/,"")
    universal_rules_md5 = results.match(/universal_rules_md5:\s*(.*)/)[1]
    integrity_check=Integrity.create_integrity_check(results, universal_rules_md5, version_key )
    results="integrity_check: #{integrity_check}\n#{results}"
  else
    puts "Tried to override results value but original integrity check was invalid"
    exit 0
  end
end



=begin rdoc
  this method posts the machine scan results back to the discovery server using the Net classes in stdlib
  
  good reference:  http://www.ruby-doc.org/stdlib/libdoc/net/http/rdoc/classes/Net/HTTP.html
=end

def deliver_results( aPlugin, optional_filename = nil, overrides={} )


  puts "DEBUG - aPlugin: #{aPlugin.class}"

  if ( optional_filename != nil )
    printf("\nPosting results file, #{optional_filename}, to: %s ...please wait\n", aPlugin.destination_server_url )
    results = File.new( optional_filename ).read
  else
    # take the file to deliver from the given plugin
    printf("\nPosting results file, #{aPlugin.machine_report_filename()}, to: %s ...please wait\n", aPlugin.destination_server_url )
    results = File.new( aPlugin.machine_report_filename ).read
  end
  
  if overrides != nil && overrides.size > 0
   results=apply_override(results,overrides, aPlugin.plugin_version() )
  end
  
  begin

    if not aPlugin.destination_server_url.match("^https:")
      # The Open Source Census doesn't allow sending via regular HTTP for security reasons unless explicitly given the override

      if aPlugin.override_https == nil || aPlugin.override_https == false
        puts "For security reasons,  #{aPlugin.class} requires HTTPS."
        puts "Please update the value of destination_server_url in plugin's config.yml to the proper HTTPS URL."

        return
      else
        # if the delivery URL is not HTTPS, use this simple form of posting scan results    
        # Since Net::HTTP.Proxy returns Net::HTTP itself when proxy_addr is nil, there‘s no need to change code if there‘s proxy or not.

        if ( aPlugin.override_https != nil && aPlugin.override_https )
          puts "WARNING:  The HTTPS delivery restriction is currently being overridden for ease-of-test purposes" 
        end

        response = Net::HTTP.Proxy( aPlugin.proxy_host, aPlugin.proxy_port, aPlugin.proxy_user, aPlugin.proxy_password ).post_form(URI.parse(aPlugin.destination_server_url),
                                  {'scan[scan_results]' => results} )

        response_headers = response.to_hash()
        response_headers["status"] = "#{response.class} #{response.code}"
      end

    elsif HTTPS_AVAILABLE
      # otherwise, the delivery URL is HTTPS and SSL is available
      
      # TODO - HTTPS in pure ruby will not yet work through a proxy - all HTTPS deliveries must be direct for now in that case
      # or the delivery URL must be explicitly changed to be HTTP only to use a proxy
      
      # parse the delivery url for hostname/IP, port if one is given, otherwise default to 443 for ssl
      # irb(main):006:0> URI.split("https://192.168.10.211:443/cgi-bin/scanpost.rb?test=this")
      # => ["https", nil, "192.168.10.211", "443", nil, "/cgi-bin/scanpost.rb", nil, "test=this", nil]
      
      parts = URI.split(aPlugin.destination_server_url)
      protocol = parts[0]
      host = parts[2]
      port = parts[3]
      path = parts[5]
      
      if port == nil
        port = 443
      else
        port = port.to_i
      end
      
      if port <= 0
        printf("Invalid delivery URL - bad port number")
        port = 80
      end
      
      if !JAVA_HTTPS_AVAILABLE && RUBY_HTTPS_AVAILABLE

        # TODO - HTTPS will not yet work through a proxy when using ruby's Net classes - all HTTPS deliveries must be direct for now
	      # TODO - tell override option to use HTTP instead of HTTPS

        if ( aPlugin.proxy_host != nil )
           puts "HTTPS posts through a proxy is not supported when running under the Ruby Net classes.  Try JRuby instead"
           return
        else
          http = Net::HTTP.new(host, port)
          http.use_ssl = true
          headers = { "Content-Type" => "application/x-www-form-urlencoded" }
          response = http.request_post( path, "scan[scan_results]=#{results}", headers)

          response_headers = response.to_hash()
          response_headers["status"] = "#{response.class} #{response.code}"
        end

      else # do it the Java way because for HTTPS through a proxy this will work in addition to the standard HTTPS post

        client = org.apache.commons.httpclient.HttpClient.new
        post = org.apache.commons.httpclient.methods.PostMethod.new( aPlugin.destination_server_url )
        post.set_do_authentication( true )
        # post method created

        if ( aPlugin.proxy_host != nil )
           # setting up proxy
           client.get_host_configuration().set_proxy( aPlugin.proxy_host, aPlugin.proxy_port)
           scope = Java::OrgApacheCommonsHttpclientAuth::AuthScope::ANY
           
           # it's necessary to change the authentication scheme preference so that NTLM is not the first choice...
           # users have experiences issues because NTLM is the first priority of HttpClient by default and if it fails
           # it bails.   In those environments, it was found that often the proxy will support additional authentication
           # schemes such as BASIC and DIGEST.  Trying those before NTLM often solves the issue
           
           authPrefs = java.util.ArrayList.new
           authPrefs.add(Java::OrgApacheCommonsHttpclientAuth::AuthPolicy::BASIC)
           authPrefs.add(Java::OrgApacheCommonsHttpclientAuth::AuthPolicy::DIGEST)
           authPrefs.add(Java::OrgApacheCommonsHttpclientAuth::AuthPolicy::NTLM) 
           
           client.get_params().set_parameter( Java::OrgApacheCommonsHttpclientAuth::AuthPolicy::AUTH_SCHEME_PRIORITY, authPrefs)
           
           if ( aPlugin.proxy_user != nil && aPlugin.proxy_password != nil )
              # since NTCredentials derives from standard username password credentials, it works for other authentication schemes like BASIC
              #
              credentials = org.apache.commons.httpclient.NTCredentials.new( aPlugin.proxy_user, 
                                                                             aPlugin.proxy_password, 
                                                                             Socket.gethostname , 
                                                                             aPlugin.proxy_ntlm_domain )
              client.get_state().set_proxy_credentials( scope, credentials ) 
              # proxy credentials created
           end
        end

        # create post data

        # it was not obvious how to pass a typed array from JRuby to Java without getting the TypeError exception.
        # this is how to pass a typed array in JRuby.  make an array, then do a to_java passing the class name of the
        # array type.  - ljc

        post_data = [ org.apache.commons.httpclient.NameValuePair.new("scan[scan_results]", "#{results}") ]

        # post request
        post.set_request_body( post_data.to_java( org.apache.commons.httpclient.NameValuePair) )

        client.executeMethod( post )

        # get response
        response_line = post.get_status_line()

        # DEBUG 
        # puts response_line   # HTTP/1.1 200 OK
        # puts post.get_response_header("disco")

        # pull the disco status header from the response 
        disco_status = post.get_response_header("disco").to_s
        disco_status.gsub!("disco: ", "")   # strip the disco: string to match how pure ruby headers work
      	response = { "disco" =>  disco_status.strip }

        response_headers = Hash.new
        response_status = response_line.to_s
        response_status.gsub!('HTTP/1.1 ','')
        response_headers["status"] = response_status   # just leave 200 OK like Net:HTTP of pure ruby
        response_headers["disco"] = disco_status.strip  

        # release the method connection
        post.release_connection()
      end
    else 
      puts("Can't submit scan results to secure server: #{aPlugin.destination_server_url} because we can't find OpenSSL and we're not running in JRuby")
      response = { "disco" => "0, OpenSSL not found" }
    end
 
    # homogenize JRuby/java.net and Ruby Net::HTTP responses into a response header hash
    if ( !response_headers["status"].to_s.match("200") )
      printf("Error submitting the scan results\n")
      response["disco"] = "0, Bad response from server while posting results. #{response_headers['status']}"
    end

  rescue Errno::ECONNREFUSED, Errno::EBADF, OpenSSL::SSL::SSLError, Timeout::Error, Errno::EHOSTUNREACH
    printf("Can't submit scan. The connection was refused or server did not respond when trying to deliver the scan results.\nPlease check your network connection or contact the administrator for the server at: %s\n", @destination_server_url )
    printf("\nYour machine readable results can be found in the file: %s\n", aPlugin.machine_report_filename )
    response = Hash.new
    response["disco"] = "0, Connection Refused or Server did not respond"
  rescue Exception => e
    printf("Error: #{e.to_s}\n")
  end
  
  # by now there should be a response["disco"] header.  If not, then the request was sent to a non-discovery
  # server
  
  if ( response == nil )
    response = Hash.new
  end

  if ( response["disco"] == nil )
    response["disco"] = "0, Improper or unexpected destination server response.  Check your destination URL to make sure it's correct"    
  end
   
  if ( response["disco"].match("^100") )  # look for success code from discovery server
    printf("Result: Success! View reports at #{aPlugin.viewing_url}\n") 
    return true
  else
    printf("Result: %s\n", response["disco"].gsub(/^[0-9]+, /, "") )
    if (response["disco"].include?('not eligible for being discovered')) then
      printf("\nThis error can likely be resolved by updating your project rules.\nTo do this, run discovery with the '--update-rules' option, then perform the scan again and re-deliver the results.\n")
    end
    return false
  end 

end


=begin rdoc
  given a directory of scan results, pick off scans and deliver them
=end

# --------- TODO - refactor in terms of plugin architecture
# plugins are to be built so that they can determine if the file is a report type they "own" and should send
# otherwise they just pass

def deliver_batch( result_directory )
  
  failed_deliveries = []

  Find.find( result_directory ) do | results_fname |

    #printf("results fname: #{results_fname}\n")

    begin
      case
        when File.file?( results_fname )

          # do some basic validation test by spot checking for a couple of fields that are
          # expected to be in a valid results file
          results_content = File.new( results_fname, "r" ).read 

          if ( results_content.match('^report_type: census') == nil ||
               results_content.match('^permission_denied_count:') == nil||
               results_content.match('^distro:') == nil  ||
               results_content.match('^os_family:') == nil ||
               results_content.match('^integrity_check:') == nil 
             )
            printf("Invalid results file #{results_fname}, not sent\n")
            next
          end # of if

          # TODO - refactor

          @plugins_list.each do | plugin_name, aPlugin |
            puts plugin_name   		
            success = aPlugin.send_file( results_fname )
            if (!success) then
              failed_deliveries << File.expand_path(results_fname)
            end
          end
      end # of case
    rescue Errno::EACCES, Errno::EPERM
      puts "Cannot access #{results_fname}\n" 
    end
  end
  
  if (failed_deliveries.size > 0) then
    dirname = File.join(ENV['OSSDISCOVERY_HOME'], "failed_census_deliveries", ScanRulesUpdater.get_YYYYMMDD_HHMM_str)
    FileUtils.mkdir_p(dirname)
    FileUtils.cp(failed_deliveries, dirname)
    msg =  "\nFailed to deliver #{failed_deliveries.size} scan(s) as part of the batch submission.\n" 
    msg << "To resubmit these failures, please perform this operation\n"
    msg << "again, providing this directory as an argument: \n"
    msg << "    #{dirname}\n"
    puts msg
  end
  

end

=begin rdoc
  this code is responsible for generating a unique and static machine id
=end
def make_machine_id

  # allow plugins to supply machine id instead of the default - first plugin to have make_machine_id wins
  @plugins_list.each do | plugin_name, aPlugin |
    if (aPlugin.respond_to?( :make_machine_id, false ) )
      return aPlugin.make_machine_id
    end
  end

  # otherwise, no plugin supplies machine_id, so do the normal machine id generation
  # for non-windows machines, everything else is u*ix like and should support uname
  platform = major_platform
  
  case platform
  when "windows", "jruby-windows"     
    Integrity.iso7064( make_windows_machine_id )
  else  # every other platform including cygwin supports uname -a
    Integrity.iso7064( make_uname_based_machine_id( platform ) )
  end
end

=begin rdoc
  creates a machine id from hostname, ipaddress, mac address and distro
  assumes callers of this know this is a windows machine
  return a hashed machine id composed of only hostname, IP address, and distro string
=end
def make_windows_machine_id

  hostname = Socket.gethostname
  ipaddr = IPSocket.getaddress(hostname)

  # assumes callers of this know this is a windows machine
  ipconfig = `ipconfig /all`

  macaddr = ipconfig.match("Physical Address.*?: (.*?)$")[1]
  
  @machine_id = Digest::MD5.hexdigest(hostname + ipaddr + macaddr + @distro)
end

def make_uname_based_machine_id(platform)
  #-------------- the uname method --------------------------------------------------------------------
  # this assumes all other platforms support uname -a
  # this also assumes that if a machine upgrades its OS or changes its hostname it essentially becomes
  # a different machine and will be considered different for scanning purposes

  hostname = Socket.gethostname
  mac = ""

  # try to find some other reasonably static info about the machine
  if ( platform == "linux" || platform == "macosx" )
    ifconfig = `/sbin/ifconfig`

    if ( platform == "linux" )  # get the fully qualified hostname with domain if it's available
      hostname = `hostname -f 2>&1`
  
      if ( hostname.match('Unknown host') != nil )
        # we found some versions of ubuntu which would report Unknown host on a hostname -f but the 
        # one-word hostname (not fully qualified) for the `hostname`, so gracefully degrade if this
        # condition exists on the users' box.
        hostname = `hostname 2>&1`
      end
    end
  elsif ( platform == "solaris" )
    # on solaris, if you ifconfig -a as a normal user you can't get the MAC address, only hostname
    # solaris, ifconfig with no -a will dump, so must have -a

    ifconfig = `/sbin/ifconfig -a`
    hostname = `hostname`
  end

  # see if the mac address is in the output...if so, use it, otherwise, mangle the output of ifconfig.
  # Yes, this can cause the machine id to change if the machine is on DHCP and the lease expires
  # or if the machine is carried around and constantly rescanned, but short of using the machine's hostname 
  # exclusively (which can also change), have to find a combination of items which help define the uniqueness of a box
  #
  # The only other known unique ID is from a pentium processor (and not all pentiums), but that instruction was removed
  # due to privacy concerns.  So, the fact is, we don't care about the true unchangeable identity of the machine
  # and you'd freak if we did.  So, just obfuscate some of the basic, relatively static parameters of a machine
  # that help identify it in standard ways such as the address, mac address, hostname and attempt to be unique
  # in their own domains.

  # these are two forms of ifconfig output for showing mac, 'HWaddr' and 'ether'
  if ( ifconfig != nil && 
      ((matchdata = ifconfig.match( '(HWaddr) ([0-9:A-F].*?)$')) != nil || 
       (matchdata = ifconfig.match( '(ether) ([0-9:A-F].*?)$' )) != nil) )

    # load the found mac address
    mac = matchdata[2]

  elsif( ifconfig != nil )

    # substitute an MD5 related to the output of ifconfig instead of mac if it can't be found
    # so just load the variable up with the content of ifconfig
    mac = ifconfig

  else
    mac = "unknown"
  end

  mac = Digest::MD5.hexdigest( mac )  # obfuscate the mac address or ifconfig output

  @uname = `uname -a`
  @kernel = get_starnix_kernel(@uname)
  
  # typical output from uname -a 
  #   Linux smoker 2.6.16.21-0.8-smp #1 SMP Mon Jul 3 18:25:39 UTC 2006 x86_64 x86_64 x86_64 GNU/Linux

  # obfuscate the entire blob of info we gather into a single, 32 byte MD5 sum   
  # if any single one of these items changes over time, the machine ID will change.  This is a known
  # limitation.

  @machine_id = Digest::MD5.hexdigest(hostname + mac + @uname + @distro)
end

def get_starnix_kernel(uname_a)
  # This method and check exists because the FreeBSD (tested on version 7.0) kernel value
  # could not be accurately extracted by using the uname parts technique that most other
  # versions of *nix succumbed to.  The FreeBSD value is set in the 'get_freebsd_version_str'
  # method.  

  # This feels a little odd actually, because the only way this really works is because the
  # 'get_os_version_str' (the method where the @kernel is initialized in a FreeBSD environment)
  # method is called before the 'make_machine_id' method over in discovery.rb.  I think this 
  # oddness is indicative of the notion that cliutils.rb and discovery.rb should probably be
  # refactored whenever we get the time so that they become a more OOish (classes and modules used).
  # This kind of refactoring would undoubtedly make it easier for the census plugin to behave more
  # like an actual plugin by being able to mix methods in somewhere other than directly on Object.
  # (bnoll - 04/01/2008)

  @uname_parts = @uname.split(" ")
  if (@kernel.nil? or @kernel == "") then
    @kernel = sprintf( "%s %s", @uname_parts[2], @uname_parts[3] )
  end 

  return @kernel  
end

=begin rdoc
  return an os name, version string
  
  whatever the distro is of linux or whatever the major windows type is for windows,
  this type of data will be returned in the string.  It can include major OS name,
  major distro name, version, architecture...all in a single line string.
  
  the overall format of the string will always be:
  
     Major OS: distro details
     
     Major OS strings will not change; distro details could change over time
  
  Examples: 
  Mac OS X: Darwin 8.10.0 RELEASE_PPC Power Macintosh powerpc
  Solaris: Solaris 8 2/02 s28s_u7wos_08a SPARC
  SUSE Linux: SUSE Linux Enterprise Desktop 10 (x86_64)
    
=end

def get_os_version_str

  @os_family = RbConfig::CONFIG['host_os']
   
  case major_platform
  when "linux"
    return get_linux_version_str
  when "windows", "jruby-windows"
    return get_windows_version_str
  when "macosx"
    return get_macosx_version_str
  when "solaris"
    return get_solaris_version_str
  when "cygwin"
    return get_cygwin_version_str
  when "freebsd"
    return get_freebsd_version_str
    
  # new platform cases go here
  
  else
    return "Unknown: Unrecognized"
  end
end

=begin rdoc
  return the string containing the windows version info

=end

def get_windows_version_str
  # the windows file:
  # %systemroot%\system32\prodspec.ini
  # contains the warning to not change the contents, so should be pretty stable
  # also makes it easy to search for the bits of version info we need
  #
  # need to find out systemroot, drive, etc before going after prodspec.ini file.
  # some admins put system on drives other than C:

  @os_architecture = ENV["PROCESSOR_ARCHITECTURE"] 
  windir = ENV["windir"]   # this env var exists in both pure ruby and JRuby ENV arrays
    
  @prodspec_fn = "#{windir}/system32/prodspec.ini"

	if ( File.exists?(@prodspec_fn) )
    content = File.new(@prodspec_fn, "r").read

    # pp content

    # Product=Windows XP Professional
    # Version=5.0
    # Localization=English  
    # ServicePackNumber=0

    product = content.match('Product=(.*?)[\r\n]$')[1]

    @os = product
    @os_family = "windows"
    # pick of 2nd Version= which is the one for Windows, the first Version=1.0 is for SMS
    @os_version = content.match('Version=([3-6].*?)$')[1]
    @kernel = "#{product} #{@os_version}"

    return "Windows: #{product}"

	end # if

  # if we got here, we know that the '#{windir}/system32/prodspec.ini' file did not exist 
  # (which means we're probably on Vista - we can prove this by checking for the string 
  # 'VISTA' in the '#{windir}/system32/license.rtf' file, if it exists)
    
  license_rtf_fn = "#{windir}/system32/license.rtf"
 
  if ( File.exists?(license_rtf_fn) )
    content = File.new(license_rtf_fn, "r").read
    is_vista = false
    content.each_line do |line| 
      if (line.include?('EULAID') and line.include?('VISTA')) then
        is_vista = true
      end
    end

    if (is_vista) then
      @kernel = "#{@os_architecture}-mswin"
      @os = 'Vista'
      @os_family = 'windows'

      # this breaks under java/JRuby
      # version = `ver`   # Microsoft Windows [Version 6.0.6000]
      # @os_version = version.match("Version (.*?)\]")[1]
      # 
      # TODO - the workaround is to run ver in the .bat file and read the file here
      #  ver > version.txt
      #  open version.txt, read and match the version as above.
      # per nathan/eric, given 1 hr to freeze, this will be hardwired
      # since we know it's vista here, this is safe for now
      
      @os_version = "6.x" 

      return "Windows: #{@os}"
    end

  end # if

  # if we got here, we don't know what version of Windows it is
  return "Windows: Unknown"
end

=begin rdoc
  return the string containing the cygwin version info
=end

def get_cygwin_version_str
  
  uname = `uname -a`
  
  # sample output from cygwin uname
  # CYGWIN_NT-5.2 landon-ebd16czu 1.5.25(0.156/4/2) 2007-12-14 19:21 i686 Cygwin
  
  # don't take hostname and build date
  parts = uname.split(" ")
  
  @os = "cygwin"                # distro major name "ubuntu"
  @os_family = "cygwin"         # linux, windows, etc
  @os_architecture = parts[5]   # i386, x86_64, sparc, etc
  @os_version = parts[2]        # 5.04, 10.4, etc
  
  return "Cygwin: #{parts[0]} #{parts[2]} #{parts[5]} #{parts[6]}"
end

=begin rdoc
  return the string containing the linux distro and version
  
  list of distros and their release files derived from information found
  on: http://linuxmafia.com/faq/Admin/release-files.html
=end


def get_linux_version_str

    @linux_distros = { 

      "/etc/annvix-release" => "Annvix",
      "/etc/arch-release" => "Arch Linux", 
      "/etc/arklinux-release" => "Arklinux", 
      "/etc/aurox-release" => "Aurox Linux", 
      "/etc/blackcat-release" => "BlackCat", 
      "/etc/cobalt-release" => "Cobalt", 
      "/etc/conectiva-release" => "Conectiva", 
      "/etc/debian_release" => "Debian", 
      "/etc/debian_version" => "Debian",       
      "/etc/fedora-release" => "Fedora", 
      "/etc/gentoo-release" => "Gentoo Linux",
      "/etc/immunix-release" => "Immunix",
      "/etc/knoppix_version" => "Knoppix",
      "/etc/lfs-release" => "Linux-From-Scratch",
      "/etc/linuxppc-release" => "Linux-PPC", 
      "/etc/mandrake-release" => "Mandrake",
      "/etc/mandriva-release" => "Mandriva/Mandrake Linux",
      "/etc/mandrake-release" => "Mandriva/Mandrake Linux",
      "/etc/mandakelinux-release" => "Mandriva/Mandrake Linux",            
      "/etc/mklinux-release" => "MkLinux",
      "/etc/nld-release" => "Novell Linux Desktop",
      "/etc/pld-release" => "PLD Linux",
      "/etc/redhat-release" => "Red Hat",
      "/etc/redhat_version" => "Red Hat",     
      "/etc/slackware-version" => "Slackware", 
      "/etc/slackware-release" => "Slackware",       
      "/etc/e-smith-release" => "SME Server (Formerly E-Smith)",
      "/etc/SuSE-release" => "SUSE Linux",
      "/etc/novell-release" => "SUSE Linux",      
      "/etc/sles-release" => "SUSE Linux ES9",
      "/etc/tinysofa-release" => "Tiny Sofa",
      "/etc/turbolinux-release" => "TurboLinux",
      "/etc/ultrapenguin-release" => "UltraPenguin",
      "/etc/UnitedLinux-release" => "UnitedLinux",
      "/etc/va-release" => "VA-Linux/RH-VALE",
      "/etc/yellowdog-release" => "Yellow Dog"
    }
  
  platform = RUBY_PLATFORM
          
  @os_architecture = `uname -m`.strip

  @linux_distros.each do | distrofile, distroname |
    
    if ( File.exist?(distrofile))

      # this is a special case where we found ubuntu, not debian
      # debian (etch) has debian_version but no lsb-release file
      # need to test on other versions of debian to make sure this heuristic works
      if ( distrofile == "/etc/debian_version" && File.exists?("/etc/lsb-release") )
        next
      end

      content = File.new(distrofile, "r").readlines

      distro_bits = content[0].strip == nil ? content[0] : content[0].strip
      @os = distroname
      
      # special case for debian - pull the os version number from this file directly 
      if ( distrofile == "/etc/debian_version" )
        @os_version = distro_bits
      end

      # for release files which match fedora-like strings:
      #  "Fedora release 8 (Werewolf)" 
      if( distro_bits.match('release (.*?) ') != nil ) 
         @os_version = distro_bits.match('release (.*?) ')[1] 
      end

      content.each do | line |

        if( line.match('^VERSION = (.*?)$') != nil ) 
          @os_version = line.match('^VERSION = (.*?)$')[1] 
        end

      end

      return "#{distroname}: #{distro_bits}" 

    end # exists
  end # distros
  
  # if we got here, none of the distro files were found, most common cause is Ubuntu.
  # Problem with Ubuntu using lsb-release is that lots of other distros have lsb-release, even SuSE,
  # as well as their own release file, so if none of the distro-specific release files were
  # found, look for lsb-release - as last resort it could be Ubuntu or some other flavor that
  # only uses lsb-release.
  
  if ( File.exist?("/etc/lsb-release") )
    content = File.new("/etc/lsb-release", "r").read
    
    if ( (distroname = content.match("^DISTRIB_ID=(.*?)$")[1]) == nil )
      distroname = "Unknown"
    end

    if ( (version = content.match("^DISTRIB_RELEASE=(.*?)$")[1]) == nil )
      version = "Unknown"
    end
    
    @os_version = version
    
    if ( (codename = content.match("^DISTRIB_CODENAME=(.*?)$")[1]) == nil )
      codename = "Unknown"
    end
    
    @os = "#{distroname} #{codename}"
    
    if ( (description = content.match("^DISTRIB_DESCRIPTION=(.*?)$")[1]) == nil )
      description = "Unknown"
  
    end

    # strip quotes from description                
    description.gsub!('"', '' )

    if ( distroname != nil && description != nil )
      return "#{distroname}: #{description} (#{codename})" 
    end
    
  end
  
  return "Unknown: Unrecognized distro"
end

def get_freebsd_version_str
 freebsd = "FreeBSD"
 @os_family = freebsd
 @os = freebsd

 @os_architecture = `uname -m`.strip
 kernel_parts = `uname -v`.split(" ")
 @kernel = kernel_parts[1] + " " + kernel_parts[2].match(/(.*):/)[1]

 version = File.new('/usr/src/sys/conf/newvers.sh').read.match(/REVISION=\"(.*)\"/)[1]
 if (!version.nil?) then
   @os_version = version
 end
 
 return freebsd + " " + @os_version
end


=begin rdoc
  return the string containing the solaris distro and version
  
  takes the first line of the solaris /etc/release file (ie:)
  
  Solaris 9 9/05 s9s_u8wos_05 SPARC
=end

def get_solaris_version_str
    # you can find the solaris OS version in /etc/release
  
    # /etc/release is a typical Solaris release file
    # /etc/sun-release is typical of Sun's JDS - java desktop system
    
    distrofiles = [ "/etc/release","/etc/sun-release" ]
    
    distrofiles.each do | distrofile |
      if ( File.exists?(distrofile) )
        File.open(distrofile, "r" ) do | file | 
          file.each do | line |
            distro_bits = line.strip!
            if ( distro_bits == nil )
              distro_bits = line     
            end
            
            # typical solaris distro line:
            # "                        Solaris 9 9/05 s9s_u8wos_05 SPARC".split(" ")
            # => ["Solaris", "9", "9/05", "s9s_u8wos_05", "SPARC"]

            parts = distro_bits.split(" ")
            @os_architecture = parts[4]   # i386, x86_64, sparc, etc
            @os_version = parts[1]        # 5.04, 10.4, etc
          
            @os = "solaris"                # distro major name "ubuntu"
            @os_family = "solaris"         # linux, windows, etc
          
            return "Solaris: #{distro_bits}" 
          end 
        end
      end
    end
end

=begin rdoc
  return the string containing the macosx version
=end

def get_macosx_version_str
  # since there's only one distro of mac os x, Darwin, just assume that "distro" plus get the kernel version and return it
  # example uname string: 
  # for PPC mac: 
  # Darwin whitecloud 8.10.0 Darwin Kernel Version 8.10.0: Wed May 23 16:50:59 PDT 2007; root:xnu-792.21.3~1/RELEASE_PPC Power Macintosh powerpc
  # for Intel mac:
  # Darwin cooper.local 9.1.0 Darwin Kernel Version 9.1.0: Wed Oct 31 17:46:22 PDT 2007; root:xnu-1228.0.2~1/RELEASE_I386 i386
  
  uname_content = `uname -a`
  parts = uname_content.split(" ")
  os = parts[0]
  kernel = parts[2]
  parts = uname_content.split("/")
  release = parts[1]
  archparts = release.split(" ")
  
  release.strip != nil ? release.strip! : release;
  
  @os = os                          # distro major name "ubuntu"
  @os_family = "macosx"             # linux, windows, etc
  @os_architecture = `uname -m`.strip
  @os_version = kernel              # 5.04, 10.4, etc
    
  return "Mac OS X: #{os} #{kernel} #{release}"
end

def normalize_dir(dir)
  # Some versions of ruby have trouble when expanding a path with backslashes.
  # In windows, replace all backslashes with forward slashes.
  
  if major_platform =~ /windows/
    dir=dir.gsub('\\','/')
  end
  
  dir = File.expand_path( dir )
  dir = dir.gsub(/[\/]{2,}/,'/') 
end

def print_rule_version_info()
  universal_rules_version = ScanRulesReader.get_universal_rules_version()
  universal_rules_md5 = ScanRulesReader.generate_aggregate_md5(File.dirname(@rules_openlogic))
  rules_files = ScanRulesReader.find_all_scanrules_files(File.dirname(@rules_openlogic))
  puts ""
  puts "===== General Rule Version Information ====="
  puts "universal-version           : '#{universal_rules_version}'"
  puts "universal-rules-md5         : '#{universal_rules_md5}'"
  puts "total number of rules files : '#{rules_files.size}'"
  puts ""
  puts "===== Individual File Information ====="
  rules_files.each_with_index do |rf, i|
    the_file = File.new(rf)
    the_file.binmode
    md5_val = Digest::MD5.hexdigest(the_file.read)
    puts "#{i+1}) #{md5_val} #{rf}"
  end
  puts ""
end

=begin rdoc
  return true or false if we can reach the census site - typically only called if --deliver-results is active
  we want to make sure we can reach the net and warn the user right up front if the census site cannot be reached.
=end

def check_network_connectivity( url )

  begin
    if ( url == nil )  # no need for network check
       return true
    end
    
		# use any proxy settings that are configured
		
		uri = URI.parse(url)
	
		response = Net::HTTP.Proxy( @proxy_host, @proxy_port, @proxy_user, @proxy_password ).start(uri.host) { | http | 
			 return true
		}
  rescue Exception => e
     return false
  end
end

def build_options_parameter_list( param_array )

  optstr = "options.set_options("

  param_array.each do | str |
     optstr << str
     optstr << "\n"
  end

  optstr << ")\n"

end

