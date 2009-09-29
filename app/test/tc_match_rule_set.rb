require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), "..", "main", "lib")
require 'match_rule_set'
require 'matchrules/filename_match_rule'

class TcMatchRuleSet < Test::Unit::TestCase
  
  def setup
    
  end
  
  def teardown
    
  end
  
  def test_evaluate_0
    # Scenario: all 3 match rules are true for 1 location
  
#    <ruleset name="executables">
#      <result>httpd AND apxs AND htpasswd</result>
#      <matchrule name="httpd" type="filename" filename="httpd" />
#      <matchrule name="apxs" type="filename" filename="apxs" />
#      <matchrule name="htpasswd" type="filename" filename="htpasswd" />
#    </ruleset>

    # FilenameMatchRule#initialize(name, defined_filename)
    
    mr1 = FilenameMatchRule.new("rule-httpd", "httpd")
    val1 = mr1.match?("/home/me/httpd", [])
    
    mr2 = FilenameMatchRule.new("rule-apxs", "apxs")
    val2 = mr2.match?("/home/me/apxs", [])
    
    mr3 = FilenameMatchRule.new("rule-htpasswd", "htpasswd")
    val3 = mr3.match?("/home/me/htpasswd", [])
    
    rs = MatchRuleSet.new("executables")
    rs.match_rules << mr1 << mr2 << mr3
    
    locations = rs.get_ruleset_match_locations
    
    assert_equal(1, locations.size)
    locations.each { |unique_dir, outcome| 
      if (unique_dir == "/home/me") then
        assert_equal(3, outcome.size)
        outcome.each { |mr, did_it_match|
          assert did_it_match
        }
      else
        fail "Expected the unique dirs in this Hash (the keys of it) to be one of: '/home/me'"
      end
    } # end of locations.each
    
    successful_match_dirs = rs.evaluate()
    assert 1, successful_match_dirs.size
  end
  
  def test_evaluate_1
    # Scenario: all 3 match rules are true for 2 locations
  
#    <ruleset name="executables">
#      <result>httpd AND apxs AND htpasswd</result>
#      <matchrule name="httpd" type="filename" filename="httpd" />
#      <matchrule name="apxs" type="filename" filename="apxs" />
#      <matchrule name="htpasswd" type="filename" filename="htpasswd" />
#    </ruleset>

    # FilenameMatchRule#initialize(name, defined_filename)
    
    mr1 = FilenameMatchRule.new("rule-httpd", "httpd")
    val1 = mr1.match?("/home/me/httpd", [])
    val1 = mr1.match?("/away/me/httpd", [])
    
    mr2 = FilenameMatchRule.new("rule-apxs", "apxs")
    val2 = mr2.match?("/home/me/apxs", [])
    val2 = mr2.match?("/away/me/apxs", [])
    
    mr3 = FilenameMatchRule.new("rule-htpasswd", "htpasswd")
    val3 = mr3.match?("/home/me/htpasswd", [])
    val3 = mr3.match?("/away/me/htpasswd", [])
    
    rs = MatchRuleSet.new("executables")
    rs.match_rules << mr1 << mr2 << mr3
    
    locations = rs.get_ruleset_match_locations
    
    assert_equal(2, locations.size)
    locations.each { |unique_dir, outcome| 
      if (unique_dir == "/home/me") then
        assert_equal(3, outcome.size)
        outcome.each { |mr, did_it_match|
          assert did_it_match
        }
      
      elsif (unique_dir == "/away/me")
        assert_equal(3, outcome.size)
        outcome.each { |mr, did_it_match|
          assert did_it_match
        }
      
      else
        fail "Expected the unique dirs in this Hash (the keys of it) to be one of: '/home/me' or '/away/me'"
      end
    } # end of locations.each
    
    successful_match_dirs = rs.evaluate()
    assert 2, successful_match_dirs.size
    
  end
  
  def test_evaluate_2
    
    # Scenario: all 3 match rules are true for 1 location ('home/me'), 
    # and only 2 of the 3 match rules are true for another location ('away/me')

#    <ruleset name="executables">
#      <result>httpd AND apxs AND htpasswd</result>
#      <matchrule name="httpd" type="filename" filename="httpd" />
#      <matchrule name="apxs" type="filename" filename="apxs" />
#      <matchrule name="htpasswd" type="filename" filename="htpasswd" />
#    </ruleset>

    # FilenameMatchRule#initialize(name, defined_filename)
    
    mr1 = FilenameMatchRule.new("rule-httpd", "httpd")
    val1 = mr1.match?("/home/me/httpd", [])
    val11 = mr1.match?("/away/me/httpd", [])
    
    mr2 = FilenameMatchRule.new("rule-apxs", "apxs")
    val2 = mr2.match?("/home/me/apxs", [])
    val22 = mr2.match?("/away/me/apxs", [])
    
    mr3 = FilenameMatchRule.new("rule-htpasswd", "htpasswd")
    val3 = mr3.match?("/home/me/htpasswd", [])
    assert val3
    val33 = mr3.match?("/away/me/foo", [])
    
    rs = MatchRuleSet.new("executables")
    rs.match_rules << mr1 << mr2 << mr3
    
    locations = rs.get_ruleset_match_locations
    
    assert_equal(2, locations.size)
    locations.each { |unique_dir, outcome| 
      if (unique_dir == "/home/me") then
        assert_equal(3, outcome.size)
        outcome.each { |mr, did_it_match|
          assert did_it_match
        }
      
      elsif (unique_dir == "/away/me")
        assert_equal(3, outcome.size)
        outcome.each { |mr, did_it_match|
          if (mr.defined_filename.source == "htpasswd") then
            assert !did_it_match
          else
            assert did_it_match
          end
        }
      
      else
        fail "Expected the unique dirs in this Hash (the keys of it) to be one of: '/home/me' or '/away/me'"
      end
    } # end of locations.each
    
    successful_match_dirs = rs.evaluate()
    assert 1, successful_match_dirs.size
    
  end
  
  def test_evaluate_3
    
    # Scenario: all 3 match rules are false... aka... they never get matched to anything

#    <ruleset name="executables">
#      <result>httpd AND apxs AND htpasswd</result>
#      <matchrule name="httpd" type="filename" filename="httpd" />
#      <matchrule name="apxs" type="filename" filename="apxs" />
#      <matchrule name="htpasswd" type="filename" filename="htpasswd" />
#    </ruleset>

    # FilenameMatchRule#initialize(name, defined_filename)
    
    mr1 = FilenameMatchRule.new("rule-httpd", "httpd")
    val1 = mr1.match?("/home/me/baz", [])
    
    mr2 = FilenameMatchRule.new("rule-apxs", "apxs")
    val2 = mr2.match?("/home/me/foo", [])
    
    mr3 = FilenameMatchRule.new("rule-htpasswd", "htpasswd")
    val3 = mr3.match?("/home/me/bar", [])
    
    rs = MatchRuleSet.new("executables")
    rs.match_rules << mr1 << mr2 << mr3
    
    locations = rs.get_ruleset_match_locations
    
    assert_equal(0, locations.size)
    
    successful_match_dirs = rs.evaluate()
    assert 0, successful_match_dirs.size
  end
  
  def test_evaluate_4
    # Scenario: match rules A and B are true for location X, match rule C is false for location X
    #           match rules A and B are true for location Y, match rule C is false for location Y
  
#    <ruleset name="executables">
#      <result>httpd AND apxs AND htpasswd</result>
#      <matchrule name="httpd" type="filename" filename="httpd" />
#      <matchrule name="apxs" type="filename" filename="apxs" />
#      <matchrule name="htpasswd" type="filename" filename="htpasswd" />
#    </ruleset>

    # FilenameMatchRule#initialize(name, defined_filename)
    
    mr1 = FilenameMatchRule.new("rule-httpd", "httpd")
    val1 = mr1.match?("/home/me/httpd", [])
    val1 = mr1.match?("/away/me/httpd", [])
    
    mr2 = FilenameMatchRule.new("rule-apxs", "apxs")
    val2 = mr2.match?("/home/me/apxs", [])
    val2 = mr2.match?("/away/me/apxs", [])
    
    mr3 = FilenameMatchRule.new("rule-htpasswd", "htpasswd")
    val3 = mr3.match?("/home/me/foo", [])
    val3 = mr3.match?("/away/me/bar", [])
    
    rs = MatchRuleSet.new("executables")
    rs.match_rules << mr1 << mr2 << mr3
    
    locations = rs.get_ruleset_match_locations
    
    assert_equal(2, locations.size)
    locations.each { |unique_dir, outcome| 
      if (unique_dir == "/home/me") then
        assert_equal(3, outcome.size)
        outcome.each { |mr, did_it_match|
          if (mr.defined_filename.source == "htpasswd") then
            assert !did_it_match
          else
            assert did_it_match
          end
        }
      
      elsif (unique_dir == "/away/me")
        assert_equal(3, outcome.size)
        outcome.each { |mr, did_it_match|
          if (mr.defined_filename.source == "htpasswd") then
            assert !did_it_match
          else
            assert did_it_match
          end
        }
      
      else
        fail "Expected the unique dirs in this Hash (the keys of it) to be one of: '/home/me' or '/away/me'"
      end
    } # end of locations.each
    
    successful_match_dirs = rs.evaluate()
    assert 0, successful_match_dirs.size
    
  end  
  
    def test_evaluate_5
    # Scenario: match rules A and B are true for location X, match rule C is false for location X
    #           match rules A and C are true for location Y, match rule B is false for location Y
  
#    <ruleset name="executables">
#      <result>httpd AND apxs AND htpasswd</result>
#      <matchrule name="httpd" type="filename" filename="httpd" />
#      <matchrule name="apxs" type="filename" filename="apxs" />
#      <matchrule name="htpasswd" type="filename" filename="htpasswd" />
#    </ruleset>

    # FilenameMatchRule#initialize(name, defined_filename)
    
    mr1 = FilenameMatchRule.new("rule-httpd", "httpd")
    val1 = mr1.match?("/home/me/httpd", [])
    val1 = mr1.match?("/away/me/httpd", [])
    
    mr2 = FilenameMatchRule.new("rule-apxs", "apxs")
    val2 = mr2.match?("/home/me/apxs", [])
    val2 = mr2.match?("/away/me/foo", [])
    
    mr3 = FilenameMatchRule.new("rule-htpasswd", "htpasswd")
    val3 = mr3.match?("/home/me/foo", [])
    val3 = mr3.match?("/away/me/htpasswd", [])
    
    rs = MatchRuleSet.new("executables")
    rs.match_rules << mr1 << mr2 << mr3
    
    locations = rs.get_ruleset_match_locations
    
    assert_equal(2, locations.size)
    locations.each { |unique_dir, outcome| 
      if (unique_dir == "/home/me") then
        assert_equal(3, outcome.size)
        outcome.each { |mr, did_it_match|
          if (mr.defined_filename.source == "htpasswd") then
            assert !did_it_match
          else
            assert did_it_match
          end
        }
      
      elsif (unique_dir == "/away/me")
        assert_equal(3, outcome.size)
        outcome.each { |mr, did_it_match|
          if (mr.defined_filename.source == "apxs") then
            assert !did_it_match
          else
            assert did_it_match
          end
        }
      
      else
        fail "Expected the unique dirs in this Hash (the keys of it) to be one of: '/home/me' or '/away/me'"
      end
    } # end of locations.each
    
    successful_match_dirs = rs.evaluate()
    assert 0, successful_match_dirs.size
    
  end  
  
end
