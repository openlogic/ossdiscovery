require 'test/unit'

class TcWalkerExclusions < Test::Unit::TestCase
  
  DISCOVERY_RB = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'main', 'lib', 'discovery.rb')) unless defined? DISCOVERY_RB
  HIDDEN_TESTS_DIR = File.expand_path(File.join(File.dirname(__FILE__), '..', 'resources', 'hidden-tests')) unless defined? HIDDEN_TESTS_DIR

=begin rdoc
  Note that before you can run the hidden test, you need to run resources/hidden-tests/run-me.sh.  That
  script will set up the hidden files and directories needed for this test to work correctly.
=end  
  def setup

  end
  
  def teardown
    
  end
  
=begin rdoc
  Note that before you can run the hidden test, you need to run resources/hidden-tests/run-me.sh.  That
  script will set up the hidden files and directories needed for this test to work correctly.
=end
  def test_walker_hidden_exclusions
    
    if ( !(RUBY_PLATFORM =~ /mswin/) && !(RUBY_PLATFORM =~/cygwin/) )  # don't run hidden tests on a windows platform
      
      test = `ruby #{DISCOVERY_RB} --path #{HIDDEN_TESTS_DIR} --list-excluded`
      # printf(" test content: %s\n", test )
    
      # resources/hidden-tests contains some . files that represent hidden files and directories on linux/solaris
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
