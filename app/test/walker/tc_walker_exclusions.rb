require 'test/unit'

class TcWalkerExclusions < Test::Unit::TestCase

=begin rdoc
  Note that before you can run the hidden test, you need to run resources/content-cg/hidden-tests/run-me.sh.  That
  script will set up the hidden files and directories needed for this test to work correctly.
=end  
  def setup

  end
  
  def teardown
    
  end
  
=begin rdoc
  Note that before you can run the hidden test, you need to run resources/content-cg/hidden-tests/run-me.sh.  That
  script will set up the hidden files and directories needed for this test to work correctly.
=end
  def test_walker_hidden_exclusions
    
    if ( !(RUBY_PLATFORM =~ /mswin/) && !(RUBY_PLATFORM =~/cygwin/) )  # don't run hidden tests on a windows platform
      
      test = `ruby lib/discovery.rb --path ../test/resources/content-cg/hidden-tests --list-excluded`
      # printf(" test content: %s\n", test )
    
      # resources/content-cg/hidden-tests contains some . files that represent hidden files and directories on linux/solaris
      # if the exclusions are working, by default we don't look at hidden files
      #
      # since this test asks the CLI to show the list of excluded files and not the list of files scanned, only 
      # the hidden files that are excluded should be in the output list of this command, so try to match for those
      # to see if they got flagged as excluded
    
      if ( test.match('.svn') == nil )
        fail ".svn directory was not excluded even though it's a hidden dir.  Perhaps the no-hidden filter is not in the filters directory or the hidden-tests directory has not be set up."
      end
      if ( test.match('.htaccess') == nil )
        fail ".htaccess file was not excluded even though it's a hidden file.  Perhaps the no-hidden filter is not in the filters directory or the hidden-tests directory has not be set up."
      end
    end
    
    assert true
  end

   
end
