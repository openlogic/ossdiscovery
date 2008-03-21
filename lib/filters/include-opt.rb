# include-opt.rb
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

# this is a generic inclusion for including the directory /opt.
# like exclusion filters, inclusion filters are a hash with a 
# description for a key and the top-level included directory 
# for a value.

# inclusion_filters are for directories only
# the reason for this is:
# file types/extensions are included by the RuleEngine maintaining
# a list of filenames and file types/extensions it needs to match

# example:
# tell the walker to scan the /opt directory
# the index is an arbitrary, unique string that describes the inclusion filter
# the value is the path to the directory to scan

@inclusion_filters["Scan /opt"] = '^/opt'
