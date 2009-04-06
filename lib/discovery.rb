# discovery.rb
#
# LEGAL NOTICE
# -------------
# 
# OSS Discovery is a tool that finds installed open source software.
#    Copyright (C) 2007-2009 OpenLogic, Inc.
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
# discovery.rb is the main CLI framework.  It's purpose is to:
#
#   a) process command line arguments
#   b) instantiate the major subsystems such as the walker and rule engine
#   c) kick off the scan
#   d) produce the reports
#
# Every property from the config.yml file is loaded as an instance variable of global self.
# This is done so that this file can have default values for all of these properties, and then 
# change them if necessary based on a cli option that was specified.  So, if a default value in 
# the config.yml file is ever modified, this file will receive that modified value by default.  
# The same will happen if a new value is ever added to the config.yml.
#
# Quick and dirty code architecture discussion:  
#    1) A Walker is a class which traverses the disk looking for files that match a given set of 
#       of regular expressions
#       a) The Walker derives the list of file matches it should be looking for from the RuleEngine
#    2) The RuleEngine is initialized through reading the set of project rules xml files found in
#       the lib/rules directory and subdirectories.  A project rule and its match rules defines 
#       filename regular expressions which could indicate a project is installed
#    3) The Walker looks for any file which matches one of rule's "files of interest" (FOI)
#       a) A file of interest is really a regular expression that could match any number of possible
#          files the rule could apply to.
#       b) You can see the list of patterns that make up the "files of interest" by running:
#            ./discovery --list-foi
#    4) When the Walker finds a matching file, it calls the RuleEngine with the found file
#    5) The RuleEngine will evaluate the file and apply any rule which matches that filename
#       a) There are currently 4 types of match rules depending upon the rule writer's judgement for
#          the best way to detect the project's key files.
#    6) The RuleEngine will track the match state for each of the project rules and match rules
#    7) After the Walker has completed the disk traverse, the RuleEngine contains the match states
#       of everything found
#    8) The Discovery framework then dumps a list of the match states to the console in a sorted order
#       a) optionally, the results will be delivered to an open source census server for inclusion in
#          the open source census.
#
# For more details on how the project rules work, please see the "Rule Writing for Discovery" document
# on the project web site:  http://www.ossdiscovery.org
#

$:.unshift File.join(File.dirname(__FILE__))

require 'date'
require 'getoptlong'
require 'parsedate'
require 'pp'

require 'walker.rb'
require 'cliutils.rb'
require 'rule_engine.rb'
require 'scan_rules_updater'


#--------------- global defaults ---------------------------------------------
# maintain these in alphabetical order, please

@basedir = File.expand_path(File.dirname(__FILE__))
@config = 'conf/config.rb'
@copyright = "Copyright (C) 2007-2009 OpenLogic, Inc."
@discovery_version = "2.3.0"
@discovery_name = "ossdiscovery"
@discovery_license = "GNU Affero General Public License version 3"
@discovery_license_shortname = "Affero GPLv3" 
@directories_to_scan = Array.new
@dir_exclusion_filters = Hash.new
@distro = "Unknown: Unrecognized"
@file_exclusion_filters = Hash.new
@census_code = ""
@inclusion_filters = Hash.new
@plugins_list = Hash.new
@@log = Config.prop(:log)

# walker configuration parameter defaults
@list_files = false
@list_foi = false
@list_exclusions = false

@os = "Unknown"                # distro major name "ubuntu"
@os_family = "Unknown"         # linux, windows, etc
@os_architecture = "Unknown"   # i386, x86_64, sparc, etc
@os_version = "Unknown"        # 5.04, 10.4, etc

@production_scan = false

@show_every = 1000
@show_progress = false
@show_verbose = false

@speed = -1
@rule_types = "all"

# important global objects
@rule_engine = nil
@walker = nil

# configuration file can override any of the parameters above
require "#{@basedir}/#{@config}"

require "#{@basedir}/#{Config.prop(:generic_filters)}"

# Load any plugins, meaning any file named 'init.rb' found somewhere
# under the 'plugins' directory.
def load_plugins
  plugin_files = File.join(File.dirname(__FILE__), "plugins", "**", "init.rb")
  Dir.glob(plugin_files) { |path| require path }
end

load_plugins    # always load whatever plugins are found and enabled.

=begin rdoc
 This is the main executive controller of discovery

   a) assumes processing command line arguments has occurred
   b) instantiates the major subsystems such as the walker and rule engine
   c) kicks off the scan
=end

def execute

  # mark the beginning of a scan
  @starttime = Time.new
  
  @universal_rules_md5 = ScanRulesReader.generate_aggregate_md5(File.dirname(@rules_openlogic))
  @universal_rules_version = ScanRulesReader.get_universal_rules_version()

  # create the application's Walker instance - @list_files is boolean for whether to dump files as encountered
  @walker = Walker::new
  
  if @walker == nil
    puts("FATAL - walker cannot be created")
    exit 1
  end

  # if the user sets rule_types in config.yml, we need to update our speed
  # accordingly
  set_speed(@rule_types)
  
  # setup all the walker behavior based on CLI flags
  #
  @walker.add_dir_exclusions(@dir_exclusion_filters)
  @walker.add_file_exclusions(@file_exclusion_filters.values)
  
  @walker.list_exclusions = @list_exclusions
  @walker.list_files = @list_files
  @walker.show_permission_denied = @show_permission_denied
  @walker.open_archives = @open_archives
  @walker.dont_open_discovered_archives = @dont_open_discovered_archives
  @walker.class_file_archive_extensions = @class_file_archive_extensions
  @walker.always_open_class_file_archives = @always_open_class_file_archives
  @walker.no_class_files = @no_class_files
  @walker.archive_temp_dir = @archive_temp_dir
  @walker.archive_extensions = @archive_extensions
  @walker.examine_source_files = @examine_source_files
  @walker.source_file_extensions = @source_file_extensions
  @walker.show_every = @show_every.to_i
  @walker.show_progress = @show_progress
  @walker.show_verbose = @show_verbose  
  @walker.symlink_depth = @symlink_depth
  @walker.follow_symlinks = @follow_symlinks
  @walker.throttling_enabled = @throttling_enabled
  @walker.throttle_number_of_files = @throttle_number_of_files
  @walker.throttle_seconds_to_pause = @throttle_seconds_to_pause
  @walker.starttime = @starttime
  
  # create the applications RuleEngine instance
  # in the process of constructing the object, the rule engine
  # will register with the walker and set up the list of files of interest
  # after this object is created, the machine is ready to scan
  msg = ""
  
  unless @list_foi 
    msg << "OSS Discovery is preparing to scan your machine or specified directory.\n"
    msg << "If the directory or drive being scanned contains many files this will take some time.\n"
    msg << "You can continue to work on your machine while the scan proceeds.\n"
  end
  
  msg << "Reading project rules....\n"
  puts msg
  
  @rule_engine = RuleEngine.new(@rules_dirs, @walker, @speed)

  # obey the command line parameter to list the files of interest.  this can't be done until
  # the rule engine has parsed the scan rules file so that we know all the actual files of 
  # interest determined by scan rules expressions
  
  if ( @list_foi )
    puts "Files of interest:"
    @walker.get_files_of_interest.each { | foi |
      if foi.respond_to?('source')
        puts foi.source
      else
        puts foi
      end
    }
    exit 0
  end
  
  # This is the end of setup and the start of scanning a machine

  # take a comma delimited --path option and scan each directory indepdendently
  # this lets us handle multiple drives as in:  --path C:,E:,X: 
  #
  # or multiple paths such as:
  #
  # --path /usr/bin,/opt/apache2,/opt/local
  #
  # without making the user go through an exclusions filter, or having to enumerate windows drives
  # which is problematic in Ruby for a cli app (pops up unexpected dialogs when accessing drives with no media.)

  if ( @directories_to_scan.empty? )
    @directories_to_scan << @directory_to_scan   # no --path was given so default the directory to scan from the config.yml file
  end

  # iterate through directories to scan, and walk each one
  # and accumulate the results
  #

  @directories_to_scan.each do | directory |
    directory = File.expand_path(directory)
    puts "Scanning #{directory}\n"
    @walker.walk_dir( directory )
  end

  # mark the end of a scan
  @endtime = Time.new

end

def update_scan_rules
  updater = ScanRulesUpdater.new(@server_base_url, @rules_file_base_url)
  updater.proxy_host = @proxy_host
  updater.proxy_port = @proxy_port
  updater.proxy_username = @proxy_user
  updater.proxy_password = @proxy_password
  begin
    updater.update_scanrules(@rules_openlogic, @rules_files_url_path)
  rescue Exception => e
    @@log.error("Discovery: " << e.inspect + e.backtrace.inspect.gsub("[\"", "\n\t[\"").gsub(", ", ",\n\t ")) # if there's a better/easier way to get a readable exception trace, I don't know what it is
    printf("#{e.to_s}\n")
  end
end

def validate_directory_to_scan(dir)
  dir_exists = true

  # --path can now take comma delimited path names, so break it up first, and validate each
  #
  @directories_to_scan = dir.split(",")

  dirindex = 0
  @directories_to_scan.each do | directory |
    directory = normalize_dir( directory )
    if ( !File.exist?(directory) )

      # If it doesn't exist, it may be a weirdism with ruby turning c:\ into /c:/.  So
      # make that change and try again
      
      if ( directory =~ /:/ )
  	    lastditch = directory[1..@directory_to_scan.length]
  	    if ( !File.exist?(lastditch) )
          dir_exists=false
        else
          dir_exists=true
        end
      else
          dir_exists=false
      end
    end

    unless dir_exists
      printf("The given path to scan does not exist: %s\n", directory )
      return false
    end
    @directories_to_scan[dirindex] = directory
    dirindex += 1
  end

  true
end

# Do a little trick to get the 'real' local IP address.  The trick is
# to create a UDPSocket that intends to connect to the openlogic.com
# IP address.  It doesn't actually connect, but forces the networking
# stack to figure out which local IP address is actually bound for
# external traffic.  We then ask for that IP address.
def get_local_ip  
  # turn off reverse DNS resolution temporarily
  orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true

  UDPSocket.open do |s|
    s.connect '216.24.133.139', 1
    s.addr.last
  end
rescue
  IPSocket.getaddress(Socket.gethostname)
ensure
  Socket.do_not_reverse_lookup = orig
end

# given a string, set our internal speed value
def set_speed(type)
  @speed = case type
             when "all": -1
             when "fast": 0
             when "slow": 1
             else -1
           end
end

def make_reports
  if @produce_match_audit_records
    report_audit_records @rule_engine.audit_records
  end

  if @geography.to_i < 1 || @geography.to_i > MAX_GEO_NUM
    @geography = ""
  end

  @scandata.client_version = version
  @scandata.machine_id = @machine_id
  @scandata.hostname = Socket.gethostname
  @scandata.ipaddress = get_local_ip
  @scandata.dir_ct = @walker.dir_ct
  @scandata.file_ct = @walker.file_ct
  @scandata.sym_link_ct = @walker.sym_link_ct
  @scandata.not_followed_ct = @walker.not_followed_ct
  @scandata.permission_denied_ct = @walker.permission_denied_ct
  @scandata.foi_ct = @walker.foi_ct
  @scandata.archives_found_ct = @walker.archives_found_ct
  @scandata.class_file_archives_found_ct = @walker.class_file_archives_found_ct
  @scandata.source_files_found_ct = @walker.source_files_found_ct
  @scandata.starttime = @starttime
  @scandata.endtime = @endtime
  @scandata.distro = @distro
  @scandata.os_family = @os_family
  @scandata.os = @os
  @scandata.os_version = @os_version
  @scandata.os_architecture = @os_architecture
  @scandata.kernel = @kernel
  @scandata.production_scan = @production_scan
  @scandata.universal_rules_md5 = @universal_rules_md5
  @scandata.universal_rules_version = @universal_rules_version
  @scandata.throttling_enabled = @walker.throttling_enabled
  @scandata.total_seconds_paused_for_throttling =@walker.total_seconds_paused_for_throttling
  @scandata.directories_scanned = @directories_to_scan

  @plugins_list.each do | plugin_name, aPlugin |
    if aPlugin.respond_to?(:report, false)
      # human readable report
	    aPlugin.report(aPlugin.local_report_filename, @packages, @scandata)
    end

    # if the plugin will respond to a machine report method, fire it off
    if aPlugin.respond_to?(:machine_report, false)
      aPlugin.machine_report(aPlugin.machine_report_filename, @packages, @scandata)

      if @preview_results && aPlugin.machine_report_filename != STDOUT
        printf("\nThese are the actual machine scan results from the file, %s, that would be delivered by --deliver-results option\n", destination)
        puts File.new(aPlugin.machine_report_filename).read
      end
    end

    # if the plugin will respond to a mif report method, fire it off
    if aPlugin.respond_to?(:mif_report, false)
      aPlugin.mif_report(aPlugin.mif_report_filename, @packages, @scandata)

      if @preview_results && aPlugin.mif_report_filename != STDOUT
        printf("\nThese are the actual machine scan results from the file, %s, that can be imported into Tivoli Inventory. \n", destination)
        puts File.new(aPlugin.mif_report_filename).read
      end
    end

  end
end


#----------------------------- command line parsing ------------------------------------------
options = GetoptLong.new()
options.quiet = true

options_array = Array.new

options_array << [ "--always-open-archives", "-a", GetoptLong::NO_ARGUMENT ]  # open archives even if we match against the archive file itself
options_array << [ "--always-open-class-file-archives", "-f", GetoptLong::NO_ARGUMENT ]  # open class file archives even if we match against the archive file itself
options_array << [ "--conf", "-c", GetoptLong::REQUIRED_ARGUMENT ]            # specific conf file
options_array << [ "--deliver-results", "-d", GetoptLong::OPTIONAL_ARGUMENT ] # existence says 'yes' deliver results to server, followed by a filename sends that file to the server  
options_array << [ "--deliver-batch", "-D", GetoptLong::REQUIRED_ARGUMENT ]   # argument points to a directory of scan results files to submit
options_array << [ "--help", "-h", GetoptLong::NO_ARGUMENT ]                  # get help, then exit
options_array << [ "--list-os","-o", GetoptLong::NO_ARGUMENT ] 
options_array << [ "--list-excluded", "-e", GetoptLong::NO_ARGUMENT]          # show excluded filenames during scan
options_array << [ "--list-files", "-l", GetoptLong::NO_ARGUMENT ]            # show encountered filenames during scan
options_array << [ "--list-filters", "-g", GetoptLong::NO_ARGUMENT ]          # show list of filters, then exit
options_array << [ "--list-foi", "-i", GetoptLong::NO_ARGUMENT ]              # show a list of files of interest derived from scan rules, then exit
options_array << [ "--list-plugins","-N", GetoptLong::NO_ARGUMENT ]           # list any plugins that are enabled
options_array << [ "--list-projects", "-j", GetoptLong::OPTIONAL_ARGUMENT ]   # show a list projects discovery is capable of finding
options_array << [ "--list-md5-dupes", "-M", GetoptLong::NO_ARGUMENT ]  
options_array << [ "--list-tag", "-t", GetoptLong::NO_ARGUMENT ]              # dump the MD5 hash which is the machine id tag 
options_array << [ "--no-class-files", "-C", GetoptLong::NO_ARGUMENT ]        # don't try to match against class files inside of a jar if the jar isn't recognized
options_array << [ "--nofollow", "-S", GetoptLong::NO_ARGUMENT ]              # follow symlinks?  presence of this flag says "No" don't follow
options_array << [ "--path", "-p", GetoptLong::REQUIRED_ARGUMENT ]            # scan explicit path
options_array << [ "--progress", "-x", GetoptLong::OPTIONAL_ARGUMENT ]        # show a progress indication every X files scanned
options_array << [ "--preview-results","-R", GetoptLong::OPTIONAL_ARGUMENT ]  # the existence of this flag will cause discovery to print to stdout the machine results file when scan is completed 
options_array << [ "--rule-types", "-y", GetoptLong::REQUIRED_ARGUMENT ]      # rules to use - 'all', 'fast' for ternary-tree only, 'slow' for non-ternary-tree
options_array << [ "--rule-version", "-V", GetoptLong::NO_ARGUMENT ]          # print out rule version info and do nothing else (no scan performed)
options_array << [ "--source-scan", "-s", GetoptLong::NO_ARGUMENT ]           # look inside source files for things like Java import statements
options_array << [ "--throttle", "-T", GetoptLong::NO_ARGUMENT ]              # enable production throttling (by default it is disabled)
options_array << [ "--update-rules", "-r", GetoptLong::OPTIONAL_ARGUMENT ]    # get update scan rules, and optionally perform the scan after getting them
options_array << [ "--verbose", "-b", GetoptLong::OPTIONAL_ARGUMENT ]         # be verbose while scanning - every X files scanned  
options_array << [ "--version", "-v", GetoptLong::OPTIONAL_ARGUMENT ]         # print version, then exit

# now add any plugin specific command line options to the list

@plugins_list.each do | plugin_name, aPlugin |
  options_array.concat( aPlugin.cli_options )
end

options.set_options( *options_array )


begin
   

  # Every property from the config.yml file is loaded as an instance variable of self.
  # This is done so that this file can have default values for all of these properties, and then 
  # change them if necessary based on a cli option that was specified.

  configs = Config.configs  
  configs.each_pair {|key, value|
    self.instance_variable_set("@" + key.to_s, value)
  }

  @distro = get_os_version_str
  # generate a unique and static machine id
  @machine_id = make_machine_id
  
  # defaults from config
  @scandata = ScanData.new

  options.each do | opt, arg |
  
    case opt

    when "--always-open-archives"
      @dont_open_discovered_archives = false

    when "--always-open-class-file-archives"
      @always_open_class_file_archives = true

    when "--conf"
      if ( File.exist?(arg) && File.file?(arg) )
        @config = arg
      else
        printf("The given configuration path does not exist or is not a file: %s\n", arg )
        exit 1
      end
  
    when "--deliver-batch"
      if ( !File.directory?(arg) )
        printf("#{arg} does not exist, please recheck the directory name\n")
        exit 1
      end

      # ------- TODO - refactor in terms of plugin architecture
      deliver_batch( arg )
      exit 0
  
    # existence says 'yes' deliver the machine readable results to the server
    # optional arg will either immediately deliver results if the file already exists
    # or will scan the machine and use that filename as the results file and then deliver it
    # if no results filename is given, the machine will be rescanned and results placed in the
    # default results file and then posted.
  
    when "--deliver-results"  
      @send_results = true

      if ( arg != nil && arg != "" )
        # results file was given, see if it exists.
        # if it exists, post it immediately, exit once the status code is received from the server
        # if it does not exist, scan the machine normally except use the given filename as the
        # the results file to post when the scan is complete

        if ( File.exists?(arg) )
          @immediate_filename = arg
        else
          puts "The file, #{@immediate_filename} does not exist."
          puts File.expand_path(arg)
          exit 1
        end
      end 

    when "--help"
      help()
      exit 0
      
    when "--list-os"
      printf("%s, arch: %s, kernel: %s\n", get_os_version_str(), @os_architecture, @kernel )
      exit 0
      
    when "--list-excluded"
      @list_exclusions = true
    
    when "--list-filters"
      dump_filters()
      exit 0

    when "--list-files"    
      @list_files = true
    
    when "--list-foi"    
      @list_foi = true
  
    when "--list-plugins"    

      puts "Enabled plugins:"
      @plugins_list.each do | plugin_name, aPlugin |
        puts plugin_name   		
      end

      exit 0
 
    when "--list-md5-dupes"
      ScanRulesReader.find_duplicated_md5_match_rules(@rules_dirs)      
      exit 0
      
    when "--list-projects"
 
      projects = ScanRulesReader.discoverable_projects(@rules_dirs)     
      if (arg == "verbose") then        
        puts "number,name,from,platforms,description"
        projects.each_with_index do |p, i|
          puts "#{i+1},#{p.name},#{p.from},#{p.operating_systems.to_a.inspect.gsub(", ", "|")},#{p.desc}"
        end
      else
        names = projects.collect{|p| p.name}.to_set.sort
        names.each_with_index do |name, i|
          puts "#{i+1},#{name}"
        end
      end
      
      exit 0
    
    when "--list-tag"
      printf("Unique Machine Tag (ID): %s\n", @machine_id )
      exit 0
     
    when "--no-class-files"
      @no_class_files = true

    when "--nofollow"   
      @follow_symlinks = false
      
    when "--path"

      if ( !validate_directory_to_scan( arg )  )
         exit 1
      end

    when "--progress"
        
      @show_progress = true
    
      if ( arg != "" )
        # TODO validate argument to be a positive integer > 50
        @show_every = arg.to_i
      end
    
    when "--preview-results"
      @preview_results = true
    
    when "--production-scan"
      @production_scan = true
      @@log.info('Discovery') {'This scan will be identified as a production scan.'}
    
    when "--rule-types"
      if arg && !arg.empty?
        @rule_types = arg
      end

    when "--rule-version"
      print_rule_version_info
      exit 0
      
    when "--source-scan"
      @examine_source_files = true

    when "--throttle"
      @throttling_enabled = true
      @@log.info('Discovery') {'Throttling has been enabled.'}
      
    when "--update-rules"
      if (arg == nil || arg == "") then
        @update_rules = true
        @update_rules_and_do_scan = false
      elsif (arg == "scan")
        @update_rules = true
        @update_rules_and_do_scan = true
      else
        puts "The only valid arg for the '--update-rules' option is 'scan'. You provided an arg of '#{arg}'."
        exit 1
      end

    when "--verbose"
        
      @show_verbose = true
    
      if ( arg != "" )
        # TODO validate argument to be a positive integer > 50
        @show_every = arg.to_i
      end

    when "--version"
      printf("%s\n", version() )
      exit 0
    end   # case

    # now give each plugin a whack at any command line option that was offered so it can collect 
    # additional state if needs to, not just processing it's own specific options

    @plugins_list.each do | plugin_name, aPlugin |
      aPlugin.process_cli_options( opt, arg, @scandata )
    end

  end # options do

rescue Exception => e
  if (e.is_a?(GetoptLong::InvalidOption)) then
    printf("Unsupported option. Please review the list of supported options and usage:\n")
    @@log.error('Discovery') {"Unsupported option. Please review the list of supported options and usage:"}
    @@log.error('Discovery') {e.inspect + e.backtrace.inspect.gsub("[\"", "\n\t[\"").gsub(", ", ",\n\t ")}
    help()
    exit 1
  elsif (e.is_a?(SystemExit))
    exit e.status
  else
    printf("Unexpected error (#{e.message}). Please see the log for more detailed information.\n")
    @@log.error('Discovery') {e.inspect + e.backtrace.inspect.gsub("[\"", "\n\t[\"").gsub(", ", ",\n\t ")}
    help()
    exit 1
  end
  
  
end

if defined? @immediate_filename
  printf("Immediately delivering the results file: #{@immediate_filename} ...\n")

  # plugins are responsible for determining if this file is of the type it can 
  @plugins_list.each do | plugin_name, aPlugin |
    if ( aPlugin.can_deliver? )
      aPlugin.send_file( @immediate_filename )
    end
  end

  exit 0
end


#----------------------------- do the business -------------------------------------

# If this is running under jruby, we ignore the --nofollow preference and manually set
# symlinks to not be followed.  Jruby has a lot of problems with symlinks, so we have to
# completely ignore them unless running in native ruby.
@follow_symlinks = false if RUBY_PLATFORM =~ /java/
#if RUBY_PLATFORM =~ /java/
#  require 'java'
#  puts "Java Version: #{java.lang.System.getProperty('java.version')}"
#end

# make sure all files are writable so we don't scan first and then blow out on writing results
@plugins_list.each do | plugin_name, aPlugin |
  if ( aPlugin.respond_to?(:test_file_permissions, false) )
    aPlugin.test_file_permissions()
  end
end
      
# test access to the destination_url for posting to make sure we can get out ok
# pre-check and warn if server cannot be reached
if ( @send_results )
  @plugins_list.each do | plugin_name, aPlugin |
    if ( aPlugin.can_deliver? && (check_network_connectivity(aPlugin.destination_server_url) == false) ) # checks to see if scan results post server is reachable.
      puts "\nOSS Discovery could not contact the #{aPlugin.class} server.   It's likely that you are operating behind a proxy.  "
      puts "The scan will continue, but you will need to manually post your scan results.\n"
      puts "The URL used to contact the server is: #{aPlugin.destination_server_url}"
      if ( aPlugin.upload_url != nil )
        puts "Manual upload URL: #{aPlugin.upload_url}\n\n"
      end
      puts "Could not reach destination URL: #{aPlugin.destination_server_url}"
    end
  end
end

if ( @update_rules ) then
  do_a_scan = "Finished getting the updated rules, going on to perform a scan.\n"
  just_update_rules = "Finished getting the updated rules, no scan being performed.\n"
  
  # get the updated rules from the server
  begin 
    printf("Getting the updated scan rules from the server.\n")
    update_scan_rules()
  rescue => e
    error_msg =  "An error occured while attempting to get the updated scan rules.\n"
    error_msg << "  error: #{e.message}\n"
    error_msg << "  The original scan rules should still be in affect.\n"
    printf(error_msg)
    @@log.error(e.inspect + e.backtrace.inspect.gsub("[\"", "\n\t[\"").gsub(", ", ",\n\t ")) # if there's a better/easier way to get a readable exception trace, I don't know what it is
    do_a_scan = "Going on to perform a scan using the original scan rules.\n"
    just_update_rules = "No scan being performed.\n"
  end
  
  if (@update_rules_and_do_scan) then
    # go on and do the business below starting with 'execute()'
    printf(do_a_scan)
  else
    printf(just_update_rules)
    exit 0
  end
end


# execute a scan
execute

# scan is complete, tell rule engine
@packages = @rule_engine.scan_complete

# pass all the scan data to plugins to build their reports files
make_reports

# now all reports will live in their own files based on plugin configurations
# if --deliver-results is active ask each plugin to post their results files

if @send_results
  @plugins_list.each do | plugin_name, aPlugin |
    if ( aPlugin.can_deliver?)
      aPlugin.send_results()
     end
  end
end

puts "\nOSS Discovery has completed the scan\n"

