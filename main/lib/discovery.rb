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
# Every single property from the config.yml file is loaded as an instance variable of self.
# This is done so that this file can have default values for all of these properties, and then 
# change them if necessary based on a cli option that was specified.  So, if a default value in 
# the config.yml file is ever modified, this file will receive that modified value by default.  
# The same will happen if a new value is ever added to the config.yml.
#
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

# relative paths are relative to the main/ruby directory

@basedir = File.expand_path(File.dirname(__FILE__))
@config = 'conf/config.rb'
@copyright = "Copyright (C) 2007-2008 OpenLogic, Inc.  All Rights Reserved."
@discovery_version = "2.0-alpha-1"
@discovery_name = "discovery"
@discovery_license = "TBD"
@discovery_license_shortname = "TBD"  # GPLv3, BSD, Apache 2, whatever
@distro = "Unknown: Unrecognized"
@inclusion_filters = Hash.new
@dir_exclusion_filters = Hash.new
@file_exclusion_filters = Hash.new
@@log = Config.prop(:log)

# walker configuration parameter defaults
@list_files = false
@list_foi = false
@list_exclusions = false
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

=begin rdoc
 This is the main executive controller of discovery

   a) assumes processing command line arguments has occurred
   b) instantiates the major subsystems such as the walker and rule engine
   c) kicks off the scan
=end

def execute()

  # mark the beginning of a scan
  @starttime = Time.new

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
  
  # create the applications RuleEngine instance
  # in the process of constructing the object, the rule engine
  # will register with the walker and set up the list of files of interest
  # after this object is created, the machine is ready to scan
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
    @@log.error("#{e.to_s}")
    printf("#{e.to_s}\n")
  end
end

def validate_directory_to_scan( dir )
  @directory_to_scan << File.expand_path( dir )

  @directory_to_scan.gsub!('//','/') 

  # for some stupid reason, ruby expands a c:\ to /c:/ so if there's a drive spec in the 
  # path, strip off the leading /

  if ( @directory_to_scan =~ /:/ )
   @directory_to_scan = @directory_to_scan[1..@directory_to_scan.length]
  end

  if ( !File.exist?(@directory_to_scan ) )

   printf("The given path to scan does not exist: %s\n", dir )
   # printf("Expanded path does not exist: %s\n", @directory_to_scan )
   return false
  end

  return true
end
 

#----------------------------- command line parsing ------------------------------------------
options = GetoptLong.new(

  # please maintain these in alphabetical order
  [ "--conf", "-c", GetoptLong::REQUIRED_ARGUMENT ],           # specific conf file
  [ "--deliver-results", "-d", GetoptLong::OPTIONAL_ARGUMENT ],# existence says 'yes' deliver results to server, followed by a filename sends that file to the server  
  [ "--help", "-h", GetoptLong::NO_ARGUMENT ],                 # get help, then exit
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
  # future [ "--speed", "-s", GetoptLong::REQUIRED_ARGUMENT ], # speed hint - how much analysis to do, which rules to use
  [ "--update-rules", "-r", GetoptLong::OPTIONAL_ARGUMENT ],   # get update scan rules, and optionally perform the scan after getting them
  [ "--verbose", "-b", GetoptLong::OPTIONAL_ARGUMENT ],        # be verbose while scanning - every X files scanned  
  [ "--version", "-v", GetoptLong::OPTIONAL_ARGUMENT ]         # print version, then exit

  # TODO - would be nice to override the filter-list.rb file from the CLI
  # TODO - need to be able to throttle the scan rate so it doesn't soak CPU cycles on production boxes
)



begin
  # What's going on here?  Glad you asked.
  # 
  # Every single property from the config.yml file is loaded as an instance variable of self.
  # This is done so that this file can have default values for all of these properties, and then 
  # change them if necessary based on a cli option that was specified.
  configs = Config.configs  
  configs.each_pair {|key, value|
    self.instance_variable_set("@" + key.to_s, value)
  }

  # generate a unique and static machine id
  @machine_id, @kernel = make_machine_id()

  @distro = get_os_version_str()
  
  options.each do | opt, arg |
    case opt

    when "--conf"
      if ( File.exist?(arg) && File.file?(arg) )
        @config = arg
      else
        printf("The given configuration path does not exist or is not a file: %s\n", arg )
        exit 1
      end
  
  
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
          deliver_results( arg )
          exit 0
        else
          @machine_results = arg
          # proceed with the scan using new given filename as the machine results file
        end

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
         File.open(@results, "w") {|file|}      
       rescue Exception => e
         puts "ERROR: Unable to write to file: '#{@results}'\n"
         if ( !(File.directory?( File.dirname(@results) ) ) )
           puts"The directory " + File.dirname( @results ) + " does not exist\n"
         end
         exit 0
       end
    when "--list-os"
      printf("%s, kernel: %s\n", get_os_version_str(), @kernel )
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
         File.open(@machine_results, "w") {|file|}      
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
rescue
  printf("Unsupported option. Please review the list of supported options and usage:\n")
  @@log.error('Discovery') {"Unsupported option. Please review the list of supported options and usage: #{$!}"}
  help()
  exit 1
end

# interpret any leftover arguments as the override path
if ( ARGV.size > 0 )
  validate_directory_to_scan( ARGV[0] ) 
end

#----------------------------- do the business -------------------------------------

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
execute()

# scan is complete, do a simple report based projects evaluated by the rule engine - this 'report' method is in cliutils.rb
packages = @rule_engine.scan_complete()

# human readable report
report( packages )

if (@produce_match_audit_records) then
  report_audit_records(@rule_engine.audit_records)
end

# deal with machine reports and sending results if allowed
machine_report( packages )

if ( @send_results )
  printf("Posting results to: %s ...please wait\n", @destination_server_url )
  deliver_results( @machine_results )

end

printf("Scan complete\n")
exit 0
