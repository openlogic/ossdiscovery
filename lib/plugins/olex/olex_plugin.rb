# olex_plugin.rb
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
require 'scan_data'
require "pathname"
require 'getoptlong'

class OlexPlugin

  attr_accessor :olex_machine_file, :olex_local_file
    
  def initialize

    @olex_machine_file = OlexConfig.machine_report 
    @olex_local_file = OlexConfig.local_report
    @plugin_version = OLEX_PLUGIN_VERSION_KEY

  end 

  def plugin_version
    return @plugin_version
  end

  #--- mandatory methods for a plugin ---
  def cli_options
    clioptions_array = Array.new
    clioptions_array << [ "--olex-local","-A", GetoptLong::REQUIRED_ARGUMENT ]   # formerly --human-results
    clioptions_array << [ "--olex-results","-B", GetoptLong::REQUIRED_ARGUMENT ] # formerly --machine-results

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

       @olex_local_file = arg
       begin
         # Issue 34: only open as append in this test so we do not blow away an existing results file
         File.open(@olex_local_file, "a") {|file|}      
       rescue Exception => e
         puts "ERROR: Unable to write to file: '#{@olex_local_file}'\n"
         if ( !(File.directory?( File.dirname(@olex_local_file) ) ) )
           puts "The directory " + File.dirname(@olex_local_file) + " does not exist\n"
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

  def can_deliver?
    false
  end

=begin rdoc
  Output the report we'll submit to the olex server.
=end
  def machine_report(destination, packages, scandata )
    io = nil
    if (destination == STDOUT) then
      io = STDOUT
    else 
      io = File.new(destination, "w")
    end

    # if SHA256 isn't available, we can't submit to the OLEX server 
    # because the results would be rejected as invalid
    unless Integrity.sha256_available?
      message = "OpenSSL 0.9.8 with SHA256 is required in order to properly write machine scan results.\nYour machine is either running a version of OpenSSL that is less than 0.9.8 or you need to install the ruby openssl gem"
      puts(message) unless io == STDOUT
      printf(message, io)
      io.close unless io == STDOUT
      return
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
    dumps a simple ASCII text report to the console
=end

  def report( destination, packages, scandata  )

    io = nil
    if ( destination == STDOUT) then
      io = STDOUT
    else 
      io = File.new( destination, "w")
    end

    scan_ftime = scandata.endtime - scandata.starttime  # seconds
    scan_hours = (scan_ftime/3600).to_i
    scan_min = ((scan_ftime -  (scan_hours*3600))/60).to_i
    scan_sec = scan_ftime - (scan_hours*3600) - (scan_min*60)

    # pull the stats from the walker for a simple report
    
    throttling_enabled_or_disabled = nil
    if ( scandata.throttling_enabled) then
      throttling_enabled_or_disabled = 'enabled'
    else
      throttling_enabled_or_disabled = 'disabled'
    end
    end_of_line = "\r\n"

    printf(io, end_of_line)
    printf(io, "client_version        : #{scandata.client_version}#{end_of_line}" )
    printf(io, "ip address            : #{scandata.ipaddress}#{end_of_line}" )
    printf(io, "hostname              : #{scandata.hostname}#{end_of_line}" )
    printf(io, "directories walked    : %d#{end_of_line}", scandata.dir_ct )
    printf(io, "files encountered     : %d#{end_of_line}", scandata.file_ct )
    printf(io, "symlinks found        : %d#{end_of_line}", scandata.sym_link_ct )
    printf(io, "symlinks not followed : %d#{end_of_line}", scandata.not_followed_ct )  
    printf(io, "bad symlinks found    : %d#{end_of_line}", scandata.bad_link_ct )
    printf(io, "permission denied     : %d#{end_of_line}", scandata.permission_denied_ct )
    printf(io, "files examined        : %d#{end_of_line}", scandata.foi_ct )
    printf(io, "start time            : %s#{end_of_line}", scandata.starttime.asctime )
    printf(io, "end time              : %s#{end_of_line}", scandata.endtime.asctime )
    printf(io, "scan time             : %02d:%02d:%02d (hh:mm:ss)#{end_of_line}", scan_hours, scan_min, scan_sec )
    printf(io, "distro                : %s#{end_of_line}", scandata.distro )
    printf(io, "kernel                : %s#{end_of_line}", scandata.kernel )
    printf(io, "anonymous machine hash: %s#{end_of_line}", scandata.machine_id )
    printf(io, "")
    printf(io, "packages found        : %d#{end_of_line}", packages.length )
    printf(io, "throttling            : #{throttling_enabled_or_disabled} (total seconds paused: #{scandata.total_seconds_paused_for_throttling})#{end_of_line}" )
    printf(io, "production machine    : %s#{end_of_line}",  scandata.production_scan)
    
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
      result_txt = File.open(destination,"r").read
      puts result_txt
    end
  end

  # this is a callback from the framework after reports have been built to give the plugin an opportunity to send the report if it wants to
  # this plugin never sends results to an OLEX server
  def send_results()
    return false
  end

  def send_file( filename, overrides={} )
    return false
  end

end
