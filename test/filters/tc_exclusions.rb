require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), '..', '..', 'main', 'lib', 'filters')

class TcExclusions < Test::Unit::TestCase
  
  def setup
    @exclusion_filters = Hash.new

    # these test cases taken from no-hidden.rb and no-tmp.rb
    
    @exclusion_filters["No hidden files or directories"] = '^(\.)*'
    
    @exclusion_filters["No tmp files or directories"] = '^/tmp'
    @exclusion_filters["No temp files or directories"] = '^/temp'

  end
  
  def teardown
    
  end
  
  def test_exclusions_true
    @result = false
      
    # should match
    if ( File.dirname("/tmp/test/.svn/test").match(@exclusion_filters["No hidden files or directories"])[0] != nil )
      @result = true
    else
      fail "/tmp/test/.svn"
    end
    
    # should match
    if ( File.dirname("/tmp/test.svn/.svn").match(@exclusion_filters["No hidden files or directories"])[0] != nil )
      @result = true
    else
      fail "/tmp/test.svn/.svn"
    end
      
    # should match
    if ( File.dirname("/tmp/test").match(@exclusion_filters["No tmp files or directories"])[0] != nil )
      @result = true
    else
      fail "/tmp exclusion"
    end
    
    if ( File.dirname("/temp/test").match(@exclusion_filters["No temp files or directories"])[0] != nil )
      @result = true
    else
      fail "/temp"
    end

      
    assert @result
  end
  
  def test_exclusions_false

    @result = false
    
    # should not match
    
    #irb(main):009:0> File.dirname("/tmp/test/.svn/test").match('^(\.)*')[0]
    #=> "" (this doesn't match because the filter only goes off the dirname it's given)
    @exclude = @exclusion_filters["No hidden files or directories"]

    if ( File.dirname("/tmp/test/.svn/test").match(@exclude) == nil ||
         File.dirname("/tmp/test/.svn/test").match(@exclude)[0] == ""
      )
      @result = true
    else
      printf("exclusion filter failed: [%s]\n", @exclude )
      fail "Exclusion test failed with directory: /tmp/test/.svn/test"
    end
    
    #irb(main):002:0>  File.dirname("/tmp/test.svn/").match('^(\.)*')[0]
    #=> ""  (this doesn't match because the . period is not at the beginning of the dirname )
    
    if ( File.dirname("/tmp/test.svn/").match(@exclusion_filters["No hidden files or directories"]) == nil ||
         File.dirname("/tmp/test.svn/").match(@exclusion_filters["No hidden files or directories"])[0] == ""
      )
      @result = true
    else
      fail "Exclusion test failed iwth directory /tmp/test.svn/"
    end

    #irb(main):011:0> File.dirname("/tmp/test.svn/svn").match('^(\.)*')[0]
    #=> ""  (this doesn't match because the base name doesn't start with a period)
    
    if ( File.dirname("/tmp/test.svn/svn").match(@exclusion_filters["No hidden files or directories"]) == nil ||
         File.dirname("/tmp/test.svn/svn").match(@exclusion_filters["No hidden files or directories"])[0] == ""
      )
      @result = true
    else
      fail "Exclusion test failed with directory /tmp/test.svn/snv"
    end    
    
    #irb(main):030:0> File.dirname("/testtmp").match("^tmp")
    #=> nil

    if ( File.dirname("/testtmp").match(@exclusion_filters["No tmp files or directories"]) == nil ||
         File.dirname("/testtmp").match(@exclusion_filters["No tmp files or directories"])[0] == ""
      )
      @result = true
    else
      fail "Exclusion test failed with directory /testtmp"
    end
    
    assert @result
  end
  
end
