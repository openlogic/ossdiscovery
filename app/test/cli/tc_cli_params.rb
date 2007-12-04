require 'test/unit'


class TcCLI < Test::Unit::TestCase
  
  def setup

  end
  
  def teardown
    
  end
  
  def test_cli_help
    test = `ruby lib/discovery.rb --help`
    
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
    test = `ruby lib/discovery.rb --version`
    expected_version = "discovery v2.0-alpha"
    
    if ( test.match( expected_version ) == nil )
      fail "Did not find the expected version of: #{expected_version}"
    end
    
    assert true
  end
  
  def test_cli_list_filters
    test = `ruby lib/discovery.rb --list-filters`

    if ( test.match('/temp') == nil ||
         test.match('/tmp') == nil )
      printf("%s\n", test)
      fail "Failed to find the expected exclusion filters for temp or tmp"
    end
    
    assert true
  end
  
  def test_list_projects
    test = `ruby lib/discovery.rb --list-projects verbose`
    if ( test.match("name,from,platforms,description") == nil || test.match("Unsupported option.  Please review the list of supported options and usage") != nil ) then
      fail("The '--list-projects' cli option is not working as expected.")
    else
      assert(true, "TcCliParams#test_list_projects passed")
    end
    
    test = `ruby lib/discovery.rb --list-projects`
    if ( test.match("Unsupported option.  Please review the list of supported options and usage") != nil ) then
      fail("The '--list-projects' cli option is not working as expected.")
    else
      assert(true, "TcCliParams#test_list_projects passed")
    end
  end
   
  
end
