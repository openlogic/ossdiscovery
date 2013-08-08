# This test suite runs all unit tests (all tests whose filename start with 'tc_')
require 'test/unit'
require File.join(File.dirname(__FILE__), 'test_helper')
$:.unshift File.join(File.dirname(__FILE__))

files = TestHelper.find_all_files(File.dirname(__FILE__))

files.each { |file|
  basename = File.basename(file)
  if ((basename.size > 2) && (basename[0..2] == "tc_")) then
    eval("require '#{file}'")
  end
  
}
