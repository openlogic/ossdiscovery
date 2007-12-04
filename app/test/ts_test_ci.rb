# This test suite runs ALL tests (all tests executed by both the 'ts_test_all' and the 'tslong_test_all' suites).
require 'test/unit'
require File.join(File.dirname(__FILE__), 'test_helper')
$:.unshift File.join(File.dirname(__FILE__))

files = TestHelper.find_all_files(File.dirname(__FILE__))

files.each { |file|
  basename = File.basename(file)
  if (((basename.size > 2) && (basename[0..2] == "tc_")) || ((basename.size > 6) && (basename[0..6] == "tclong_"))) then
    eval("require '#{file}'")
  end
  
}
