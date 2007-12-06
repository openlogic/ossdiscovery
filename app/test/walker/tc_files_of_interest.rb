require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), '..', '..', 'main', 'lib')
require 'walker'

class TcWalkerFilesOfInterest < Test::Unit::TestCase
  
  DISCOVERY_RB = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'main', 'lib', 'discovery.rb')) unless defined? DISCOVERY_RB
  
  def setup

  end
  
  def teardown
    
  end

=begin rdoc

=end  
  def test_walker_set_files_of_interest()
   
    test = `ruby #{DISCOVERY_RB} --list-foi`
    
    ['Files of interest','Apache.exe','php','libphp\(\.\?\).so','httpd'].each { | foi |
      if ( test.match(foi) == nil )
        printf("expected to find a file of interest: %s\n", foi)
      end
      assert test.match(foi) != nil
    }
   
  end

   
end
