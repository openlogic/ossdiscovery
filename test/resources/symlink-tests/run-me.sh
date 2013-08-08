#!/bin/bash
#  when you first set up your test environment, you need to run
# this script (once) before running the ruby test suite for the app
#
# this assumes you're on a linux, mac os, or solaris environment - these tests
# aren't really relevant to windows

pushd .

mkdir ignore_these

cd ignore_these

ln -s /tmp symlinkto-tmpdir
ln -s ../ symlinkto-parent
touch aFile
ln -s ./aFile symlnkto-file
ln -s symlnkto-file link-to-a-link
mkdir setup-circular-link
cd setup-circular-link
ln -s ../setup-circular-link

cd ..
mkdir setup-orphaned-link
touch setup-orphaned-link/realfile
cd setup-orphaned-link
ln -s ./realfile orphaned-link
# now orphan the link by blowing away the real file
rm ./realfile

mkdir testdir
ln -s ./testdir orphaned-dir
# now orphan the directory
rmdir testdir
cd ..

popd

