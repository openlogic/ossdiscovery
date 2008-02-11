require 'test/unit'

class TcWalkingSymLinks < Test::Unit::TestCase
  
  DISCOVERY_RB = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'main', 'lib', 'discovery.rb')) unless defined? DISCOVERY_RB
  SYMLINK_TESTS_DIR = File.expand_path(File.join(File.dirname(__FILE__), '..', 'resources', 'symlink-tests')) unless defined? SYMLINK_TESTS_DIR

=begin rdoc
  Note that before you can run the symlink test, you need to run resources/symlink-tests/run-me.sh.  That
  script will set up the symlink files and directories needed for this test to work correctly.
=end  
  def setup

  end
  
  def teardown
    
  end
  
=begin rdoc
  black box test for following symlinks which is the default
=end
  def test_walker_follow_symlinks
    
    if ( !(RUBY_PLATFORM =~ /mswin/) )  # don't run symlink tests on a windows platform
      
      test = `ruby #{DISCOVERY_RB} --path #{SYMLINK_TESTS_DIR}`
    
      if ( test.match('not followed.*?: 0') == nil )
        fail "Symlinks were not followed and should have been OR symlink-tests directory has not be set up.  Run run-me.sh in symlinks-tests"        
      end
    end

  end
  
=begin rdoc
  black box test for not following symlinks
=end  
  def test_walker_nofollow_symlinks
    
    if ( !(RUBY_PLATFORM =~ /mswin/) )  # don't run symlink tests on a windows platform

       test = `ruby #{DISCOVERY_RB} --path #{SYMLINK_TESTS_DIR} --nofollow`

       if ( test.match('not followed.*?: 5') == nil )
         fail "Symlinks were not pruned OR symlink-tests directory has not be set up.  Run run-me.sh in symlinks-tests"        
       end
     end
   end
   
   def test_presence_of_infinite_recursion_on_circular_link
     
     symlinks_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', 'resources', 'symlink-tests', 'ignore_thesexxxxx'))
     assert(File.exist?(symlinks_dir) && File.directory?(symlinks_dir), "Expected the directory '#{symlinks_dir}' to exist. In order to create it, just run the 'run-me.sh' script located here: '#{File.dirname(symlinks_dir)}'")
     
   end
   
end
