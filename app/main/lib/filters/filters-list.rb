# filters-list.rb
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
# 
#  this file is the file used to create the master list of exclusion filters
#
#  the discovery framework will load this file which in turn will load the individual filters
#  
#  using this mechanism, it's possible to specify different filter sets used to scan a drive
#  it's also possible to include all filters that are available, though seems unlikely one would
#  want to do that.
#
#  To Add a New Filter
#     1) write the filter using an existing example and place the filter .rb file in the filters directory
#     2) Add the require of the filter .rb file to generic-exclusions.rb
#        file to pull it in.


@filterdir = File.dirname(__FILE__)

require "#{@filterdir}/generic-exclusions.rb"
