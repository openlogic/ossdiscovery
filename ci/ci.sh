#!/bin/bash
# This script needs to be run from directory directly above 'main' (which is where CruiseControl runs it from).
cd ./main && ruby ../test/ts_test_ci.rb && ./discovery --list-projects >> $CC_BUILD_ARTIFACTS/discoverable_projects_list && cp ./ci/mascot $CC_BUILD_ARTIFACTS/project_mascot && cd -
# ruby ./test/ts_test_ci.rb && rcov --text-summary `find ./test/ -name .svn -prune -o -iname 'tc*.rb' -printf "%p "` --output $CC_BUILD_ARTIFACTS/coverage
