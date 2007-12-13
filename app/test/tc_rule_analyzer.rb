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
  
  def test_it    
    mar1 = MatchAuditRecord.new('hibernate', 'fileversions', '102-hibernate-3.2.1.ga.tar.gz-hibernate3.jar', '/home/bnoll/projects/openlogic/ossdiscovery/app/test/resources/content-cg/hibernate/3.2.1.ga/hibernate3.jar', '3.2.1.ga')
    mar2 = MatchAuditRecord.new('hibernate', 'hibfiles', 'hibjar', '/home/bnoll/projects/openlogic/ossdiscovery/app/test/resources/content-cg/hibernate/3.2.1.ga/hibernate3.jar', '3')
    records = Array.new << mar1 << mar2
    analyzed_info = RuleAnalyzer.analyze_audit_records(records)
    assert analyzed_info.size > 0
  end

end
