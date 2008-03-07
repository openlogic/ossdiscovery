# cliutils.rb
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
# You can learn more about OSSDiscovery, report bugs and get the latest versions at www.ossdiscovery.org.
# You can contact the OSS Discovery team at info@ossdiscovery.org.
# You can contact OpenLogic at info@openlogic.com.


# --------------------------------------------------------------------------------------------------
#
#  cliutils.rb contains methods to support CLI command processing and output
#

require 'net/http'
require 'find'
require 'erb'
require 'rbconfig'
require 'uri'
require 'pp'
require 'base64'   # used for java proxy authentication properties

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

  printf("\nUsage: %s [options]\n", @discovery_name )
  printf("\nThe simplest usage of %s is: ./%s\n", @discovery_name, @discovery_name )
  # please maintain this list in alphabetical order
  printf("\nOptions are not order dependent and may be one or more of:\n")
  printf("--conf,           -c the absolute or relative path and filename of the configuration file to use for the scan\n")
  printf("--deliver-batch   -D the absolute or relative path to a directory contain one or more scan results files to deliver\n")
  printf("--deliver-results -d existence says 'yes' deliver results to server. Server destination is configured in config/config.yml\n")
  printf("                     optionally --deliver-results can take a parameter which is a path to an existing scan results file to deliver\n")
  printf("--help,           -h print this help message\n")
  printf("--human-results,  -u the absolute or relative path and filename for the human readable results files.  The default is %s\n", "STDOUT" )
  printf("--geography,      -Y geography code, if the scan is submitted to census server as an anonymous scan, this overrides\n" )
  printf("                     value in the config.yml file.  This is an exception to order dependences and must occur before\n")
  printf("                     --deliver-results on the command line.\n")
  printf("--census-code,    -C the identifier code received at census registration time\n")
  printf("--inc-path,       -I include the path/location of detected package in machine scan results\n")  
  printf("--list-excluded,  -e during a scan, print a list of files that are excluded and the filter that excluded each\n")
  printf("--list-files,     -f during a scan, print a list of all files that matched a rule or other criteria\n")
  printf("--list-filters,   -g print a list of generic filters that would be active during the next scan\n")
  printf("--list-foi,       -i print a list of files of interest %s will be looking for\n", @discovery_name)
  printf("--list-geos       -G print a list of geographies and their numeric codes\n")
  printf("--list-os,        -o list the operating system, version, and distro on which #{@discovery_name} is running\n")  
  printf("--list-projects,  -j print a list of the projects that are capable of being discovered\n")
  printf("                     Optionally append 'verbose' to get verbose output.\n")
  printf("--list-md5-dupes, -M If the same MD5 digest is used in two or more match rule definitions, then the duplicated digests are printed.\n")
  printf("--list-tag,       -t print the machine ID (tag) that will be reported with scan results\n")
  printf("--machine-results,-m the absolute or relative path and filename for the machine readable results files.\n" )
  printf("--nofollow,       -N don't follow symlinks, default is: %s, follow symlinks\n", @follow_symlinks ? "Yes" : "No" )
  printf("--preview-results,-R This flag will dump the machine results file to the console when the scan is complete.\n")
  printf("--production-scan,-P This flag identifies the scan you run as a scan of a production machine in the results.\n")
  printf("--progress,       -x show progress indicator every X number of files scanned - X given by the parameter to --progress\n")
  printf("--path,           -p the absolute or relative path of the directory to scan, the default is %s\n", @directory_to_scan )
  # future printf("--speed,          -s a value of 1,2, or 3 which is a hint to the rule engine for how precise to be.\n")
  # future printf("                     the lower the number, the faster but less precise the scan will be.\n")
  # future printf("                     The default speed is 2, medium\n")
  printf("--rule-version,   -V print out rule version info and do nothing else (no scan performed)\n")
  printf("--throttle,       -T Enable throttling of the scanner so all system resources are not fully dedicated to running this tool.\n")
  printf("                     No arguments accepted for this option.  See the throttle_* properties in the configuration file.                                   \n")
  printf("--update-rules,   -r Gets updated scan rules from the server (discovery scan not performed).\n")
  printf("                     Providing an optional 'scan' argument (--update-rules scan) will first get the updated rules\n")
  printf("                     from the server and then go ahead and perform a discovery scan of the specified --path.\n")
  printf("--version,        -v print the version of %s\n", @discovery_name )
  
  printf("\nThe default configuration file is %s and can contain \n", 'conf/config.yml', @discovery_name )
  printf("all the parameters required for a scan.  Any command line parameter given will\n")
  printf("override what is found in the configuration file. \n", @discovery_name )
  printf("\nIf no command line parameters are given, %s will do a root directory scan and place the results \n", @discovery_name )
  printf("in the directory from which the scan was invoked.\n")

  printf("\n\nExamples:\n")
  printf("./discovery --path /home/lcox --machine-results /tmp/myscan_machine_results.txt --human-results /tmp/myscan_human_results.txt\n")
  printf("   scans the directory /home/lcox and places the results files in the /tmp directory.\n")

  printf("\n\n")
  printf("For geography codes used with --geography command line option or the geography config.yml property,\n")
  printf( "#{show_geographies_short()}\n" )

  printf("\n%s\n", version() )    
  printf("%s\n", @copyright )
  printf("Unique Machine Tag (ID): %s\n", @machine_id )
  printf("License: %s\n", @discovery_license_shortname )

end

=begin rdoc
    returns a standard version string to use throughout discovery    
=end

def version
  return @discovery_name + " v" + @discovery_version
end

=begin rdoc
    dumps a simple ASCII text report to the console
=end

def report( packages )
  io = nil
  if (@results == STDOUT) then
    io = STDOUT
  else 
    io = File.new(@results, "w")
  end

  scan_ftime = @endtime - @starttime  # seconds
  scan_hours = (scan_ftime/3600).to_i
  scan_min = ((scan_ftime -  (scan_hours*3600))/60).to_i
  scan_sec = scan_ftime - (scan_hours*3600) - (scan_min*60)

  # pull the stats from the walker for a simple report
  
  throttling_enabled_or_disabled = nil
  if (@walker.throttling_enabled) then
    throttling_enabled_or_disabled = 'enabled'
  else
    throttling_enabled_or_disabled = 'disabled'
  end
  end_of_line = "\n"

  printf(io, end_of_line)
  printf(io, "directories walked    : %d#{end_of_line}", @walker.dir_ct )
  printf(io, "files encountered     : %d#{end_of_line}", @walker.file_ct )
  printf(io, "symlinks found        : %d#{end_of_line}", @walker.sym_link_ct )
  printf(io, "symlinks not followed : %d#{end_of_line}", @walker.not_followed_ct )  
  printf(io, "bad symlinks found    : %d#{end_of_line}", @walker.bad_link_ct )
  printf(io, "permission denied     : %d#{end_of_line}", @walker.permission_denied_ct )
  printf(io, "files examined        : %d#{end_of_line}", @walker.foi_ct )
  printf(io, "start time            : %s#{end_of_line}", @starttime.asctime )
  printf(io, "end time              : %s#{end_of_line}", @endtime.asctime )
  printf(io, "scan time             : %02d:%02d:%02d (hh:mm:ss)#{end_of_line}", scan_hours, scan_min, scan_sec )
  printf(io, "distro                : %s#{end_of_line}", @distro )
  printf(io, "kernel                : %s#{end_of_line}", @kernel )
  printf(io, "anonymous machine hash: %s#{end_of_line}", @machine_id )
  printf(io, "")
  printf(io, "packages found        : %d#{end_of_line}", packages.length )
  printf(io, "throttling            : #{throttling_enabled_or_disabled} (total seconds paused: #{@walker.total_seconds_paused_for_throttling})#{end_of_line}" )
  @production_scan = false unless @production_scan == true
  printf(io, "production machine    : %s#{end_of_line}",  @production_scan)
  
  max_version_length = 32
  
  if ( packages.length > 0 )
    # Format the output by making sure the columns are lined up so it's easier to read.
    longest_name = "Package Name".length
    longest_version = "Version".length
    
    packages.each do |package| 
      if ( package.version.length < max_version_length )
        longest_name = package.name.length if (package.name.length > longest_name)
        longest_version = package.version.length if (package.version.length > longest_version)
      end
    end # of packages.each
    
    printf(io, %{#{"Package Name".ljust(longest_name)} #{"Version".ljust(longest_version)} Location#{end_of_line}})
    printf(io, %{#{"============".ljust(longest_name)} #{"=======".ljust(longest_version)} ========#{end_of_line}})
    
    packages.to_a.sort!.each do | package |
      begin 

        if ( package.version.size > max_version_length )
          printf(io, "Possible error in rule: #{package.name} ... matched version text was too large (#{package.version.size} characters)#{end_of_line}")
          @@log.error("Possible error in rule: #{package.name} ... matched version text was too large (#{package.version.size} characters) - matched version: '#{package.version}'")
        else
          printf(io, "#{package.name.ljust(longest_name)} #{package.version.ljust(longest_version)} #{package.found_at}#{end_of_line}")
        end
      rescue Exception => e
        printf(io, "Possible error in rule: #{package.name}#{end_of_line}")
      end
    end # of packages.each
  end
  
  if (io != STDOUT)  
    io.close 
    # now echo final results to console also
    result_txt = File.open(@results,"r").read
    puts result_txt
  end
  
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
  this method posts the machine scan results back to the discovery server using the Net classes in stdlib
  
  good reference:  http://www.ruby-doc.org/stdlib/libdoc/net/http/rdoc/classes/Net/HTTP.html
=end

def deliver_results( result_file )
  printf("Posting results to: %s ...please wait\n", @destination_server_url )
  results = File.new( result_file ).read
  
  begin
    
    if not @destination_server_url.match("^https:")
      # The Open Source Census doesn't allow sending via regular HTTP for security reasons unless explicitly given the override

      if defined?(CENSUS_PLUGIN_VERSION) && (@override_https == nil || @override_https == false)
        puts "For security reasons, the Open Source Census requires HTTPS."
        puts "Please update the value of destination_server_url in conf/config.yml to the proper HTTPS URL."

        return
      else
        # if the delivery URL is not HTTPS, use this simple form of posting scan results    
        # Since Net::HTTP.Proxy returns Net::HTTP itself when proxy_addr is nil, there‘s no need to change code if there‘s proxy or not.

        if ( @override_https != nil && @override_https )
          puts "WARNING:  The HTTPS delivery restriction is currently being overridden for ease-of-test purposes" 
        end

        response = Net::HTTP.Proxy( @proxy_host, @proxy_port, @proxy_user, @proxy_password ).post_form(URI.parse(@destination_server_url),    
                                  {'scan[scan_results]' => results} )

        response_headers = response.to_hash()
      end

    elsif HTTPS_AVAILABLE
      # otherwise, the delivery URL is HTTPS and SSL is available
      
      # TODO - HTTPS in pure ruby will not yet work through a proxy - all HTTPS deliveries must be direct for now in that case
      # or the delivery URL must be explicitly changed to be HTTP only to use a proxy
      
      # parse the delivery url for hostname/IP, port if one is given, otherwise default to 443 for ssl
      # irb(main):006:0> URI.split("https://192.168.10.211:443/cgi-bin/scanpost.rb?test=this")
      # => ["https", nil, "192.168.10.211", "443", nil, "/cgi-bin/scanpost.rb", nil, "test=this", nil]
      
      parts = URI.split(@destination_server_url)
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

        if ( @proxy_host != nil )
           puts "HTTPS posts through a proxy is not supported when running under the Ruby Net classes.  Try JRuby instead"
           return
        else
          http = Net::HTTP.new(host, port)
          http.use_ssl = true
          headers = { "Content-Type" => "application/x-www-form-urlencoded" }
          response = http.request_post( path, "scan[scan_results]=#{results}", headers)

          response_headers = response.to_hash()
        end

      else # do it the Java way because for HTTPS through a proxy this will work in addition to the standard HTTPS post

        client = org.apache.commons.httpclient.HttpClient.new
        post = org.apache.commons.httpclient.methods.PostMethod.new( @destination_server_url )
        post.set_do_authentication( true )
        # post method created

        if ( @proxy_host != nil )
           # setting up proxy
           client.get_host_configuration().set_proxy(@proxy_host, @proxy_port)
           scope = Java::OrgApacheCommonsHttpclientAuth::AuthScope::ANY
           credentials = org.apache.commons.httpclient.UsernamePasswordCredentials.new( @proxy_user, @proxy_password )
           client.get_state().set_proxy_credentials( scope, credentials ) 
           # proxy credentials created
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
      puts("Can't submit scan results to secure server: #{@destination_server_url} because we can't find OpenSSL and we're not running in JRuby")
      response = { "disco" => "0, OpenSSL not found" }
    end
 
    # homogenize JRuby/java.net and Ruby Net::HTTP responses into a response header hash

    if ( !response_headers["status"].to_s.match("200") )
      printf("Error submitting the scan results\n")
      response["disco"] = "0, Bad response from server while posting results. #{response_headers['status']}"
    end
 
  rescue Errno::ECONNREFUSED, Errno::EBADF, OpenSSL::SSL::SSLError, Timeout::Error, Errno::EHOSTUNREACH
    printf("Can't submit scan. The connection was refused or server did not respond when trying to deliver the scan results.\nPlease check your network connection or contact the administrator for the server at: %s\n", @destination_server_url )
    printf("\nYour machine readable results can be found in the file: %s\n", result_file )
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
   
  # request by Customer to strip disco status code from output and put in referrer message
  if ( response["disco"].match("^100") )  # look for success code from discovery server
    printf("Result: Success! View reports at http://www.osscensus.org\n") # DIS-825
  else
    printf("Result: %s\n", response["disco"].gsub(/^[0-9]+, /, "") )
  end 

end


=begin rdoc
  given a directory of scan results, pick off scans and deliver them
=end

def deliver_batch( result_directory )

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
         
             end

             deliver_results( results_fname ) 
        end
     rescue Errno::EACCES, Errno::EPERM
        puts "Cannot access #{results_fname}\n" 
     end
  end

end

=begin rdoc
  this code is responsible for generating a unique and static machine id
=end
def make_machine_id
  # for non-windows machines, everything else is u*ix like and should support uname
  
  platform = major_platform
  
  case platform
  when "windows", "java", "jruby-windows"     
	                     # 'java' is what's reported if running under JRuby, 
                             # so use the simplest possible machine id regardless of "real" platform
                             # if using JRuby
    if (platform == "jruby-windows" )
       # this isn't as good or specific as pure ruby with Win32 gem can give, but at this writing
       # Win32 gem isn't ready for prime time under JRuby
       @kernel = "#{@os_architecture}-mswin" 
    end

    make_simple_machine_id   
  else  # every other platform including cygwin supports uname -a
    make_uname_based_machine_id platform
  end
end

=begin rdoc
  return a hashed machine id composed of only hostname, IP address, and distro string
=end
def make_simple_machine_id

  if ( @kernel == nil )
    @kernel = RUBY_PLATFORM
  end

  hostname = Socket.gethostname
  ipaddr = IPSocket.getaddress(hostname)
  
  @machine_id = Digest::MD5.hexdigest(hostname + ipaddr + @distro)
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
      ((matchdata = ifconfig.match( '(HWaddr) ([0-9:A-F].*?)+$')) != nil || 
       (matchdata = ifconfig.match( '(ether) ([0-9:A-F].*?)+$' )) != nil) )

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
  @uname_parts = @uname.split(" ")
  @kernel = sprintf( "%s %s", @uname_parts[2], @uname_parts[3] )

  # typical output from uname -a 
  #   Linux smoker 2.6.16.21-0.8-smp #1 SMP Mon Jul 3 18:25:39 UTC 2006 x86_64 x86_64 x86_64 GNU/Linux

  # obfuscate the entire blob of info we gather into a single, 32 byte MD5 sum   
  # if any single one of these items changes over time, the machine ID will change.  This is a known
  # limitation.
  @machine_id = Digest::MD5.hexdigest(hostname + mac + @uname + @distro)
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
  @os_architecture = RbConfig::CONFIG['host_cpu']
   
  case major_platform
  when "linux"
    return get_linux_version_str
  when "windows"
    return get_windows_version_str
  when "jruby-windows"  # this is special because Win32 classes aren't supported under JRuby at this writing
    return @os_family
  when "macosx"
    return get_macosx_version_str
  when "solaris"
    return get_solaris_version_str
  when "cygwin"
    return get_cygwin_version_str
    
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

  @os_architecture = "unknown"

  Win32::Registry::HKEY_LOCAL_MACHINE.open('HARDWARE\DESCRIPTION\System\CentralProcessor\0') do |reg|
    reg_typ, reg_val = reg.read('ProcessorNameString')
    @os_architecture = reg_val
  end
     
  [ENV['HOMEDRIVE'],"C","D","Z"].each do | drivespec |
    
   @prodspec_fn = "#{drivespec}:/windows/system32/prodspec.ini"
   
   if ( File.exists?(@prodspec_fn) )
      content = File.new(@prodspec_fn, "r").read
      
      # Product=Windows XP Professional
      # Version=5.0
      # Localization=English  
      # ServicePackNumber=0
      
      product = content.match("Product=(.*?)$")[1]

      @os = product
      @os_family = "windows"
      @os_version = content.match("Version=(.*?)$")[1]
      
      return "Windows: #{product}"

   end # if
  end # do

  return "Unknown"
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
      "/etc/fedora-release" => "Fedora Core", 
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
  @os_architecture = archparts[1]   # i386, x86_64, sparc, etc
  @os_version = kernel              # 5.04, 10.4, etc
    
  return "Mac OS X: #{os} #{kernel} #{release}"
end

def show_geographies_short()
  "see command line option --list-geos for a full listing of geographies"
end

def show_geographies_long()

"1,AFGHANISTAN
2,ALBANIA
3,ALGERIA
4,ANDORRA
5,ANGOLA
6,ANTIGUA_AND_BARBUDA
7,ARGENTINA
8,ARMENIA
9,AUSTRALIA
10,AUSTRIA
11,AZERBAIJAN
12,BAHAMAS
13,BAHRAIN
14,BANGLADESH
15,BARBADOS
16,BELARUS
17,BELGIUM
18,BELIZE
19,BENIN
20,BHUTAN
21,BOLIVIA
22,BOSNIA_AND_HERZEGOVINA
23,BOTSWANA
24,BRAZIL
25,BRUNEI
26,BULGARIA
27,BURKINA_FASO
28,BURMA_MYANMAR
29,BURUNDI
30,CAMBODIA
31,CAMEROON
32,CANADA
33,CAPE_VERDE
34,CENTRAL_AFRICAN_REPUBLIC
35,CHAD
36,CHILE
37,CHINA
38,COLOMBIA
39,COMOROS
40,CONGO
41,CONGO_DEMOCRATIC_REPUBLIC_OF
42,COSTA_RICA
43,COTE_D_IVOIRE_IVORY_COAST
44,CROATIA
45,CUBA
46,CYPRUS
47,CZECH_REPUBLIC
48,DENMARK
49,DJIBOUTI
50,DOMINICA
51,DOMINICAN_REPUBLIC
52,EAST_TIMOR
53,ECUADOR
54,EGYPT
55,EL_SALVADOR
56,EQUATORIAL_GUINEA
57,ERITREA
58,ESTONIA
59,ETHIOPIA
60,FIJI
61,FINLAND
62,FRANCE
63,GABON
64,GAMBIA
65,GEORGIA
66,GERMANY
67,GHANA
68,GREECE
69,GRENADA
70,GUATEMALA
71,GUINEA
72,GUINEA_BISSAU
73,GUYANA
74,HAITI
75,HONDURAS
76,HUNGARY
77,ICELAND
78,INDIA
79,INDONESIA
80,IRAN
81,IRAQ
82,IRELAND
83,ISRAEL
84,ITALY
85,JAMAICA
86,JAPAN
87,JORDAN
88,KAZAKSTAN
89,KENYA
90,KIRIBATI
91,NORTH_KOREA
92,SOUTH_KOREA
93,KUWAIT
94,KYRGYZSTAN
95,LAOS
96,LATVIA
97,LEBANON
98,LESOTHO
99,LIBERIA
100,LIBYA
101,LIECHTENSTEIN
102,LITHUANIA
103,LUXEMBOURG
104,MACEDONIA
105,MADAGASCAR
106,MALAWI
107,MALAYSIA
108,MALDIVES
109,MALI
110,MALTA
111,MARSHALL_ISLANDS
112,MAURITANIA
113,MAURITIUS
114,MEXICO
115,MICRONESIA
116,MOLDOVA
117,MONACO
118,MONGOLIA
119,MONTENEGRO
120,MOROCCO
121,MOZAMBIQUE
122,NAMIBIA
123,NAURU
124,NEPAL
125,NETHERLANDS
126,NEW_ZEALAND
127,NICARAGUA
128,NIGER
129,NIGERIA
130,NORWAY
131,OMAN
132,PAKISTAN
133,PALAU
134,PANAMA
135,PAPUA_NEW_GUINEA
136,PARAGUAY
137,PERU
138,PHILIPPINES
139,POLAND
140,PORTUGAL
141,QATAR
142,ROMANIA
143,RUSSIAN_FEDERATION
144,RWANDA
145,SAINT_KITTS_AND_NEVIS
146,SAINT_LUCIA
147,SAINT_VINCENT_AND_THE_GRENADINES
148,SAMOA
149,SAN_MARINO
150,SAO_TOME_AND_PRINCIPE
151,SAUDI_ARABIA
152,SENEGAL
153,SERBIA
154,SEYCHELLES
155,SIERRA_LEONE
156,SINGAPORE
157,SLOVAKIA
158,SLOVENIA
159,SOLOMON_ISLANDS
160,SOMALIA
161,SOUTH_AFRICA
162,SPAIN
163,SRI_LANKA
164,SUDAN
165,SURINAME
166,SWAZILAND
167,SWEDEN
168,SWITZERLAND
169,SYRIA
170,TAJIKISTAN
171,TANZANIA
172,TAIWAN
173,THAILAND
174,TOGO
175,TONGA
176,TRINIDAD_AND_TOBAGO
177,TUNISIA
178,TURKEY
179,TURKMENISTAN
180,TUVALU
181,UGANDA
182,UKRAINE
183,UNITED_ARAB_EMIRATES
184,UNITED_KINGDOM
185,UNITED_STATES
186,URUGUAY
187,UZBEKISTAN
188,VANUATU
189,VATICAN
190,VENEZUELA
191,VIETNAM
192,YEMEN
193,ZAMBIA
194,ZIMBABWE
195,OTHER
"
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
