require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), '..', '..', 'main', 'lib')
require 'rule_engine'
require 'expression'
require File.join(File.dirname(__FILE__), '..', 'test_helper')
require File.join(File.dirname(__FILE__), 'discovery_assertions')
require 'conf/config'

class TclongDiscoverItSpeed1 < Test::Unit::TestCase
  include DiscoveryAssertions
  
  @@log = Config.log
  
  def setup
    
  end
  
  def teardown
    
  end

  def test_discovery
    t1 = Time.new
    @@log.info('TclongDiscoverItSpeed1') {"Running... #{t1}"}
    # Setting up the RuleEnging and calling found file on each file in the 'content-cg' directory
    rulesfiledir = File.expand_path(Config.prop(:rules_openlogic))
    re = RuleEngine.new(rulesfiledir, MockWalker.new, 1)
    dir = File.new(File.dirname(__FILE__) + '/../resources/content-cg/README.txt').path
    dir = File.dirname(dir)
    files = TestHelper.find_all_files(File.expand_path(dir))
    files.each { |file|
      # printf("%s\n",File.basename(file) )
      re.found_file(File.dirname(file), File.basename(file), nil)
    }
    t2 = Time.new
    @@log.info('TclongDiscoverItSpeed1') {"It took '#{(t2-t1).to_s}' seconds to walk the files and do the matches for '#{re.project_rules.size}' projects."}
    
    t3 = Time.new
    packages = re.scan_complete
    t4 = Time.new
    @@log.info('TclongDiscoverItSpeed1') {"It took '#{(t4-t3).to_s}' seconds for 'rule_engine.scan_complete' to run."}
    
    # here for performance debugging stats
    @@log.debug('TclongDiscoverItSpeed1') {"BooleanExpression#evaluate was called #{BooleanExpression.get_evaluate_call_count} times."}
    match_call_count = 0
    rs_count = 0
    mr_count = 0
    re.project_rules.each { |prule|
      prule.rulesets.each { |rs|
        rs_count = rs_count + 1
        rs.match_rules.each { |mr|
          mr_count = mr_count + 1
          match_call_count = match_call_count + mr.match_attempts
        }
      }
    }
    @@log.debug('TclongDiscoverItSpeed1') {"match? was called #{match_call_count} times. (#{rs_count} RuleSets, #{mr_count} MatchRules)"}
   
    t5 = Time.new
    # This is where assertions can be made to verify that a certain package/version was found.
    
    assert_was_found_in_locations("aelfred", "1.2", "content-cg/aelfred", packages)
    
    assert_was_found("apache","1.3.34",packages )
    assert_was_found("apache","1.3.39",packages )
    assert_was_found("apache","2.0.46",packages )
    assert_was_found("apache","2.0.61",packages )
    assert_was_found("apache","2.2.4", packages )
    assert_was_found("apache","2.2.2", packages )
    assert_was_found_in_locations("apache", "2.2.3", "content-cg/apache/linux/2.2.3/ubuntu-apache2", packages)
    assert_was_not_found_in("apache", "unknown", "content-cg/apache/decoy", packages)
    
    
    assert_was_found("ant","1.1", packages )
    assert_was_found("ant","1.2", packages )
    assert_was_found("ant","1.3", packages )
    assert_was_found("ant","1.4", packages )
    assert_was_found("ant","1.5.1", packages )
    assert_was_found("ant","1.5", packages )
    assert_was_found("ant","1.5.2", packages )
    assert_was_found("ant","1.5.3-1", packages )
    assert_was_found("ant","1.5.4", packages )
    assert_was_found("ant","1.6.0", packages )
    assert_was_found("ant","1.6.1", packages )
    assert_was_found("ant","1.6.2", packages )
    assert_was_found("ant","1.6.3", packages )
    assert_was_found("ant","1.6.4", packages )
    assert_was_found("ant","1.6.5", packages )
    assert_was_found("ant","1.7.0", packages )
    
    assert_was_found_in_locations("ashkay", "0.6", "content-cg/ashkay", packages)
    
    assert_was_found_in_locations("axis", "1.4", ["content-cg/axis/1.4"], packages)
    assert_was_found_in_locations("axis2", "1.3", ["content-cg/axis"], packages)  # uses FilenameVersion - should cover all versions of axis2
    assert_was_found_in_locations("axis2", "M2", ["content-cg/axis"], packages)  # uses FilenameVersion
    
    assert_was_found_in_locations("blissed", "1.0-beta-1.20020815.040849", "content-cg/blissed", packages)
    
    assert_was_found_in_locations("c3p0", "0.9.1", "content-cg/c3p0", packages)
    assert_was_found_in_locations("coconut", "5.0-alpha-1", "content-cg/coconut", packages)
    
    assert_was_not_found_in("commons", "2.2", "content-cg/commons/attributes", packages)
    assert_was_found_in_locations("commons-attributes", "2.2", "content-cg/commons/attributes", packages)
    
    assert_was_found_in_locations("cvs", "1.12.13", "content-cg/cvs/linux/1.12.13", packages)
    assert_was_found_in_locations("cvs", "1.11.22", ["content-cg/cvs/sunos-9/1.11.22", "content-cg/cvs/win-cygwin/1.11.22"], packages)
    assert_was_found_in_locations("cvs", "1.11.17", "content-cg/cvs/win-32/1.11.17", packages)
    
    assert_was_found("dom4j", "1.4", packages )
    assert_was_found("dom4j", "1.5.2", packages )
    assert_was_found("dom4j", "1.6.1", packages )
    
    assert_was_found("eclipse", "3.3.0", packages )    
    assert_was_found("eclipse", "3.2.1", packages )  

    assert_was_found_in_locations("firefox", "1.0.7", "content-cg/firefox/windows/1.0.7", packages)
    assert_was_found_in_locations("firefox", "2.0.0.1", "content-cg/firefox/linux/2.0.0.1", packages)
    assert_was_found_in_locations("firefox", "2.0.0.9", "content-cg/firefox/windows/2.0.0.9", packages)    
    assert_was_found_in_locations("firefox", "2.0", "content-cg/firefox/osx/2.0/Firefox.app/Contents/MacOS", packages) 
    assert_was_found_in_locations("firefox", "1.5.0.4", "content-cg/firefox/linux/1.5.0.4", packages )   
        
    # spot check gcc - one from 4 series and one from 3 series
    assert_was_found("gcc", "4.1.0", packages )
    assert_was_found("gcc", "3.4.4", packages )
    # since ubuntu had cases that triggered false positives, test for these
    assert_was_not_found_in("gcc", "4.1.0", "content-cg/gcc/linux/ubuntu/decoy", packages)    
    assert_was_not_found_in("gcc", "3.3", "content-cg/gcc/linux/ubuntu/decoy", packages)     
    assert_was_not_found_in("gcc", "unknown", "content-cg/gcc/linux/ubuntu/decoy", packages)
        
    assert_was_found_in_locations("hamcrest", "1.1", "content-cg/hamcrest", packages)
    
    assert_was_found_in_locations("hibernate", "3.0.5", "content-cg/hibernate/3.0.5", packages )
    assert_was_found_in_locations("hibernate", "3.1.3", "content-cg/hibernate/3.1.3", packages )
    assert_was_found_in_locations("hibernate", "3.2.1.ga", "content-cg/hibernate/3.2.1.ga", packages )
    assert_was_found_in_locations("hibernate", "3.2.2.ga", "content-cg/hibernate/3.2.2.ga", packages )
    assert_was_found_in_locations("hibernate", "3.2.4.ga", "content-cg/hibernate/3.2.4.ga", packages )
        
    assert_was_found_in_locations("jboss", "3.2.7", "content-cg/jboss/3.2.7/lib", packages)
    assert_was_found_in_locations("jboss", "4.0.2", "content-cg/jboss/4.0.2/lib", packages)
    assert_was_found_in_locations("jboss", "4.0.3SP1", "content-cg/jboss/4.0.3SP1/lib", packages)
    assert_was_found_in_locations("jboss", "5.0.0.Beta2", "content-cg/jboss/5.0.0.Beta2/lib", packages)
    
    # spot check jdom
    assert_was_found_in_locations("jdom", "1.0", "content-cg/jdom/1.0", packages )  
    assert_was_found_in_locations("jdom", "b9", "content-cg/jdom/b9", packages ) 
    
    assert_was_found_in_locations("jempbox", "0.2.0", "content-cg/jempbox", packages)
    assert_was_found_in_locations("jencks", "2.1-all", "content-cg/jencks", packages)
    assert_was_found_in_locations("jline", "0.9.91", "content-cg/jline", packages)
        
    # spot check junit
    assert_was_found("junit", "3.8.1", packages )
    assert_was_found("junit", "3.2", packages )
    assert_was_found("junit", "4.3.1", packages )
    
    assert_was_found_in_locations("jstl", "1.0", "content-cg/jstl/1.0", packages)
    assert_was_found_in_locations("jstl", "1.1.0-B1", "content-cg/jstl/1.1.0-B1", packages)
    assert_was_found_in_locations("jstl", "1.1.2", "content-cg/jstl/1.1.2", packages)
    
    assert_was_found_in_locations("log4j", "1.0.4", "content-cg/log4j/1.0.4", packages)
    assert_was_found_in_locations("log4j", "1.2beta4", "content-cg/log4j", packages)
    assert_was_found_in_locations("log4j", "1.2.7", "content-cg/log4j", packages)
    assert_was_found_in_locations("log4j", "1.3alpha-8", "content-cg/log4j", packages)
      
    # spot check maven
    assert_was_found("maven", "1.0", packages ) 
    assert_was_found("maven", "1.0.1", packages )
    assert_was_found("maven", "1.1", packages )               
    assert_was_found("maven", "2.0-alpha-2", packages)
    assert_was_found("maven", "2.0.7", packages )

    # this is a project that doesn't follow maven repo conventions, so this tests the 
    # exception handling in the maven rule generate
    assert_was_found("maven-jstools-plugin", "0.3", packages)
        
    # spot check mysql
    assert_was_found("mysql", "5.0.45", packages)
    assert_was_found("mysql", "4.1.16", packages)
    
    # spot check openldap
    assert_was_found("openldap", "2.3.38", packages)
    assert_was_found("openldap", "2.2.15", packages)

    # this is a multi-hyphened jar find from autogenerated maven ruleset
    assert_was_found("opennms", "20031201-173122", packages )
   
    assert_was_found_in_locations("openoffice", "2.2.0", "content-cg/openoffice/linux/2.2.0", packages)
    # this is a binary that has some double byte regexp's in order to find the version
    assert_was_found_in_locations("openoffice", "2.3", "content-cg/openoffice/windows/2.3", packages)

    assert_was_not_found_in("openssh", "unknown", "content-cg/openssl/decoy", packages)   
                        
    # spot check openssl
    assert_was_found("openssl", "0.9.8a", packages )  
    assert_was_found("openssl", "0.9.8d", packages )

    
    # spot check perl
    assert_was_found("perl","5.8.5", packages)
    assert_was_found("perl", "5.8.8", packages )    
    assert_was_found("perl","5.6.1", packages)
    
    # spot check php
    assert_was_found("php","4.3.11", packages)  # some covalent 
    assert_was_found("php","4.4.7", packages)   # some os x or windows
    assert_was_found("php","5.2.4", packages)   # windows
    
    # spot check postgresql
    assert_was_found("postgresql", "8.0.3", packages )
    assert_was_found("postgresql", "8.1.3", packages )
    assert_was_found("postgresql", "8.1.4", packages )
    assert_was_found("postgresql", "8.1.5", packages )
    assert_was_not_found_in("postgresql", "unknown", "content-cg/postgresql/linux/decoy", packages)      
    
#    assert_was_found("poi", "1.8.0-dev-20020919", packages)
#    assert_was_found("poi", "2.0-final-20040126", packages)
#    assert_was_found("poi", "2.5-final-20040302", packages)
#    assert_was_found("poi", "2.5.1-final-20040804", packages)
#    assert_was_found("poi", "3.0.1-FINAL-20070705", packages)
    
    assert_was_found_in_locations("poi", "1.8.0-dev-20020919", "content-cg/poi", packages)
    assert_was_found_in_locations("poi", "2.0-final-20040126", "content-cg/poi", packages)
    assert_was_found_in_locations("poi", "2.5-final-20040302", "content-cg/poi", packages)
    assert_was_found_in_locations("poi", "2.5.1-final-20040804", "content-cg/poi", packages)
    assert_was_found_in_locations("poi", "3.0.1-FINAL-20070705", "content-cg/poi", packages)

    # this is a project that doesn't follow maven repo conventions, so this tests the 
    # exception handling in the maven rule generate
    assert_was_found("rife-continuations", "0.0.1", packages )
    assert_was_found("rife-continuations", "0.0.2", packages )
    assert_was_found_in_locations("roller", "2.3.1-rc2", "content-cg/roller/apache-roller-2.3.1-rc2-incubating/WEB-INF/lib", packages)
    assert_was_found_in_locations("roller", "3.0", "content-cg/roller/apache-roller-3.0-incubating/webapp/roller/WEB-INF/lib", packages)
    assert_was_found_in_locations("roller", "3.0.1-rc3", "content-cg/roller/apache-roller-3.0.1-rc3-incubating/webapp/roller/WEB-INF/lib", packages)
    assert_was_found_in_locations("roller", "3.1", "content-cg/roller/apache-roller-3.1/webapp/roller/WEB-INF/lib", packages)
    assert_was_found_in_locations("rxtx", "2.1.7", "content-cg/rxtx", packages)
        
    assert_was_found("spring", "1.2.2", packages )
    assert_was_found("spring", "2.0.7", packages )
    assert_was_found("spring", "1.2.9", packages )
    assert_was_found_in_locations("spring", "2.0-rc1", "content-cg/spring", packages)
    assert_was_found("spring", "2.0.2", packages )
    
    assert_was_found("struts", "1.0.2", packages)  # uses MD5
    assert_was_found("struts", "1.1-b1", packages)  # uses MD5
    assert_was_found("struts", "1.1-b2", packages)  # uses MD5
    assert_was_found("struts", "1.1-b3", packages)  # uses MD5
    assert_was_found("struts", "1.1-rc1", packages)  # uses MD5
    assert_was_found("struts", "1.1-rc2", packages)  # uses MD5
    assert_was_found("struts", "1.1", packages)  # uses MD5
    assert_was_found("struts", "1.2.2", packages)  # uses MD5
    assert_was_found("struts", "1.2.4", packages)  # uses MD5
    assert_was_found("struts", "1.2.6", packages)  # uses MD5
    assert_was_found("struts", "1.2.7", packages)  # uses MD5
    assert_was_found("struts", "1.2.8", packages)  # uses MD5
    assert_was_found("struts", "1.2.9", packages)  # uses MD5
    assert_was_found("struts", "1.3.9", packages)  # uses FilenameVersion
    assert_was_found("struts2", "2.0.9", packages) # should cover all 2.x versions
    
    assert_was_found("subversion", "1.3.1", packages)     
    assert_was_found("subversion", "1.4.3", packages)  
    assert_was_found("subversion", "1.4.5", packages)
    
    assert_was_found("thunderbird", "2.0.0.9",  packages)       
    assert_was_found_in_locations("thunderbird", "1.5.0.14", "content-cg/thunderbird/ubuntu/1.5.0.14pre", packages) 
    # false positive test
    assert_was_not_found_in("thunderbird", "unknown", "content-cg/firefox/windows/1.0.7", packages)   
            
    assert_was_found("tomcat", "4.1.36-LE-jdk14", packages )
    assert_was_found("tomcat", "5.5.25", packages )
    assert_was_found("tomcat", "4.1.34", packages )
    assert_was_found("tomcat", "6.0.13", packages )            
    
    assert_was_found("velocity", "1.0b1", packages )
    assert_was_found("velocity", "1.2", packages )
    assert_was_found("velocity", "1.5", packages )
    assert_was_found("velocity", "1.3.1-rc2", packages )
    
    assert_was_found_in_locations("vim", "7.0", "content-cg/vim/linux/ubuntu/7.0", packages)
    assert_was_found("vim", "7.1", packages)
    assert_was_found("vim", "6.4", packages)
    
    assert_was_found_in_locations("xalan", "2.7.0", ["content-cg/xalan/xalan-j_2_7_0-bin-2jars", "content-cg/xalan/xalan-j_2_7_0-bin"], packages)
    
    assert_was_found_in_locations("xerces", "1.0.1", "content-cg/xerces/1.0.1", packages)
    assert_was_found_in_locations("xerces", "2.9.0", "content-cg/xerces/2.9.0", packages)
    
    assert_was_found_in_locations("xpl4java", "1.3h", "content-cg/xpl4java", packages)
    
    t6 = Time.new
    @@log.info('TclongDiscoverItSpeed1') {"It took '#{(t6-t5).to_s}' seconds to assert various projects were found."}
    
  end

end

class MockWalker
  attr_accessor :file_ct, :dir_ct, :sym_link_ct, :bad_link_ct, :permission_denied_ct, :foi_ct, :not_found_ct
  attr_accessor :follow_symlinks, :symlink_depth, :not_followed_ct, :show_every, :show_verbose, :show_progress
  attr_accessor :list_exclusions, :list_files, :show_permission_denied
  
  def subscribe(arg1)
    
  end
  
  def set_files_of_interest(arg1, arg2)
    
  end
end
