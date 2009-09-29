require 'test/unit'
require File.join(File.dirname(__FILE__), '..', '..', 'main', 'lib', 'cliutils.rb')
#require File.join(File.dirname(__FILE__), '..', 'test_helper.rb')


class TcDontFindOurDogfood < Test::Unit::TestCase
  DISCOVERY_RB = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'main', 'lib', 'discovery.rb')) unless defined? DISCOVERY_RB
  
  def setup
    
  end
  
  def teardown
    
  end
  
  def test_that_we_dont_find_our_own_dogfood
    app_home = ENV['OSSDISCOVERY_HOME']
    output = `ruby #{DISCOVERY_RB} --path #{app_home}`
    
    dir_scanned = output.match(/^Scanning\s+(.*)$/)[1]
    assert_equal(normalize_dir(app_home), normalize_dir(dir_scanned))
 
    # this is less fragile than the former tests that relied on precise output line order and whitespace    
    assert( output.match("packages found.*?: 0" ) )

  end
  
end
