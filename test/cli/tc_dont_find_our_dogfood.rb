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
    
    lines = Array.new
    output.each_line do |line|
      lines << line
    end
    
    str = 'Discovery has completed a scan'
    index = 0
    lines.each_with_index do |line, i|
      if (line.include?(str)) then
        index = i
      end      
    end
    
    assert(index != 0, "Expecting the string '#{str}' to exist somewhere in the output")
    
    # This assertion means that nothing was found (aka... no found packages were listed between the 'production scan' line and the 'Discovery has completed a scan' line
    assert(lines[index - 2].include?('production machine')) # [index - 2] because there's a line of whitespace in there
    
  end
  
end
