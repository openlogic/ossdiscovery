# discovery.rb
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
@copyright = "Copyright (C) 2007 OpenLogic, Inc."
@discovery_version = "2.0-alpha-4"
@discovery_name = "discovery"
@discovery_license = "GNU Affero General Public License version 3"
@discovery_license_shortname = "Affero GPLv3" 
@dir_exclusion_filters = Hash.new
@distro = "Unknown: Unrecognized"
@file_exclusion_filters = Hash.new
@census_code = ""
@inclusion_filters = Hash.new
@@log = Config.prop(:log)

# walker configuration parameter defaults
@list_files = false
@list_foi = false
@list_exclusions = false

@os = "Unknown"                # distro major name "ubuntu"
@os_family = "Unknown"         # linux, windows, etc
@os_architecture = "Unknown"   # i386, x86_64, sparc, etc
@os_version = "Unknown"        # 5.04, 10.4, etc

@show_every = 1000
@show_progress = false
@show_verbose = false

# used to help validate speed values in various subsystems
@valid_speeds = 1
SPEEDHINT = 1 unless defined?(SPEEDHINT)

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

load_plugins if Config.prop(:load_plugins)

=begin rdoc
 This is the main executive controller of discovery

   a) assumes processing command line arguments has occurred
   b) instantiates the major subsystems such as the walker and rule engine
   c) kicks off the scan
=end

def execute()

  # mark the beginning of a scan
  @starttime = Time.new
  
  @universal_rules_md5 = ScanRulesReader.generate_aggregate_md5(File.dirname(@rules_openlogic))
  @universal_rules_version = ScanRulesReader.get_universal_rules_version()

  # create the application's Walker instance - @list_files is boolean for whether to dump files as encountered
  @walker = Walker::new( )
  
  if ( @walker == nil )
    printf("FATAL - walker cannot be created\n")
    exit 1
  end
  
  # setup all the walker behavior based on CLI flags
  #
  # exclusion filters is a hash of descriptions/regexs, so just pass the criteria to the walker
  @walker.add_dir_exclusions( @dir_exclusion_filters.values )
  @walker.add_file_exclusions( @file_exclusion_filters.values )
  
  @walker.list_exclusions = @list_exclusions
  @walker.list_files = @list_files
  @walker.show_permission_denied = @show_permission_denied
  @walker.show_every = @show_every.to_i
  @walker.show_progress = @show_progress
  @walker.show_verbose = @show_verbose  
  @walker.symlink_depth = @symlink_depth
  @walker.follow_symlinks = @follow_symlinks
  @walker.throttling_enabled = @throttling_enabled
  @walker.throttle_number_of_files = @throttle_number_of_files
  @walker.throttle_seconds_to_pause = @throttle_seconds_to_pause
  
  # create the applications RuleEngine instance
  # in the process of constructing the object, the rule engine
  # will register with the walker and set up the list of files of interest
  # after this object is created, the machine is ready to scan
  puts "Reading project rules....\n"
  @rule_engine = RuleEngine.new(  @rules_dirs, @walker, SPEEDHINT )
#  @rule_engine = RuleEngine.new(  @rules_dirs, @walker, @speedhint ) - future, whenever 'speedhint' gets added back to config.yml

  # obey the command line parameter to list the files of interest.  this can't be done until
  # the rule engine has parsed the scan rules file so that we know all the actual files of 
  # interest determined by scan rules expressions
  
  if ( @list_foi )
    printf("Files of interest:\n")
    @walker.get_files_of_interest.each { | foi |
      printf("%s\n", foi.source)
    }
    exit 0
  end
  
  # This is the main call to start scanning a machine
  @directory_to_scan = File.expand_path(@directory_to_scan)
  puts "Scanning #{@directory_to_scan}\n"
  @walker.walk_dir( @directory_to_scan )

  # mark the end of a scan
  @endtime = Time.new

end

def update_scan_rules()
  updater = ScanRulesUpdater.new(@server_base_url)
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

def validate_directory_to_scan( dir )
  
  # Some versions of ruby have trouble when expanding a path with backslashes.
  # In windows, replace all backslashes with forward slashes.
  if major_platform =~ /windows/
    dir=dir.gsub!('\\','/')
  end
  
  @directory_to_scan = File.expand_path( dir )
  
  @directory_to_scan.gsub!('//','/') 
  
  dir_exists=true
  
  if ( !File.exist?(@directory_to_scan ) )
    
    # If it doesn't exist, it may be a weirdism with ruby turning c:\ into /c:/.  So 
    # make that change and try again
    
    if ( @directory_to_scan =~ /:/ )
      @directory_to_scan = @directory_to_scan[1..@directory_to_scan.length]
      if ( !File.exist?(@directory_to_scan) )
        dir_exists=false
      else
        dir_exists=true
      end
    else
      dir_exists=false
    end
    
  end
  
  if not dir_exists
    printf("The given path to scan does not exist: %s\n", dir )
    # printf("Expanded path does not exist: %s\n", @directory_to_scan )
    return false
  else
    return true
  end
  
end
 

#----------------------------- command line parsing ------------------------------------------
options = GetoptLong.new(

  # please maintain these in alphabetical order
  [ "--conf", "-c", GetoptLong::REQUIRED_ARGUMENT ],           # specific conf file
  [ "--deliver-results", "-d", GetoptLong::OPTIONAL_ARGUMENT ],# existence says 'yes' deliver results to server, followed by a filename sends that file to the server  
  [ "--deliver-batch", "-D", GetoptLong::REQUIRED_ARGUMENT ],  # argument points to a directory of scan results files to submit
  [ "--help", "-h", GetoptLong::NO_ARGUMENT ],                 # get help, then exit
  [ "--geography", "-Y", GetoptLong::REQUIRED_ARGUMENT ],      # geography code 
  [ "--census-code","-C", GetoptLong::REQUIRED_ARGUMENT ],     # identifier representing the census code
  [ "--human-results","-u", GetoptLong::REQUIRED_ARGUMENT ],   # path to results file
  [ "--list-os","-o", GetoptLong::NO_ARGUMENT ],               # returns the same os string that will be reported with machine scan results
  [ "--list-excluded", "-e", GetoptLong::NO_ARGUMENT],         # show excluded filenames during scan
  [ "--list-files", "-l", GetoptLong::NO_ARGUMENT ],           # show encountered filenames during scan
  [ "--list-filters", "-g", GetoptLong::NO_ARGUMENT ],         # show list of filters, then exit
  [ "--list-foi", "-i", GetoptLong::NO_ARGUMENT ],             # show a list of files of interest derived from scan rules, then exit
  [ "--list-projects", "-j", GetoptLong::OPTIONAL_ARGUMENT ],  # show a list projects discovery is capable of finding
  [ "--list-md5-dupes", "-M", GetoptLong::NO_ARGUMENT ], # 
  [ "--list-tag", "-t", GetoptLong::NO_ARGUMENT ],             # dump the MD5 hash which is the machine id tag 
  [ "--machine-results","-m", GetoptLong::REQUIRED_ARGUMENT ], # path to results file
  [ "--nofollow", "-S", GetoptLong::NO_ARGUMENT ],             # follow symlinks?  presence of this flag says "No" don't follow
  [ "--inc-path", "-I", GetoptLong::NO_ARGUMENT ],             # existence of this flag says to include location (path) in results
  [ "--path", "-p", GetoptLong::REQUIRED_ARGUMENT ],           # scan explicit path
  [ "--progress", "-x", GetoptLong::OPTIONAL_ARGUMENT ],       # show a progress indication every X files scanned
  [ "--preview-results","-R", GetoptLong::OPTIONAL_ARGUMENT ], # the existence of this flag will cause discovery to print to stdout the machine results file when scan is completed 
  [ "--production-scan","-P", GetoptLong::NO_ARGUMENT ],       # This flag identifies the scan you run as a scan of a production machine in the results.
  # future [ "--speed", "-s", GetoptLong::REQUIRED_ARGUMENT ], # speed hint - how much analysis to do, which rules to use
  [ "--rule-version", "-V", GetoptLong::NO_ARGUMENT ],         # print out rule version info and do nothing else (no scan performed)
  [ "--throttle", "-T", GetoptLong::NO_ARGUMENT ],             # enable production throttling (by default it is disabled)
  [ "--update-rules", "-r", GetoptLong::OPTIONAL_ARGUMENT ],   # get update scan rules, and optionally perform the scan after getting them
  [ "--verbose", "-b", GetoptLong::OPTIONAL_ARGUMENT ],        # be verbose while scanning - every X files scanned  
  [ "--version", "-v", GetoptLong::OPTIONAL_ARGUMENT ]         # print version, then exit

  # TODO - would be nice to override the filter-list.rb file from the CLI
  # TODO - need to be able to throttle the scan rate so it doesn't soak CPU cycles on production boxes
)



# begin
   
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
  
  options.each do | opt, arg |

    case opt

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
          printf("Immediately delivering the results file: #{arg} ...\n")

          # don't need to enforce geography check on cli because by delivering files, that geography would
          # have already been validated.  Also, if the scan_results geography is invalid, the server
          # will reject the scan

          deliver_results( arg )
          exit 0
        else
          puts "The file you specified to be delivered to the census server does not exist."
          puts File.expand_path(arg)
          exit 1
        end
      end

      # if deliverying anonymous results (no group passcode), then the geography option is required
      if ( (@census_code == nil || @census_code == "") && (@geography == nil || (@geography.to_i < 1 || @geography.to_i > 9)) )
        printf("\nScan not completed\n")
        printf("\nWhen delivering anonymous results to the OSSCensus server, the geography must be defined\n")
        printf("  use --geography to specify the geography code or \n")
        printf("  modify the geography property in the config.yml file\n")
        printf("  Geography codes for the --geography option are:\n")
        printf( show_geographies() )
        printf("\n  --geography is an order dependent parameter and must be used before the --deliver-results parameter\n")
        printf("If you are registered with the OSSCensus site and have a group passcode or token, you should set that \n")
        printf("on the command line or add it to your config.yml file.\n")
        exit 1
      elsif ( @census_code != "" && @geography.to_i == 100 )
        # default the geography to "" if group passcode is supplied but geography was not overridden
        # geography will be associated on the server side using the census-code
        @geography = ""
      end
  
      begin
        File.open(@machine_results, "w") {|file|}      
      rescue Exception => e
        puts "ERROR: Unable to access file: '#{@machine_results}'"
        exit 1
      end    

    when "--help"
      help()
      exit 0
      
    when "--inc-path"
      @include_paths = true      
    
    when "--human-results"
       # Test access to the results directory/filename before performing 
       # any scan.  This meets one of the requirements for disco 2 which is to not perform
       # a huge scan and then bomb at the end because the results can't be written

       # need to do a test file create/write - if it succeeds, proceed
       # if it fails, bail now so you don't end up running a scan when there's no place
       # to put the results

       @results = arg
       begin
         # Issue 34: only open as append in this test so we do not blow away an existing results file
         File.open(@results, "a") {|file|}      
       rescue Exception => e
         puts "ERROR: Unable to write to file: '#{@results}'\n"
         if ( !(File.directory?( File.dirname(@results) ) ) )
           puts "The directory " + File.dirname( @results ) + " does not exist\n"
         end
         exit 0
       end

    when "--geography"
       @geography = arg

       if ( @geography.to_i < 1 || @geography.to_i > 9 )
          printf("Invalid geography #{@geography}\n")
          printf(show_geographies())
          exit 1
       end

    when "--census-code"
        @census_code = arg
        # TODO - validation of census code format

	# if geography is undefined and a census_code is supplied, geography should be empty
        if ( @geography.to_i < 1 || @geography.to_i > 9 )
          @geography = ""  
        end

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
    
    when "--machine-results"
       # Test access to the results directory/filename before performing 
       # any scan.  This meets one of the requirements for disco 2 which is to not perform
       # a huge scan and then bomb at the end because the results can't be written

       # need to do a test file create/write - if it succeeds, proceed
       # if it fails, bail now so you don't end up running a scan when there's no place
       # to put the results

       @machine_results = arg
       begin
         File.open(@machine_results, "a") {|file|}      
       rescue Exception => e
         puts "ERROR: Unable to write to file: '#{@machine_results}'"
         if ( !(File.directory?( File.dirname(@machine_results) ) ) )
           puts"The directory " + File.dirname( @machine_results ) + " does not exist\n"
         end
         exit 0
       end  
     
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
    
    when "--rule-version"
      print_rule_version_info
      exit 0
      
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
  end # options do

# rescue Exception => e
#   printf("Unsupported option. Please review the list of supported options and usage:\n")
#   @@log.error('Discovery') {"Unsupported option. Please review the list of supported options and usage: #{$!}"}
#   @@log.error('Discovery') {"#{e.message}\n#{e.backtrace}"}
#   puts "#{e.message}\n#{e.backtrace}"
#   help()
#   exit 1
# end

# interpret any leftover arguments as the override path
if ( ARGV.size > 0 )
  if ( ARGV[0] != "" )
    validate_directory_to_scan( ARGV[0] ) 
  end
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

# Immediately check to see if the machine results output file is writeable.  If it is not, don't be a hack and do the scan anyway.
begin
  File.open(@machine_results, "w") {|file|}      
rescue Exception => e
  puts "ERROR: Unable to write to machine results file: '#{@machine_results}'. This file must be writeable before a scan can be performed."
  exit 1
end

if (@update_rules) then
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

# scan is complete, do a simple report based projects evaluated by the rule engine - this 'report' method is in cliutils.rb
@packages = @rule_engine.scan_complete

def make_reports
  # human readable report
  report @packages

  if @produce_match_audit_records
    report_audit_records @rule_engine.audit_records
  end

  if ( @geography.to_i < 1 || @geography.to_i > 9 )
     @geography = ""
  end

  # machine_report method is no longer defined in cliutils.rb -- see the 'TODO technical debt' in census_utils.rb
  if (Object.respond_to?(:machine_report, true)) then
    # deal with machine reports and sending results if allowed
    machine_report(@machine_results, @packages, version, @machine_id,
                 @walker.dir_ct, @walker.file_ct, @walker.sym_link_ct,
                 @walker.permission_denied_ct, @walker.foi_ct,
                 @starttime, @endtime, @distro, @os_family, @os,
                 @os_version, @os_architecture, @kernel, @production_scan,
                 @include_paths, @preview_results, @census_code,
                 @universal_rules_md5, @universal_rules_version, @geography )
  end
end

make_reports

if @send_results
  deliver_results @machine_results
end

puts "Scan complete"
exit 0

