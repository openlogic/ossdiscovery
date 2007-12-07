require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), '..', '..', 'main', 'lib')
require 'rule_engine'
require 'expression'
require File.join(File.dirname(__FILE__), '..', 'test_helper')
require File.join(File.dirname(__FILE__), 'discovery_assertions')
require 'conf/config'

class TclongBlackboxValidation < Test::Unit::TestCase
  include DiscoveryAssertions
  
  @@log = Config.log
  
  DIR_TO_DISCOVER = File.expand_path(File.join(File.dirname(__FILE__), '..', 'resources')) unless defined? DIR_TO_DISCOVER
  DISCOVERY_RB = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'main', 'lib', 'discovery.rb')) unless defined? DISCOVERY_RB
  
  def setup
    
  end
  
  def teardown
    
  end

  def test_discovery
    t1 = Time.new
    @@log.info('TclongBlackboxValidation') {"Running... #{t1}"}
    output = `ruby #{DISCOVERY_RB} --path #{DIR_TO_DISCOVER}`
    t2 = Time.new
    @@log.info('TclongBlackboxValidation') {"It took '#{(t2-t1).to_s}' seconds to run the blackbox validation test."}
    
    # We're testing that content that should not be discovered (content living somewhere underneath a 'decoy' directory) is actually NOT being discovered.
    assert(!output.include?('decoy'))
  end

end
