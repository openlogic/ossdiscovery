# ruby requires
require 'test/unit'

# main source tree requires
$:.unshift File.join(File.dirname(__FILE__), '..', '..', 'main', 'lib')
require 'expression'
require 'rule_engine'
require 'scan_rules_updater'
require 'conf/config'

# test source tree requires
require File.join(File.dirname(__FILE__), '..', 'test_helper')
require File.join(File.dirname(__FILE__), 'discovery_assertions')


class TclongBlackboxValidation < Test::Unit::TestCase
  include DiscoveryAssertions
  
  @@log = Config.log
  
  DIR_TO_DISCOVER = File.expand_path(File.join(File.dirname(__FILE__), '..', 'resources')) unless defined? DIR_TO_DISCOVER
  DISCOVERY_RB = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'main', 'lib', 'discovery.rb')) unless defined? DISCOVERY_RB
  
  def setup
    @results_file = File.expand_path(File.join(File.dirname(__FILE__), "#{ScanRulesUpdater.get_YYYYMMDD_HHMM_str}_scan_results.txt"))
    @baseline_file = File.expand_path(File.join(File.dirname(__FILE__), '..', 'resources', 'blackbox_validation_baseline_scan_results.txt'))
  end
  
  def teardown
    File.delete(@results_file)
  end

  def test_discovery
    t1 = Time.new
    @@log.info('TclongBlackboxValidation') {"Running... #{t1}"}
    cmd = "ruby #{DISCOVERY_RB} --path #{DIR_TO_DISCOVER} --machine-results #{@results_file}"
    output = `#{cmd}`
    
    t2 = Time.new
    @@log.info('TclongBlackboxValidation') {"It took '#{(t2-t1).to_s}' seconds to run the blackbox validation test."}
    
    assert(!output.include?('Unsupported option'), "There was a problem with the command (#{cmd}), because the help text was returned.")    
    assert(!output.include?('decoy'), "The test was testing that content that should not be discovered (content living somewhere underneath a 'decoy' directory) is actually NOT being discovered.  Some of the 'decoy' stuff must've been discovered.")
    
    # Asserting that the portions of the baseline results file and the results file created from performing the above discovery run that should be the same are the same.
    lines_test_file = Array.new
    start_adding_lines = false
    File.open(@results_file) do |test_file|
      while line = test_file.gets
        if (start_adding_lines) then
          lines_test_file << line
        elsif (line.include?("package,version"))
          start_adding_lines = true
          next
        end
      end # of while
    end # of File.open
    
    lines_baseline_file = Array.new
    start_adding_lines = false
    File.open(@baseline_file) do |test_file|
      while line = test_file.gets
        if (start_adding_lines) then
          lines_baseline_file << line
        elsif (line.include?("package,version"))
          start_adding_lines = true
          next
        end
      end # of while
    end # of File.open
    
    lines_test_file.sort!
    lines_baseline_file.sort!
    0.upto(lines_baseline_file.size - 1) do |i|
      assert_equal(lines_baseline_file[i], lines_test_file[i])
    end # of 0.upto
    
  end

end
