# scan_data.rb
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

# the purpose of this class is to aggregate scan data so it's easier to pass to report generators,
# delivery mechanisms, or any other component that might need any data related to the machine or scans

class ScanData

  attr_accessor :client_version, :machine_id, :hostname, :ipaddress
  attr_accessor :file_ct, :dir_ct, :sym_link_ct, :bad_link_ct, :permission_denied_ct, :foi_ct, :not_found_ct, :not_followed_ct
  attr_accessor :starttime, :endtime, :total_seconds_paused_for_throttling
  attr_accessor :distro, :os_family, :os, :os_version, :os_architecture, :kernel, :production_scan
  attr_accessor :census_code, :group_code
  attr_accessor :universal_rules_md5, :universal_rules_version
  attr_accessor :geography 
  attr_accessor :throttling_enabled

  def initialize

    @client_version = ""
    @machine_id = ""
    @hostname = ""
    @ipaddress = ""
    @file_ct = 0
    @dir_ct = 0
    @sym_link_ct = 0
    @bad_link_ct = 0
    @permission_denied_ct = 0   
    @foi_ct = 0
    @not_found_ct = 0 
    @not_followed_ct = 0
    @starttime = ""
    @endtime = ""
    @total_seconds_paused_for_throttling = 0
	  @distro = ""
    @os_family = ""
    @os = ""
    @os_version = ""
    @os_architecture = ""
    @kernel = ""
    @production_scan = false
    @census_code = ""
    @group_code = ""
	  @universal_rules_md5 = ""
    @universal_rules_version = ""
    @geography  = ""
		@throttling_enabled = false

  end

end
