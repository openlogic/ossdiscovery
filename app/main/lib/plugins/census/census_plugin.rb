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
require 'scan_data'
require "pathname"
require 'getoptlong'

class CensusPlugin

  def initialize
  end

  #--- mandatory methods for a plugin ---
  #

  def cli_options
    clioptions_array = Array.new
     
    clioptions_array << [ "--geography", "-Y", GetoptLong::REQUIRED_ARGUMENT ]      # geography code 
    clioptions_array << [ "--census-code","-C", GetoptLong::REQUIRED_ARGUMENT ]     # identifier representing the census code
    clioptions_array << [ "--production-scan","-P", GetoptLong::NO_ARGUMENT ]       # This flag identifies the scan you run as a scan of a production machine in the results.

  end

  def process_cli_options( option, argument )
    # all plugins will have the chance to process any command line option, not just their own additions
    # this allows plugins to gather any state if they need from the command line

  end
  #--------------------------------------------------
  
  #--- optional methods for a plugin ---
  def machine_report_filename()
    return CensusConfig.machine_report
  end

  def local_report_filename()
    return CensusConfig.local_report
  end

  def human_report_filename()
    return CensusConfig.results
  end


=begin rdoc
  Output the report we'll submit to the census.
=end
  def machine_report(destination, packages, scandata )

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

    template = %{
      report_type:             census
      census_plugin_version:   <%= CENSUS_PLUGIN_VERSION %>
      client_version:          <%= scandata.client_version %>
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
      production_scan:         <%= scandata.production_scan %>
      group_code:              <%= scandata.census_code %>
      geography:               <%= scandata.geography %>
      universal_rules_md5:     <%= scandata.universal_rules_md5 %>
      universal_rules_version: <%= scandata.universal_rules_version %>
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

    printf(io, "integrity_check: #{Integrity.create_integrity_check(text,scandata.universal_rules_md5,CENSUS_PLUGIN_VERSION_KEY)}\n")

    # TODO - when a rogue rule runs afoul and matches too much text on a package, it will blow chunks here
    begin
      printf(io, text )
    rescue Exception => e
      printf(io, "Possible bad rule matching too much text.  Sorry, can't write the machine report\n")
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

end
