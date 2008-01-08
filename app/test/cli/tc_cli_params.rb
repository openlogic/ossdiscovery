require 'test/unit'


class TcCLI < Test::Unit::TestCase
  DISCOVERY_RB = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'main', 'lib', 'discovery.rb')) unless defined? DISCOVERY_RB
  
  def setup
    
  end
  
  def teardown
    
  end
  
  def test_cli_help    
    test = `ruby #{DISCOVERY_RB} --help`
    
    # do some test matches on the output of discovery help to determine the help came out
    if ( test.match("Usage:") == nil )
      fail "Couldn't find Usage message"
    end
    
    if ( test.match("Copyright") == nil )
      fail "Couldn't find Copyright message"
    end
    
    if ( test.match("Bogus") != nil )
      fail "Unexpected help message"
    end
    
    assert true
  end
  
  def test_cli_version
    test = `ruby #{DISCOVERY_RB} --version`
    expected_version = "discovery v2.0-alpha"
    
    if ( test.match( expected_version ) == nil )
      fail "Did not find the expected version of: #{expected_version}"
    end
    
    assert true
  end
  
  def test_cli_list_filters
    test = `ruby #{DISCOVERY_RB} --list-filters`

    if ( test.match('/temp') == nil ||
         test.match('/tmp') == nil )
      printf("%s\n", test)
      fail "Failed to find the expected exclusion filters for temp or tmp"
    end
    
    assert true
  end
  
  def test_list_projects
    test = `ruby #{DISCOVERY_RB} --list-projects verbose`
    if ( test.match("name,from,platforms,description") == nil || test.match("Unsupported option.  Please review the list of supported options and usage") != nil ) then
      fail("The '--list-projects' cli option is not working as expected.")
    else
      assert(true, "TcCliParams#test_list_projects passed")
    end
    
    test = `ruby #{DISCOVERY_RB} --list-projects`
    if ( test.match("Unsupported option.  Please review the list of supported options and usage") != nil ) then
      fail("The '--list-projects' cli option is not working as expected.")
    else
      assert(true, "TcCliParams#test_list_projects passed")
    end
  end
  
  def test_cli_production_scan
    nothing_to_discover_dir = File.expand_path(File.join(File.dirname(__FILE__)))
    
    output_default = `ruby #{DISCOVERY_RB} --path #{nothing_to_discover_dir}`
    default_scan_val = output_default.match(/^production scan\s+:\s+(.*).*$/)[1]
    assert_equal('false', default_scan_val, "The default production scan value is expected to be 'false'")
    
    output_production = `ruby #{DISCOVERY_RB} --path #{nothing_to_discover_dir} --production-scan`
    prod_scan_val = output_production.match(/^production scan\s+:\s+(.*).*$/)[1]
    assert_equal('true', prod_scan_val, "The production scan value was expected to be 'true' because the '--production-scan' cli arg was passed in.")
    
  end
  
  def test_cli_list_projects
    test = `ruby #{DISCOVERY_RB} --list-projects`
    lines = Array.new
    test.each_line do |line|
      lines << line
    end
    
    first_line_first_val = lines[0].split(',')[0]
    assert_equal(1, first_line_first_val.to_i)
    first_line_second_val = lines[0].split(',')[1]
    
    last_line_first_val = lines[lines.size - 1].split(',')[0]
    assert(last_line_first_val.to_i > 1)
    last_line_second_val = lines[lines.size - 1].split(',')[1]
    assert(first_line_second_val < last_line_second_val)
  end
   
  
end
