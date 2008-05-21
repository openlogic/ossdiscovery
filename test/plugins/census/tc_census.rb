$:.unshift File.join(File.dirname(__FILE__), "..", "..", "..", "main", "lib")
$:.unshift File.join(File.dirname(__FILE__), "..", "..", "..", "main", "lib", "plugins", "census")

require 'test/unit'
require 'cliutils'
require 'conf/census_config'
require 'census_utils'

class TcCensus < Test::Unit::TestCase
  
  def test_basic_values_with_brackets
    assert_not_nil CensusConfig['census_enabled']
    assert_raise(RuntimeError) { CensusConfig['dog'] }
  end

  def test_basic_values_with_methods
    assert_not_nil CensusConfig.census_enabled
    assert_raise(RuntimeError) { CensusConfig.dog }
  end

  def test_add_check_digits
    str = 'cafebabe'
    str_num_with_check = '340569158251'
    str_num_with_check_hex = '4f4b80f26b'
    assert_equal str_num_with_check_hex, CensusPlugin.add_check_digits(str)
  end
end
