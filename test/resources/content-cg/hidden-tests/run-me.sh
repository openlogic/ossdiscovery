#!/bin/bash
#
# when you first set up your test environment, you need to run
# this script (once) before running the ruby test suite for the app
#
# subversion ignores hidden files and directories by default so 
# this script builds the test bits we need
#
# this assumes you're on a linux or solaris environment - these tests
# aren't really relevant to windows
#

# make the directory name to put in the .svn ignore file
pushd .
mkdir ignore_these
cd ignore_these
touch .htaccess .htpasswd .htgroup .bashrc .profile .2AD271C1-3ABD-11DA-905-D654-9340D5F2
mkdir .ssh .svn-svn .sshd 
popd

