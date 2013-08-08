# no-system.rb
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

#   these are filters to keep from scanning system directories that likely have 
#   no open source in them

# linux/unix exclusions
@dir_exclusion_filters["No /dev"] = '^/dev'
@dir_exclusion_filters["No /boot"] = '^/boot'
@dir_exclusion_filters["No /sys"] = '^/sys'
@dir_exclusion_filters["No /proc"] = '^/proc'
@dir_exclusion_filters["No /lost+found"] = '^/lost\+found'

# windows exclusions
@dir_exclusion_filters["No RECYCLER"] = 'RECYCLER$'
@dir_exclusion_filters["No Recycle Bin"] = 'Recycle Bin$'
@dir_exclusion_filters["No System Volume Information"] = 'System Volume Information$'
