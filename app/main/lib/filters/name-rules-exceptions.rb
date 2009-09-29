# name-rules-exceptions
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

# this is a example generic filter for ignoring /var/log directories and log
# files

# a filter is defined by its unique description as the key value to a filter hash table
# the value is simply a regular expression or literal filename or basename of a directory to ignore

# these files are not binaries, but artifacts of installations

# extensions
#@file_exclusion_filters["Name Rules Exceptions media"] = '\.(gif|jpg|jpeg|png|tif|tiff|mp3|mp3|mpeg|m4a|ogg|acc|xpm|ico)$'
#@file_exclusion_filters["Name Rules Exceptions web"] = '\.(css|xsl|xml|xsd|dtd|js|php|jsp|htm|html|xhtml)$'
#@file_exclusion_filters["Name Rules Exceptions msoffice"] = '\.(doc|xls|xlt|ppt)$'
#@file_exclusion_filters["Name Rules Exceptions .prop"] = '\.prop(erty|erties)$'
#@file_exclusion_filters["Name Rules Exceptions .txt"] = '\.t(ext|xt)$'
#@file_exclusion_filters["Name Rules Exceptions make"] = '\.make$'
#@file_exclusion_filters["Name Rules Exceptions manpages"] = '\.[0-9]$'
#@file_exclusion_filters["Name Rules Exceptions pdf"] = '\.pdf$'
#@file_exclusion_filters["Name Rules Exceptions .o"] = '\.o$'
#@file_exclusion_filters["Name Rules Exceptions .lo"] = '\.lo$'
#@file_exclusion_filters["Name Rules Exceptions .so"] = '\.so$'
#@file_exclusion_filters["Name Rules Exceptions .c"] = '\.c$'
#@file_exclusion_filters["Name Rules Exceptions .vim"] = '\.vim$'
#@file_exclusion_filters["Name Rules Exceptions .lst"] = '\.lst$'
##@file_exclusion_filters["Name Rules Exceptions python"] = '\.py$'
#@file_exclusion_filters["Name Rules Exceptions rsc"] = '\.rsc$'
#@file_exclusion_filters["Name Rules Exceptions bat"] = '\.bat$'
#@file_exclusion_filters["Name Rules Exceptions .ini"] = '\.ini$'
#@file_exclusion_filters["Name Rules Exceptions .y(a)ml"] = '\.y(aml|ml)$'

# common project id's
#@file_exclusion_filters["Name Rules Exceptions build"] = '^build\..*'
#@file_exclusion_filters["Name Rules Exceptions setup"] = '^setup\..*$'
#@file_exclusion_filters["Name Rules Exceptions nice"] = '^config\..*$'
#@file_exclusion_filters["Name Rules Exceptions autorun"] = '^autorun\..*$'
#@file_exclusion_filters["Name Rules Exceptions template"] = '^template\..*$'
#@file_exclusion_filters["Name Rules Exceptions snippet"] = '^snippet\..*$'
#@file_exclusion_filters["Name Rules Exceptions style"] = '^style\..*$'
#@file_exclusion_filters["Name Rules Exceptions spell"] = '^spell\..*$'
#@file_exclusion_filters["Name Rules Exceptions test"] = '^test(_|\.).*$'
#@file_exclusion_filters["Name Rules Exceptions types"] = '^types\..*$'
#@file_exclusion_filters["Name Rules Exceptions index"] = '^index\..*$'
#@file_exclusion_filters["Name Rules Exceptions version"] = '^version\..*$'
#@file_exclusion_filters["Name Rules Exceptions tag"] = '^tag\..*$'
#@file_exclusion_filters["Name Rules Exceptions foo"] = '^foo\..*$'
#@file_exclusion_filters["Name Rules Exceptions lib"] = '^lib\..*$'
#@file_exclusion_filters["Name Rules Exceptions prefix"] = '^prefix\..*$'
#@file_exclusion_filters["Name Rules Exceptions src"] = '^src\..*$'
#@file_exclusion_filters["Name Rules Exceptions com"] = '^com\..*$'
#@file_exclusion_filters["Name Rules Exceptions jdi"] = '^jdi\..*$'
#@file_exclusion_filters["Name Rules Exceptions client"] = '^client\..*$'
#@file_exclusion_filters["Name Rules Exceptions connector"] = '^connector\..*$'
#@file_exclusion_filters["Name Rules Exceptions mime"] = '^mime\..*$'
#@file_exclusion_filters["Name Rules Exceptions show"] = '^show\..*$'
#@file_exclusion_filters["Name Rules Exceptions search"] = '^search\..*$'
#@file_exclusion_filters["Name Rules Exceptions scan"] = '^scan\..*$'
#@file_exclusion_filters["Name Rules Exceptions scans"] = '^scans\..*$'
#@file_exclusion_filters["Name Rules Exceptions post"] = '^post\..*$'
#@file_exclusion_filters["Name Rules Exceptions parser"] = '^parser\..*$'
#@file_exclusion_filters["Name Rules Exceptions pie"] = '^pie\..*$'
#@file_exclusion_filters["Name Rules Exceptions new"] = '^new\..*$'
#@file_exclusion_filters["Name Rules Exceptions abc"] = '^abc\..*$'


