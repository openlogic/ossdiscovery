# olex_plugin.rb
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
# You can learn more about OSSDiscovery or contact the team at www.ossdiscovery.com.
# You can contact OpenLogic at info@openlogic.com.
#
#--------------------------------------------------------------------------------------------------

require 'erb'
require 'digest/md5'
require 'integrity'
require 'scan_data'
require "pathname"
require 'getoptlong'

# define a count method on Array to pull a set of unique indexes with a count of matches for each index to count duplicate package matches
class Array
  def count
    k=Hash.new(0)
    self.each{|x| k[x]+=1 }
    k
  end
end

class OlexPlugin

  # where to link packages to on the OLEX production site
  OLEX_PREFIX = "http://olex.openlogic.com/packages/" unless defined? OLEX_PREFIX

  attr_accessor :olex_machine_file, :olex_local_detailed_file, :enable_olex_links, :no_paths, :show_base_dirs, :show_rollup

  def initialize

    @show_rollup = false
    @olex_machine_file = OlexConfig.machine_report 
    @olex_local_detailed_file = OlexConfig.local_report
    @olex_local_rollup_file = OlexConfig.local_rollup_report
    @olex_mif_file = OlexConfig.mif_report
    @enable_olex_links = OlexConfig.enable_olex_links || false
    @no_paths = OlexConfig.no_paths || false
    @show_base_dirs = OlexConfig.show_base_dirs || false
    @plugin_version = OLEX_PLUGIN_VERSION_KEY

  end 

  def plugin_version
    return @plugin_version
  end

  #--- mandatory methods for a plugin ---
  def cli_options
    clioptions_array = Array.new
    clioptions_array << [ "--olex-local","-u", GetoptLong::REQUIRED_ARGUMENT ]   # formerly --human-results
    clioptions_array << [ "--olex-results","-m", GetoptLong::REQUIRED_ARGUMENT ] # formerly --machine-results
    clioptions_array << [ "--olex-rollup","-z", GetoptLong::OPTIONAL_ARGUMENT ]    # turn on rollup output and optionally use output rollup file
    clioptions_array << [ "--olex-mif-file","-Z", GetoptLong::REQUIRED_ARGUMENT ]  # output mif file for tivoli inventory integration
    clioptions_array << [ "--olex-links", "-L", GetoptLong::NO_ARGUMENT ]        # turn on showing http olex links in results
    clioptions_array << [ "--no-paths", "-P", GetoptLong::NO_ARGUMENT ]          # turn on to only show file names
    clioptions_array << [ "--show-base-dirs", "-B", GetoptLong::NO_ARGUMENT ]    # turn on to show path to scanned directories
  end

  def process_cli_options( opt, arg, scandata )
    # all plugins will have the chance to process any command line option, not just their own additions
    # this allows plugins to gather any state if they need from the command line

    case opt

    when "--olex-local"
       # Test access to the results directory/filename before performing 
       # any scan.  This meets one of the requirements for disco 2 which is to not perform
       # a huge scan and then bomb at the end because the results can't be written

       # need to do a test file create/write - if it succeeds, proceed
       # if it fails, bail now so you don't end up running a scan when there's no place
       # to put the results

       @olex_local_detailed_file = arg
       begin
         # Issue 34: only open as append in this test so we do not blow away an existing results file
         File.open(@olex_local_detailed_file, "a") {|file|}
       rescue Exception => e
         puts "ERROR: Unable to write to file: '#{@olex_local_detailed_file}'\n"
         if ( !(File.directory?( File.dirname(@olex_local_detailed_file) ) ) )
           puts "The directory " + File.dirname(@olex_local_detailed_file) + " does not exist\n"
         end
         exit 0
       end

    when "--olex-results"
       # Test access to the results directory/filename before performing 
       # any scan.  This meets one of the requirements for disco 2 which is to not perform
       # a huge scan and then bomb at the end because the results can't be written

       # need to do a test file create/write - if it succeeds, proceed
       # if it fails, bail now so you don't end up running a scan when there's no place
       # to put the results

       @olex_machine_file = arg
       begin
         # Issue 34: only open as append in this test so we do not blow away an existing results file
         File.open(@olex_machine_file, "a") {|file|}      
       rescue Exception => e
         puts "ERROR: Unable to write to file: '#{@olex_machine_file}'\n"
         if ( !(File.directory?( File.dirname(@olex_machine_file) ) ) )
           puts "The directory " + File.dirname(@olex_machine_file) + " does not exist\n"
         end
         exit 0
       end

    when "--olex-rollup"
       # Test access to the results directory/filename before performing
       # any scan.  This meets one of the requirements for disco 2 which is to not perform
       # a huge scan and then bomb at the end because the results can't be written

       # need to do a test file create/write - if it succeeds, proceed
       # if it fails, bail now so you don't end up running a scan when there's no place
       # to put the results

       @show_rollup = true
       @olex_local_rollup_file = arg if ( !arg.nil? && !arg.empty?)

       begin
         # Issue 34: only open as append in this test so we do not blow away an existing results file
         File.open(@olex_local_rollup_file, "a") {|file|}
       rescue Exception => e
         puts "ERROR: Unable to write to file: '#{@olex_local_rollup_file}'\n"
         if ( !(File.directory?( File.dirname(@olex_local_rollup_file) ) ) )
           puts "The directory " + File.dirname(@olex_local_rollup_file) + " does not exist\n"
         end
        exit 0
       end

    when "--olex-mif-file"
       # Test access to the results directory/filename before performing
       # any scan.  This meets one of the requirements for disco 2 which is to not perform
       # a huge scan and then bomb at the end because the results can't be written

       # need to do a test file create/write - if it succeeds, proceed
       # if it fails, bail now so you don't end up running a scan when there's no place
       # to put the results

       @olex_mif_file = arg
       begin
         # Issue 34: only open as append in this test so we do not blow away an existing results file
         File.open(@olex_mif_file, "a") {|file|}
       rescue Exception => e
         puts "ERROR: Unable to write to file: '#{@olex_mif_file}'\n"
         if ( !(File.directory?( File.dirname(@olex_mif_file) ) ) )
           puts "The directory " + File.dirname(@olex_mif_file) + " does not exist\n"
         end
         exit 0
       end


    when "--olex-links"
      # Instead of showing just package ID's in the on-screen report, show HTTP links
      # to the package on the live OLEX production site.  This makes it easy for
      # Linux users to quickly see details on a discovered package.
      @enable_olex_links = true

    when "--no-paths"
      # Instead of showing full paths to discovered package files, only show
      # the file name that was "discovered".
      @no_paths = true

    when "--show-base-dirs"
      # Show full paths to discovered package files instead of showing
      # paths relative to the scanned directory.
      @show_base_dirs = true
    end

  end
  #--------------------------------------------------

  #--- optional methods for a plugin ---
  def machine_report_filename
    @olex_machine_file
  end

  def local_report_filename
    @olex_local_file
  end

  def local_rollup_report_filename
    @olex_local_rollup_file
  end

  def mif_report_filename
    @olex_mif_file
  end

  def can_deliver?
    false
  end

=begin rdoc
  Output the report we'll submit to the olex server.
=end
  def machine_report(destination, packages, scandata )
    # for now, source scan is experimental and so if that flag is on we can't
    # send results up to OLEX
    return if scandata.source_scan

    io = nil
    if ( destination == STDOUT) then
      io = STDOUT
    else
      io = File.new( destination, "w")
    end

    template = %{
      report_type:             olex
      olex_plugin_version:     <%= OLEX_PLUGIN_VERSION %>
      client_version:          <%= scandata.client_version %>
      ipaddress:               <%= scandata.ipaddress %>
      hostname:                <%= scandata.hostname %>
      machine_id:              <%= scandata.machine_id %>
      directory_count:         <%= scandata.dir_ct %>
      file_count:              <%= scandata.file_ct %>
      sym_link_count:          <%= scandata.sym_link_ct %>
      permission_denied_count: <%= scandata.permission_denied_ct %>
      files_of_interest:       <%= scandata.foi_ct %>
      start_time:              <%= scandata.starttime.to_i %>
      end_time:                <%= scandata.endtime.to_i %>
      elapsed_time:            <%= scandata.endtime - scandata.starttime %>
      packages_found_count:    <%= packages.length %>
      distro:                  <%= scandata.distro %>
      os_family:               <%= scandata.os_family %>
      os:                      <%= scandata.os %>
      os_version:              <%= scandata.os_version %>
      machine_architecture:    <%= scandata.os_architecture %>
      kernel:                  <%= scandata.kernel %>
      ruby_platform:           <%= RUBY_PLATFORM %>
      group_code:              <%= @group_code %>
      universal_rules_md5:     <%= scandata.universal_rules_md5 %>
      universal_rules_version: <%= scandata.universal_rules_version %>
      package,version,location
      % if packages.length > 0
      %   packages.sort.each do |package|
      %     package.version.gsub!(" ", "")
      %     if ( package.version.to_s.match(/[<!,&>]/) != nil )
      %       package.version.gsub!(/[<!,&>]/, "")   # strip xml or csv type chars out
      %       package.version.chomp!                 # strip any carriage return from version string
      %     end
      %     package.version.tr!("\0", "")
          <%= package.name %>,<%= package.version %>,<%= package.found_at %>
      %   end
      % end
    }

    # strip off leading whitespace and compress all other spaces in
    # the rendered template so it's more efficient for sending
    template = template.gsub(/^\s+/, "").squeeze(" ")
    text = ERB.new(template, 0, "%").result(binding)

    printf(io, "integrity_check: #{Integrity.create_integrity_check(text,"",OLEX_PLUGIN_VERSION_KEY)}\n")

    # TODO - when a rogue rule runs afoul and matches too much text on a package, it will blow chunks here
    begin
      printf(io, text )
    rescue Exception => e
      printf("Sorry, can't write the machine report\n#{e.to_s}\n")
    end

    io.close unless io == STDOUT

  end

=begin rdoc
  Output the report in a mif file format for tivoli inventory integration
=end
  def mif_report(destination, packages, scandata )
    io = nil
    if (destination == STDOUT) then
      io = STDOUT
    else
      io = File.new(destination, "w")
    end

    template = %{START COMPONENT
NAME= "OSSDiscovery OLEX Application Scan MIF"
  START GROUP
    NAME = "OPEN_SOURCE"
    CLASS = "OSSDISCOVERY|OPEN_SOURCE|<%= scandata.client_version[14..-1] %>"
    START ATTRIBUTE
      NAME = "Package_Id"
      ID = 1
      TYPE = STRING(64)
      VALUE = ""
    END ATTRIBUTE
    START ATTRIBUTE
      NAME = "Version"
      ID = 2
      TYPE = STRING(64)
      VALUE = ""
    END ATTRIBUTE
    START ATTRIBUTE
      NAME = "File_Path"
      ID = 3
      TYPE = STRING(1024)
      VALUE = ""
    END ATTRIBUTE
    START ATTRIBUTE
      NAME = "File_Name"
      ID = 4
      TYPE = STRING(256)
      VALUE = ""
    END ATTRIBUTE
    KEY = 1,2
  END GROUP
  START TABLE
    NAME = "OPEN_SOURCE"
    ID = 1
    CLASS = "OSSDISCOVERY|OPEN_SOURCE|<%= scandata.client_version %>"
% if packages.length > 0
%   packages.sort.each do |package|
%     package.version.gsub!(" ", "")
%     if ( package.version.to_s.match(/[<!,&>]/) != nil )
%       package.version.gsub!(/[<!,&>]/, "")   # strip xml or csv type chars out
%       package.version.chomp!                 # strip any carriage return from version string
%     end
%     package.version.tr!("\0", "")
    {"<%= package.name %>","<%= package.version %>","<%= package.found_at %>","<%= package.file_name %>"}
%   end
% end
  END TABLE
END COMPONENT

}

    text = ERB.new(template, 0, "%").result(binding)

    # TODO - when a rogue rule runs afoul and matches too much text on a package, it will blow chunks here
    begin
      printf(io, text )
    rescue Exception => e
      printf("Sorry, can't write the mif report\n#{e.to_s}\n")
    end

    io.close unless io == STDOUT

  end

=begin rdoc
    dumps a simple ASCII text report including every individual match
=end
  def report( destination, packages, scandata  )
    detailed_io = File.new(@olex_local_detailed_file, "w")
    rollup_io = File.new(@olex_local_rollup_file, "w")


    scan_ftime = scandata.endtime - scandata.starttime  # seconds
    scan_hours = (scan_ftime/3600).to_i
    scan_min = ((scan_ftime -  (scan_hours*3600))/60).to_i
    scan_sec = scan_ftime - (scan_hours*3600) - (scan_min*60)

    throttling_enabled_or_disabled = nil
    if ( scandata.throttling_enabled) then
      throttling_enabled_or_disabled = 'enabled'
    else
      throttling_enabled_or_disabled = 'disabled'
    end

    # pull out unique names for the rollup report
    #unique_packages = packages.collect { |pkg| pkg.name }.uniq
    unique_packages = packages.collect { |pkg| pkg.name }.count.sort

    # this is the longest version we will report in case our version matchers come back with a really long match
    max_version_length = 32

    header_template= %{
OSSDiscovery OLEX Application Scanner Report
============================================

client version          : <%= scandata.client_version %>
ip address              : <%= scandata.ipaddress %>
hostname                : <%= scandata.hostname %>
directories walked      : <%= scandata.dir_ct %>
files encountered       : <%= scandata.file_ct %>
archives encountered    : <%= scandata.archives_found_ct %>
class file archives     : <%= scandata.class_file_archives_found_ct %>
source files            : <%= scandata.source_files_found_ct %>
symlinks found          : <%= scandata.sym_link_ct %>
symlinks not followed   : <%= scandata.not_followed_ct %>
bad symlinks found      : <%= scandata.bad_link_ct %>
permission denied       : <%= scandata.permission_denied_ct %>
files examined          : <%= scandata.foi_ct %>
start time              : <%= scandata.starttime.asctime %>
end time                : <%= scandata.endtime.asctime %>
scan time               : <%= scan_hours.to_s.rjust(2,'0') %>:<%= scan_min.to_s.rjust(2,'0') %>:<%= scan_sec.round.to_s.rjust(2,'0') %>
distro                  : <%= scandata.distro %>
kernel                  : <%= scandata.kernel %>
anonymous machine hash  : <%= scandata.machine_id %>
package instances found : <%= packages.length %>
unique packages found   : <%= unique_packages.length %>
throttling              : <%= throttling_enabled_or_disabled %> (total seconds paused: <%= scandata.total_seconds_paused_for_throttling %>)
production machine      : <%= scandata.production_scan %>

}

     detailed_report_template = %{
%    if ( packages.length > 0 )
%      # Format the output by making sure the columns are lined up so it's easier to read.
%      longest_name = "Package Name".length
%      longest_version = "Version".length
%
%      packages.each do |package|
%        if ( package.version.length < max_version_length )
%          longest_name = package.name.length if (package.name.length > longest_name)
%          longest_version = package.version.length if (package.version.length > longest_version)
%        end
%      end # of packages.each
%
%      longest_url = longest_name + OLEX_PREFIX.length
%
%      if @enable_olex_links
<%= "Package Name".ljust(longest_name) %> <%= "Version".ljust(longest_version) %> <%= "OLEX Package URL".ljust(longest_url) %> Location
<%= "============".ljust(longest_name) %> <%= "=======".ljust(longest_version) %> <%= "================".ljust(longest_url) %> ========
%      else
<%= "Package Name".ljust(longest_name) %> <%= "Version".ljust(longest_version) %> Location
<%= "============".ljust(longest_name) %> <%= "=======".ljust(longest_version) %> ========
%      end
%
%      packages.to_a.sort!.each do |package|
%        begin
%          if package.version.size > max_version_length
Possible error in rule: <%= package.name %> ... matched version text was too large (<%= package.version.size %> characters)
%            @@log.error("Possible error in rule: <%= package.name %> ... matched version text was too large (<%= package.version.size %> characters) - matched version: '<%= package.version %>'")
%          else
%            if @enable_olex_links
<%= package.name.ljust(longest_name) %> <%= package.version.ljust(longest_version) %> <%= link_to_olex(package.name).ljust(longest_url) %> <%= package_location(package, scandata.directories_scanned) %>
%            else
<%= package.name.ljust(longest_name) %> <%= package.version.ljust(longest_version) %> <%= package_location(package, scandata.directories_scanned) %>
%            end
%          end
%        rescue Exception => e
Possible error in rule: <%= package.name %>
because: <%= e.inspect %>
%        end
%      end # of packages.each
%    end


To show only file names of discovered files, run discovery with --no-paths
To show full paths to discovered files, run discovery with --show-base-dirs
To show OLEX web site links for discovered packages, run discovery with --olex-links

NOTE: OSSDiscovery with the OLEX plugin uses the fast rules by default.  To do a
slower, but more accurate search, run discovery with --rule-types=all

}

     rollup_report_template = %{
%    if ( packages.length > 0 )
%      # Format the output by making sure the columns are lined up so it's easier to read.
%      longest_entry = "Package Name (#)".length
%
%      unique_packages.each do | pkg |
%        longest_entry = (pkg[0].length + pkg[1].to_s.length + 3) if ((pkg[0].length + pkg[1].to_s.length + 3) > longest_entry)
%      end # of uniq packages.each
%
%      if @enable_olex_links
<%= "Package Name (#)".ljust(longest_entry) %> OLEX Package URL
<%= "================".ljust(longest_entry) %> ================
%      else
<%= "Package Name" %>
<%= "============" %>
%      end
%
%      unique_packages.each do | pkg |
%        begin
%          if @enable_olex_links
%            pkg_text = pkg[0] + " (" + pkg[1].to_s + ")"
<%= pkg_text.ljust(longest_entry) %> <%= link_to_olex(pkg[0]) %>
%          else
<%= pkg[0] %> (<%= pkg[1].to_s %>)
%          end
%        rescue Exception => e
Possible error in rule: <%= pkg[0] %>
because: <%= e.inspect %>
%        end
%      end # of packages.each
%    end


To show OLEX web site links for discovered packages, run discovery with --olex-links

NOTE: OSSDiscovery with the OLEX plugin uses the fast rules by default.  To do a
slower, but more accurate search, run discovery with --rule-types=all

}

    header_text = ERB.new(header_template, 0, "%").result(binding)
    detailed_text = ERB.new(detailed_report_template, 0, "%").result(binding)
    rollup_text = ERB.new(rollup_report_template, 0, "%").result(binding)

    detailed_report = header_text + detailed_text
    rollup_report = header_text + rollup_text

    # TODO - when a rogue rule runs afoul and matches too much text on a package, it will blow chunks here
    begin
      printf(detailed_io, detailed_report )
      printf(rollup_io, rollup_report )
    rescue Exception => e
      printf("Sorry, can't write the reports\n#{e.to_s}\n")
    end

    detailed_io.close
    rollup_io.close

    # now echo final results to console also
    if ( @show_rollup )
      puts rollup_report
    else
      puts detailed_report
    end
  end

  # Return the location to show for the given package
  def package_location(package, directories_scanned)
    if @no_paths
      # even if we're not showing paths, we still want to show the archive
      # that contains the file name so we have a clue where it was found
      if package.archive
        "#{package.archive}!/#{package.file_name}"
      else
        package.file_name
      end
    else
      location = maybe_remove_base_dir(package.found_at, directories_scanned) || ""
      location + (location.empty? ? "" : '/') + package.file_name
    end
  end

  # If a flag is set, remove the scan dir from the given directory. 
  # Example:
  #   Discovery invoked with --path /myproj/stuff,/other/lib
  #   Dir given                  Result
  #   -------------------------- --------------
  #   /myproj/stuff/code/ant.jar /code/ant.jar
  #   /other/lib/apache.exe      /apache.exe
  def maybe_remove_base_dir(dir, directories_scanned)
    return dir if @show_base_dirs || dir.empty?
    directories_scanned.each do |base|
      return dir[base.size+1..-1] if dir.index(base) == 0
    end
    # should not happen
    dir
  end

  # Link to the given package ID in olex
  def link_to_olex(package_id)
    OLEX_PREFIX + package_id
  end

  # this is a callback from the framework after reports have been built to give the plugin an opportunity to send the report if it wants to
  # this plugin never sends results to an OLEX server
  def send_results
    false
  end

  def send_file(filename, overrides={})
    false
  end

end

