require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), '..', '..', 'main', 'lib')

require 'cliutils'

class TcOSDetection < Test::Unit::TestCase
  
  def setup

  end
  
  def teardown
    
  end
  
  def test_os_detection
      # this is a pretty lame test because we don't have sample content for all the distros
      # yet to assert on....so just make sure something's detected and not the unknown os
      assert( get_os_version_str() != "unknown operating system")
  end
  
end
