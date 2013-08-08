require 'pp'
require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), '..', 'main', 'lib')
require 'rule_analyzer'
require 'matchrules/match_audit_record'

class TcRuleAnalyzer < Test::Unit::TestCase
  
  def setup
    
  end
  
  def teardown
    
  end
  
  def test_analyze_audit_records   
    mar1 = MatchAuditRecord.new('hibernate', 'fileversions', '102-hibernate-3.2.1.ga.tar.gz-hibernate3.jar', '/home/bnoll/projects/openlogic/ossdiscovery/app/test/resources/content-cg/hibernate/3.2.1.ga/hibernate3.jar', '3.2.1.ga')
    mar2 = MatchAuditRecord.new('hibernate', 'hibfiles', 'hibjar', '/home/bnoll/projects/openlogic/ossdiscovery/app/test/resources/content-cg/hibernate/3.2.1.ga/hibernate3.jar', '3')
    records = Array.new << mar1 << mar2
    analyzed_info = RuleAnalyzer.analyze_audit_records(records)
    assert analyzed_info.size > 0
  end
  
  def test_remove_our_dogfood()
    
    # one out of two should remain
    allpackages = Set.new
    p1 = Package.new()
    p1.name = 'ant'
    p1.version = '1.0'
    p1.found_at = '/home/bnoll/not/in/ossdiscovery/home'
    
    p2 = Package.new()
    p2.name = 'maven'
    p2.version = '1.0'
    p2.found_at = "#{ENV['OSSDISCOVERY_HOME']}/under/home/somewhere"
    
    allpackages << p1 << p2
    
    packages = RuleAnalyzer.remove_our_dogfood(allpackages)
    assert_equal(1, packages.size)
    
    
    # none out of two should remain
    allpackages = Set.new
    p1 = Package.new()
    p1.name = 'ant'
    p1.version = '1.0'
    p1.found_at = "#{ENV['OSSDISCOVERY_HOME']}/under/home/somewhere"
    
    p2 = Package.new()
    p2.name = 'maven'
    p2.version = '1.0'
    p2.found_at = "#{ENV['OSSDISCOVERY_HOME']}/somewhere/else/under/home"
    
    allpackages << p1 << p2
    
    packages = RuleAnalyzer.remove_our_dogfood(allpackages)
    assert_equal(0, packages.size)
    
    
    # two out of two should remain
    allpackages = Set.new
    p1 = Package.new()
    p1.name = 'ant'
    p1.version = '1.0'
    p1.found_at = "/should/not/be/removed"
    
    p2 = Package.new()
    p2.name = 'maven'
    p2.version = '1.0'
    p2.found_at = "/should/also/not/be/removed"
    
    allpackages << p1 << p2
    
    packages = RuleAnalyzer.remove_our_dogfood(allpackages)
    assert_equal(2, packages.size)
    
    
    # empty set should stay empty
    allpackages = Set.new
    
    packages = RuleAnalyzer.remove_our_dogfood(allpackages)
    assert_equal(0, packages.size)
    
    
    # nil set should stay nil and the method should not puke because the set is nil
    allpackages = nil
    
    packages = RuleAnalyzer.remove_our_dogfood(allpackages)
    assert_nil(allpackages)
  end

end
