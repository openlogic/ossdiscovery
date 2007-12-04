require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), '..', '..', 'main', 'lib')
require 'rule_engine'
require 'expression'
require File.join(File.dirname(__FILE__), '..', 'test_helper')
require File.join(File.dirname(__FILE__), 'discovery_assertions')
require 'conf/config'

class TclongDecoy < Test::Unit::TestCase
  include DiscoveryAssertions
  
  @@log = Config.log
  
  def setup
    
  end
  
  def teardown
    
  end

  def test_discovery
    t1 = Time.new
    @@log.info('TclongDecoy') {"Running... #{t1}"}
    
    dir_to_discover = File.expand_path(File.join(File.dirname(__FILE__), '..', 'resources'))
    discovery_rb = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'main', 'lib', 'discovery.rb'))
    output = `ruby #{discovery_rb} --path #{dir_to_discover}`
    assert(!output.include?('decoy'))
    
    t2 = Time.new
    @@log.info('TclongDecoy') {"It took '#{(t2-t1).to_s}' seconds to run the decoy blackbox test."}
    
  end

end
