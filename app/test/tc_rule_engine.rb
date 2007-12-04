require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), "..", "main", "lib")
require 'rule_engine'

require File.join(File.dirname(__FILE__), '..', 'main', 'lib', 'conf', 'config')

class TcRuleEngine < Test::Unit::TestCase
  
  def setup
    
  end
  
  def teardown
    
  end
  
  def test_files_of_interest
    
    rulesfiledir = File.dirname(File.new(File.dirname(__FILE__) + '/resources/rules/test_dir_00_valid_original/README.txt', 'r').path)
    
    # TODO - need to make rule engine files of interest work based on speed hint they're encapsulated within
    
    re = RuleEngine.new(rulesfiledir, MockWalker.new, 2)
    
    prules = re.project_rules
    
    result_expressions = Array.new
    prules.each {|prule|
      prule.rulesets.each {|rs|
        if (rs.result_expression != nil) then
          result_expressions << rs.result_expression
        end
      }
    }
    
    # It is important that single ticks are used here instead of double because 
    # it allows us to exactly duplicate the string you see in the xml. Using 
    # double ticks would force you to have...
    #    "junit-([0-9]\\.[0-9])\\.jar" instead of 'junit-([0-9]\.[0-9])\.jar'
    expected_set = Set.new [/^httpd.exe/, /^libphp(.?).so$/, /^Apache.exe/,  /(.+?).jar/, /^httpd$/]
    
    # 'junit-([0-9]\.[0-9])\.jar' should only be in this list if the speed factor was 1 - a speed factor of 2 will cause this to be filtered out
    # 'version' was removed due as linux distro rule was commented out
    
    files = re.files_of_interest
    expected_set.each { |expected| 
      if (!files.include?(expected)) then
        fail "The 'files_of_interest' did not include '#{expected}' and it should have. \n('files_of_interest' = #{files.inspect})\n"
      end
    }
    
  end
  
  def test_eval_rule
    
    evalrule = EvalRule.new(  "(httpd AND htpasswd) OR (executables AND version)",  2 )
    
    rulenames = evalrule.get_rule_names()
    testnames = ["httpd","htpasswd","executables","version"]
    
    assert_equal(testnames, rulenames)
    assert_equal(2, evalrule.speed)
    
    testnames_out_of_order = ["htpasswd","executables","version", "httpd"]
    assert_not_equal(testnames_out_of_order, rulenames)
  end
  
  def test_md5_optimization
    p1 = ProjectRule.new("junit", "wild", "all")
    p1.eval_rule = EvalRule.new("junit_md5", 1 )
    
    # used by both rulesets
    file = File.new(File.dirname(__FILE__) + '/resources/content-cg/junit/junit-3.2.jar', "r")
    actual_filepath = File.expand_path(file.path)
    assert(File.exist?(actual_filepath), "Expected test resource did not exist: '#{actual_filepath}'")
    
    # set up RuleSet  
    rs = MatchRuleSet.new("junit_md5")
    rs.result_expression = "ju3.2 OR ju2"
    
    rs.match_rules = Array.new # this feels weird, because I'm turning a Set into an Array, but I don't know how else to test this optimization functionality if I can't ensure the order
    mr1 = MD5MatchRule.new("ju3.2", "(.+?).jar", "d5171fc6c7860889b8224b9f822fb891", "3.2")
    rs.match_rules << mr1
    
    mr2 = MD5MatchRule.new("ju2", "(.+?).jar", "06e503d7e6457e7c3470e65b36a1529f", "2")
    rs.match_rules << mr2
    
    p1.rulesets << rs
    
    rulesfiledir = File.expand_path(Config.prop(:rules_openlogic))
    re = RuleEngine.new(rulesfiledir, MockWalker.new, 1)
    re.project_rules << p1
    re.found_file(File.dirname(actual_filepath), File.basename(actual_filepath), nil)
    
    packages = p1.build_packages
    assert_equal(1, mr1.match_attempts)
    
    # match? should not have been called on mr2 - this is the optimization
    assert_equal(0, mr2.match_attempts)
    
  end
  
end

class MockWalker
  def subscribe(arg1)
    
  end
  
  def set_files_of_interest(arg1, arg2)
    
  end
end
