require 'logger'
require 'pp'

require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), '..', '..', 'main', 'lib', 'conf')
require 'config.rb'

class TcConfig < Test::Unit::TestCase
  
  def setup
    
  end
  
  def teardown
    
  end
  
  def test_configs
    # asserting various non-trivial things (code that needs to evaluated, non-string values, etc)
    
    actual = Config.prop(:log_device)    
    expected_to_end_with = "/discovery.log"
    actually_ends_with = actual[(actual.length - expected_to_end_with.length)..actual.length]
    assert_equal(expected_to_end_with, actually_ends_with, "The log file value in the configs is hosed.")
    
    actual = Config.prop(:log_level)
    assert(actual >= 0, "The log level value in the configs is hosed.")
    
    actual = Config.prop(:rules_openlogic)
    expected_to_end_with = "/lib/rules/openlogic"
    actually_ends_with = actual[(actual.length - expected_to_end_with.length)..actual.length]
    assert_equal(expected_to_end_with, actually_ends_with, "The openlogic rules dir value in the configs is hosed.")
    
    actual = Config.prop(:rules_drop_ins)    
    expected_to_end_with = "/lib/rules/drop_ins"
    actually_ends_with = actual[(actual.length - expected_to_end_with.length)..actual.length]
    assert_equal(expected_to_end_with, actually_ends_with, "The dropins rules dir value in the configs is hosed.")
    
    actual = Config.prop(:rules_dirs)
    assert_equal(2, actual.size)
    actual.each do |rules_dir|
      assert(File.exist?(rules_dir) && File.directory?(rules_dir), "The rules directory ('#{rules_dir}') does not exist or is not a directory.")
    end
    
    actual = Config.prop(:log)
    assert_not_nil(actual)
    
    actual = Config.prop(:results)
    assert_equal(STDOUT, actual)
    assert_not_equal("STDOUT", actual)
  end
  
  def test_prop
    # a valid key argument (valid means that you'll actually see it in the config.yml file)
    
    # an invalid key argument
    assert_raise RuntimeError do
      val = Config.prop(:foo)
    end
    
    # an invalid key argument
    assert_raise RuntimeError do
      val = Config.prop('foo')
    end
  end
  
  def test_log
    assert_not_nil(Config.log)
    assert_same(Config.prop(:log), Config.log)
  end
    
end
