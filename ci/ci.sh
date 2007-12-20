#!/bin/bash
# This script needs to be run from directory directly above 'main' (which is where CruiseControl runs it from).
cd ./test-internal && svn up && cd - && cd ./main && ruby ../test-internal/ts_test_all.rb && ./discovery --list-projects >> $CC_BUILD_ARTIFACTS/discoverable_projects_list && cd -

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
