require 'find'
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
    if ( RUBY_PLATFORM =~ /mswin/ or (RUBY_PLATFORM =~ /java/) )  # don't run symlink tests on a windows platform or if this is a jruby run as jruby soils the bed with symlinks in most cases
      assert true, "don't run symlink tests on a windows platform or if this is a jruby run as jruby soils the bed with symlinks in most cases"
    else
      puts "got here for some odd reason"  
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
    
    if ( !(RUBY_PLATFORM =~ /mswin/) or !(RUBY_PLATFORM =~ /java/) )  # don't run symlink tests on a windows platform or if this is a jruby run as jruby soils the bed with symlinks in most cases

      test = `ruby #{DISCOVERY_RB} --path #{SYMLINK_TESTS_DIR} --nofollow`

      if ( test.match('not followed.*?: 5') == nil )
        fail "Symlinks were not pruned OR symlink-tests directory has not be set up.  Run run-me.sh in symlinks-tests"        
      end
    end
  end
   
  def test_presence_of_infinite_recursion_on_circular_link
     
    symlinks_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', 'resources', 'symlink-tests', 'ignore_these', 'setup-circular-link'))
    assert(File.exist?(symlinks_dir) && File.directory?(symlinks_dir), "Expected the directory '#{symlinks_dir}' to exist. In order to create it, just run the 'run-me.sh' script located two levels up from the expected directory.")
    
    max_recurse_attempts = 100
    msg = "\n########## WARNING WARNING WARNING WARNING WARNING ##################################"
    msg = msg << "\nThis environment recurses more than it needs to when it encounters circular symlinks."
    print_warning = false
    begin     
      path_count = 0
      Find.find(symlinks_dir) do |path|
        path_count = path_count + 1
        
        if (path_count > 2) then # 42 is the number of times I saw it try on Ubuntu 7.04 with java 1.5.0_12-b04 before it stopped
          print_warning = true
        end # of if (path_count >2)
        
        if (path_count > max_recurse_attempts) # arbitrarily picked this value, the recursion ought to be done by now
          begin
            require 'java'
          rescue Exception => e
            fail("This means something bad has happened.  We thought that this infinite recursion problem was limited to when we only ran with JRuby.  If we got an exception when trying to require 'java', I think it means that the parent process was kicked off with native Ruby, not JRuby.\nException = #{e.inspect}")
          end
#          msg = msg << "\nJAVA SYSTEM PROPERTIES"
#          java.lang.System.getProperties().list(java.lang.System.out);
  
          # you can get at the individual properties if you want like this...
          #   java_version = java.lang.System.get_property("java.version") 
          # which is the same as...
          #   java_version = Java::JavaLang::System.getProperty
           
          msg = msg << "\nJAVA VERSION: " << java.lang.System.get_property("java.vm.version")
          msg = msg << "\n########## WARNING WARNING WARNING WARNING WARNING ##################################\n"
           
          raise msg
        end # of if (path_count > 100)

#        puts "#{path_count}: #{path}" 
      
      end # of Find.find(dir)
    rescue Exception => e
      # do nothing, let this flow through and print the warning below
    end
     
    assert(path_count > 0)
    
    if (print_warning) then
      begin
        require 'java'
      rescue Exception => e
        fail("This means something bad has happened.  We thought that this infinite recursion problem was limited to when we only ran with JRuby.  If we got an exception when trying to require 'java', I think it means that the parent process was kicked off with native Ruby, not JRuby.\nException = #{e.inspect}")
      end
       
      msg = msg << "\nJAVA VERSION: " << java.lang.System.get_property("java.vm.version")
      msg = msg << "\nattempted to recurse #{path_count} times (max attempts was set to #{max_recurse_attempts})"
      msg = msg << "\n########## WARNING WARNING WARNING WARNING WARNING ##################################\n"
      puts(msg)
    end # of if (print_warning)
    
  end
   
end
