# This test suite runs all long running tests (all tests whose filename start with 'tclong_').
# These tests have more of a blackbox feel to them; testing that spans many layers of the application, not just one particular component.
require 'test/unit'
require File.join(File.dirname(__FILE__), '..', 'test_helper')
$:.unshift File.join(File.dirname(__FILE__))

files = TestHelper.find_all_files(File.dirname(__FILE__))

files.each { |file|
  basename = File.basename(file)
  if ((basename.size > 6) && (basename[0..6] == "tclong_")) then
    eval("require '#{file}'")
  end
  
}
