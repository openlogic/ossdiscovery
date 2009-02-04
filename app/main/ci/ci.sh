#!/bin/bash
# This script needs to be run from directory directly above 'main' (which is where CruiseControl runs it from).
export OSSDISCOVERY_HOME=`pwd`/main
svn up $OSSDISCOVERY_HOME/../test-internal $OSSDISCOVERY_HOME --username guest && \
ruby $OSSDISCOVERY_HOME/../test-internal/ts_test_all.rb && \
ruby $OSSDISCOVERY_HOME/../test/ts_test_unit.rb && \
$OSSDISCOVERY_HOME/jruby/bin/jruby -J-Xmx256m $OSSDISCOVERY_HOME/../test-internal/ts_test_all.rb && \
$OSSDISCOVERY_HOME/jruby/bin/jruby -J-Xmx1024m $OSSDISCOVERY_HOME/../test/ts_test_unit.rb && \
ruby $OSSDISCOVERY_HOME/lib/discovery.rb --list-projects >> $CC_BUILD_ARTIFACTS/discoverable_projects_list

# A command to come back to some day if we want to get rcov results posted on the CI server.
# ruby ./test/ts_test_all.rb && rcov --text-summary `find ./test/ -name .svn -prune -o -iname 'tc*.rb' -printf "%p "` --output $CC_BUILD_ARTIFACTS/coverage

# Setting the 'log_device' property in config.yml (the config.yml that is checked out on the build
# server) as follows makes it so that all log output produced from running the CI tests are posted
# as plain text that can be navigated to in the browser.
# log_device: <% File.expand_path(File.join(ENV['CC_BUILD_ARTIFACTS'], 'discovery.log')) %>

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
