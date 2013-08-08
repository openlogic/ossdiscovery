#!/bin/bash
#  when you first set up your test environment, you need to run
# this script (once) before running the ruby test suite for the app
#
# this assumes you're on a linux, mac os, or solaris environment - these tests
# aren't really relevant to windows

pushd .

mkdir ignore_these

cd ignore_these

echo "bogus stuff" > file-no-read
chmod a-r file-no-read

mkdir -p dir-no-execute/protected-sub-dir
chmod a-x dir-no-execute/protected-sub-dir
chmod a-x dir-no-execute

popd

