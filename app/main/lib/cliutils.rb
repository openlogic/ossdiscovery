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

begin
  # not all ruby installs and builds contain openssl, so degrade
  # gracefully if https can't be pulled in.
  require 'net/https'
  NO_SSL = false
rescue LoadError => e
  # bail on using any HTTPS delivery mechanisms since the client machine
  # doesn't have the prerequisite software
  NO_SSL = true
end

require 'digest/md5' 

#--------------------------------------------------------------------------------------
# this will suppress Ruby warnings on machines that have world writable directories.
# common on Solaris machines we've seen
$VERBOSE=nil  


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
  printf("--deliver-results -d existence says 'yes' deliver results to server. Server destination is configured in %s\n", @config )
  printf("                     optionally --deliver-results can take a parameter which is a path to an existing scan results file to deliver\n")
  printf("--help,           -h print this help message\n")
  printf("--human-results,  -u the absolute or relative path and filename for the human readable results files.  The default is %s\n", "STDOUT" )
  printf("--inc-path,       -I include the path/location of detected package in machine scan results\n")  
  printf("--list-excluded,  -e during a scan, print a list of files that are excluded and the filter that excluded each\n")
  printf("--list-files,     -f during a scan, print a list of all files that matched a rule or other criteria\n")
  printf("--list-filters,   -g print a list of generic filters that would be active during the next scan\n")
  printf("--list-foi,       -i print a list of files of interest %s will be looking for\n", @discovery_name)
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

  printf("\n%s\n", version() )    
  printf("%s\n", @copyright )
  printf("Unique Machine Tag (ID): %s\n", @machine_id )
  printf("License: %s\n", @discovery_license_shortname )

end

=begin rdoc
    returns a standard version string to use throughout discovery    
=end

def version()
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

  printf(io, "directories walked    : %d\n", @walker.dir_ct )
  printf(io, "files encountered     : %d\n", @walker.file_ct )
  printf(io, "symlinks found        : %d\n", @walker.sym_link_ct )
  printf(io, "symlinks not followed : %d\n", @walker.not_followed_ct )  
  printf(io, "bad symlinks found    : %d\n", @walker.bad_link_ct )
  printf(io, "permission denied     : %d\n", @walker.permission_denied_ct )
  printf(io, "files of interest     : %d\n", @walker.foi_ct )
  printf(io, "start time            : %s\n", @starttime.asctime )
  printf(io, "end time              : %s\n", @endtime.asctime )
  printf(io, "scan time             : %02d:%02d:%02d (hh:mm:ss)\n", scan_hours, scan_min, scan_sec )
  printf(io, "distro                : %s\n", @distro )
  printf(io, "kernel                : %s\n", @kernel )
  printf(io, "machine id            : %s\n", @machine_id )
  printf(io, "")
  printf(io, "packages found        : %d\n", packages.length )
  printf(io, "throttling            : #{throttling_enabled_or_disabled} (total seconds paused: #{@walker.total_seconds_paused_for_throttling})\n" )
  @production_scan = false unless @production_scan == true
  printf(io, "production scan       : %s\n",  @production_scan)
  
  if ( packages.length > 0 )
    # Format the output by making sure the columns are lined up so it's easier to read.
    longest_name = 0
    longest_version = 0
    
    packages.each do |package| 
      longest_name = package.name.length if (package.name.length > longest_name)
      longest_version = package.version.length if (package.version.length > longest_version)
    end # of packages.each
    
    pad_name = ""
    pad_version = ""
    
    1.upto(longest_name - "Package Name".length) {pad_name << " "}
    1.upto(longest_version - "Version".length) {pad_version << " "}
    printf(io, "Package Name#{pad_name} Version#{pad_version} Location\n")
    printf(io, "============#{pad_name} =======#{pad_version} ========\n")
    
    packages.to_a.sort!.each do | package |
      pad_name = ""
      pad_version = ""
      
      1.upto(longest_name - package.name.length) {pad_name << " "}
      1.upto(longest_version - package.version.length) {pad_version << " "}
      
      printf(io, "#{package.name + pad_name} #{package.version + pad_version} #{package.found_at}\n")
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
    io = File.new(@results, "w")
  end
  
  r_strings = Array.new
  records.each {|r| r_strings << r.to_s}
  r_strings.sort!
  printf(io, "##### Audit Info ###############################################################\n")
  audit_info = RuleAnalyzer.analyze_audit_records(records)
  audit_info.each_pair {|file, versions| printf(io, "Unique file (#{file}) produced multiple version matches: #{versions.inspect}\n")}
  printf(io, "##### Raw Audit Data ###########################################################\n")
  r_strings.each {|r| printf(io, r.to_s + "\n")}
  
  if (io != STDOUT) then io.close end
end

=begin rdoc
  this method will generate a report format suitable for posting to the discovery server
=end

def machine_report( packages )
  io = nil
  if (@machine_results == STDOUT) then
    io = STDOUT
  else 
    io = File.new(@machine_results, "w")
  end

  # pull the stats from the walker for a simple report

  printf(io, "type:summary\n")
  printf(io, "scanner:%s\n", version() )
  printf(io, "company:%s\n", @company_name )
  printf(io, "machine:%s\n", @machine_id )
  printf(io, "directories:%d\n", @walker.dir_ct )
  printf(io, "files:%d\n", @walker.file_ct )
  printf(io, "symlinks:%d\n", @walker.sym_link_ct )
  printf(io, "denied:%d\n", @walker.permission_denied_ct )
  printf(io, "foi:%d\n", @walker.foi_ct )
  printf(io, "start: %s\n", @starttime.to_i )
  printf(io, "end: %s\n", @endtime.to_i )
  printf(io, "totaltime:%s\n", @endtime - @starttime )
  printf(io, "found:%d\n", packages.length )
  printf(io, "distro:%s\n", @distro )                # similar to the full release string  
  printf(io, "osfamily:%s\n", @os_family )           # windows, linux, solaris, mac
  printf(io, "os:%s\n", @os )                        # xp, ubuntu, redhat
  printf(io, "osversion:%s\n", @os_version )         # sp3, 7.04, 5
  printf(io, "architecture:%s\n", @os_architecture ) # x86_64, i386, PPC,
  printf(io, "kernel:%s\n", @kernel ) 
  printf(io, "rbplat:%s\n", RUBY_PLATFORM )
  @production_scan = false unless @production_scan == true
  printf(io, "production_scan:%s\n",  @production_scan)
    
  if ( packages.length > 0 )
    printf(io, "package,version,location\n")
    packages.each do | package |
    
      # split the version string and dump each one on a new line so the columns are nicely lined up regardless of the number of versions
      @versions = package.version.split(",")
      @versions.sort!
      @versions.each do | version |
        
        version.gsub!(" ","")
        # strip out any null characters that could be in there from a double-byte match rule
        version.tr!("\0","")

        if ( @include_paths )
          printf(io, "%s,%s,%s\n", package.name, version, package.found_at )  
        else
          printf(io, "%s,%s\n", package.name, version )            
        end
      end
    end
  end
  
  if (io != STDOUT) then io.close end
  
  if ( @preview_results )
    printf("\nThese are the actual machine scan results from the file, %s, that would be delivered by --deliver-results option\n", @machine_results )
    results = File.new( @machine_results ).read
    puts results
  end
  
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
  when ( RUBY_PLATFORM =~ /java/ )     # JRuby returns java regardless of platform
    return "java"    
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

  results = File.new( result_file ).read
  
  begin
    
    if ( @destination_server_url.match("^https:") == nil )
      
      # if the delivery URL is not HTTPS, use this simple form of posting scan results    
      # Since Net::HTTP.Proxy returns Net::HTTP itself when proxy_addr is nil, there‘s no need to change code if there‘s proxy or not.
      response = Net::HTTP.Proxy( @proxy_host, @proxy_port, @proxy_user, @proxy_password ).post_form(URI.parse(@destination_server_url),    
                                {'scan[scan_results]' => results} )
                                
    elsif ( NO_SSL == false )
      # otherwise, the delivery URL is HTTPS and SSL is available
      
      # TODO - HTTPS will not yet work through a proxy - all HTTPS deliveries must be direct for now
      
      # parse the delivery url for hostname/IP, port if one is given, otherwise default to 443 for ssl
      # irb(main):006:0> URI.split("https://192.168.10.211:443/cgi-bin/scanpost.rb?test=this")
      # => ["https", nil, "192.168.10.211", "443", nil, "/cgi-bin/scanpost.rb", nil, "test=this", nil]
      
      parts = URI.split(@destination_server_url)
      protocol = parts[0]
      host = parts[2]
      port = parts[3]
      path = parts[5]
      
      if ( protocol != "http" && protocol != "https" )
        printf("Invalid delivery URL - bad protocol scheme\n")
      end
      
      if ( port == nil )
        port = 443
      else
        port = port.to_i
      end
      
      if ( port <= 0 )
        printf("Invalid delivery URL - bad port number")
        port = 80
      end
      
      http = Net::HTTP.new(host, port)
      http.use_ssl = true
      
      headers = Hash.new
      headers["Content-Type"] = "application/x-www-form-urlencoded"
    
      response = http.request_post( path, "scan[scan_results]=#{results}", headers)
      
    elsif ( @destination_server_url.match("^https:") != nil && NO_SSL )
      printf("Can't submit scan results to secure server: #{@destination_server_url} because we can't find OpenSSL\n")
      response = Hash.new
      response["disco"] = "0, OpenSSL not found"
    end
  
    case response
    when Net::HTTPSuccess
      # format constructed by the discovery server and added to the 'disco' header in the http post response:
      #  100, Scan saved, 16 packages
      
    when Net::HTTPBadResponse
      printf("Bad response from server while posting results")
      response["disco"] = "0, Bad response from server while posting results"
            
    else
      printf("Error result: ")
      response.each { | name, value |
        printf("%s: %s\n", name, value )
      }
    end
  
  rescue Errno::ECONNREFUSED
    printf("Can't submit scan. The connection was refused when trying to deliver the scan results.\nPlease check your network connection or contact the administrator for the server at: %s\n", @destination_server_url )
    printf("\nYour machine readable results can be found in the file: %s\n", result_file )
    response = Hash.new
    response["disco"] = "0, Connection Refused"
  end
  
  # by now there should be a response["disco"] header.  If not, then the request was sent to a non-discovery
  # server
  
  if ( response == nil || response["disco"] == nil )
    if ( response == nil )
      response = Hash.new
    end
    
    response["disco"] = "0, Improper or unexpected destination server response.  Check your destination URL to make sure it's correct"    
  end
    
  printf("Result: %s\n", response["disco"] )
  
end


=begin rdoc
  given a directory of scan results, pick off scans and deliver them
=end

def deliver_batch( result_directory )

  Find.find( result_directory ) do | results_fname |

    # printf("results fname: #{results_fname}\n")

    begin
        case
          when File.file?( results_fname )

             # do some basic validation test by spot checking for a couple of fields that are
             # expected to be in a valid results file
             results_content = File.new( results_fname, "r" ).read 

             if ( results_content.match('^type:summary') == nil ||
                  results_content.match('^denied:') == nil||
                  results_content.match('^foi:') == nil  ||
                  results_content.match('^distro:') == nil 
                )
               next
             end

             printf("sending #{results_fname}\n")
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

def make_machine_id()

  # if someone has overridden the machine id in the configuration.rb file and/or 
  # changed the current value of the machine id to anything besides "default", then
  # assume they know what they're doing and use it instead of making one
  
  # for non-windows machines, everything else is u*ix like and should support uname
  
  platform = major_platform()
  
  case platform
  when "windows", "java"     # java is what's reported if running under JRuby, 
                             # so use the simplest possible machine id regardless of "real" platform
                             # if using JRuby
    
    hostname = Socket.gethostname

    ipaddr = IPSocket.getaddress( hostname )  
    
    if ( @machine_id == "default")
      @machine_id = Digest::MD5.hexdigest( hostname + ipaddr + @company_name )
    # else use the one that was set in config.yml
    end
    
    # TODO - if we support JRuby at some point, we need to fix this so the "real" platform is determined
    # through JRuby/java and if linux or other unix, find the real kernel version
    @kernel = RUBY_PLATFORM
        
  else  # every other platform including cygwin supports uname -a
    
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
    # limitation.  If you want to control your machine ID according to your own unique scheme, override
    # it in the configuration.rb file on a machine by machine basis.

    if ( @machine_id == "default" )
      @machine_id = Digest::MD5.hexdigest( hostname + mac + @uname + @company_name + @distro )
      # else use the one set in config.yml
    end
  end

  return @machine_id, @kernel  
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

def get_os_version_str()
  
  mplat = major_platform()
  
  case mplat
  when "linux"
    return get_linux_version_str()
  when "windows"
    return get_windows_version_str()
  when "macosx"
    return get_macosx_version_str()
  when "solaris"
    return get_solaris_version_str()
  when "cygwin"
    return get_cygwin_version_str()
    
  # new platform cases go here
  
  else
    return "Unknown: Unrecognized"
  end

  
end

=begin rdoc
  return the string containing the windows version info

=end

def get_windows_version_str()
  # the windows file:
  # %systemroot%\system32\prodspec.ini
  # contains the warning to not change the contents, so should be pretty stable
  # also makes it easy to search for the bits of version info we need
  #
  # need to find out systemroot, drive, etc before going after prodspec.ini file.
  # some admins put system on drives other than C:

     
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
      @os_architecture = "TODO"
      @os_version = content.match("Version=(.*?)$")[1]
      
      return "Windows: #{product}"

   end # if
  end # do

  return "win-TODO"
end

=begin rdoc
  return the string containing the cygwin version info
=end

def get_cygwin_version_str()
  
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


def get_linux_version_str()

    @linux_distros = { 

      "/etc/annvix-release" => "Annvix",
      "/etc/arch-release" => "Arch Linux", 
      "/etc/arklinux-release" => "Arklinux", 
      "/etc/aurox-release" => "Aurox Linux", 
      "/etc/blackcat-release" => "BlackCat", 
      "/etc/cobalt-release" => "Cobalt", 
      "/etc/conectiva-release" => "Conectiva", 
      "/etc/debian_release" => "Debian", 
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

  @os_family = "linux"
          
  @linux_distros.each do | distrofile, distroname |
    
    if ( File.exist?(distrofile))
      #puts "Found distro file: #{distrofile}\n"
      File.open(distrofile, "r" ) do | file | 
	      file.each do | line |
          distro_bits = line.strip!
          if ( distro_bits == nil )
            distro_bits = line
          end
          
          # @os = distro_bits   # this will have more than we want but there is no standard first line that can be parsed
          @os = distroname      # less specific, but distro string returned will have more specifics
          
          platform = RUBY_PLATFORM 
          # ie: "x86_64-linux"
          
          @os_architecture = platform.split("-")[0]
          
          return "#{distroname}: #{distro_bits}" 
        end  # line
      end # file
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

def get_solaris_version_str()
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

def get_macosx_version_str()
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
