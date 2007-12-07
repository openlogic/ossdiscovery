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
    
    
  end

end
