require 'test/unit'

class TcWalkingSymLinks < Test::Unit::TestCase

=begin rdoc
  Note that before you can run the symlink test, you need to run resources/content-cg/symlink-tests/run-me.sh.  That
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
      
      test = `ruby lib/discovery.rb --path ../test/resources/content-cg/symlink-tests`
    
      if ( test.match('not followed.*?: 0') == nil )
        fail "Symlinks were not followed and should have been OR symlink-tests directory has not be set up.  Run run-me.sh in content-cg/symlinks-tests"        
      end
    end

  end
  
=begin rdoc
  black box test for not following symlinks
=end  
  def test_walker_nofollow_symlinks
    
    if ( !(RUBY_PLATFORM =~ /mswin/) )  # don't run symlink tests on a windows platform

       test = `ruby lib/discovery.rb --path ../test/resources/content-cg/symlink-tests --nofollow`

       if ( test.match('not followed.*?: 5') == nil )
         fail "Symlinks were not pruned OR symlink-tests directory has not be set up.  Run run-me.sh in content-cg/symlinks-tests"        
       end
     end
  end
   
end
