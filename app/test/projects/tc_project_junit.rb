require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), '..', '..', 'main', 'lib')

require 'eval_rule'
require 'project_rule'
require 'match_rule_set'
require 'matchrules/binary_match_rule'
require 'matchrules/filename_match_rule'
require 'matchrules/md5_match_rule'

class TcProjectJunit < Test::Unit::TestCase
  
  def setup
    
  end
  
  def teardown
    
  end
  
=begin rdoc
  Asserts that two distinct versions of the junit project (3.2 & 3.4) are found in the same directory using an OR of two rulesets.
  Both RuleSets are comprised of a single MD5MatchRule.
=end
  def test_build_packages_1
    p1 = ProjectRule.new("junit", "wild", "all")
    p1.eval_rule = EvalRule.new("ju3.2 OR ju3.4", 2 )
    
    # set up RuleSet 1
    file1 = File.new(File.dirname(__FILE__) + '/../resources/content-cg/junit/junit-3.2.jar', "r")
    actual_filepath1 = File.expand_path(file1.path)
    assert(File.exist?(actual_filepath1), "Expected test resource did not exist: '#{actual_filepath1}'")
    
    rs1 = MatchRuleSet.new("ju3.2")
    mr1 = MD5MatchRule.new("jujar", "(.+?).jar", "d5171fc6c7860889b8224b9f822fb891", "3.2")
    assert mr1.match?(actual_filepath1)
    rs1.match_rules << mr1
    
    # set up RuleSet 2
    file2 = File.new(File.dirname(__FILE__) + '/../resources/content-cg/junit/junit-3.4.jar', "r")
    actual_filepath2 = File.expand_path(file2.path)
    assert(File.exist?(actual_filepath2), "Expected test resource did not exist: '#{actual_filepath2}'")
    
    rs2 = MatchRuleSet.new("ju3.4")
    mr11 = MD5MatchRule.new("jujar", "(.+?).jar", "04023ede5a649ec9a61596e046f44ba0", "3.4")
    assert mr11.match?(actual_filepath2)
    rs2.match_rules << mr11
    
    p1.rulesets << rs1 << rs2
    
    location_to_rulesets = p1.get_location_to_rulesets_hash
      
    assert_equal(1, location_to_rulesets.size)
    hash_of_matched_rulesets = location_to_rulesets[File.dirname(actual_filepath1)]
    assert(hash_of_matched_rulesets.size == 2)
    assert(hash_of_matched_rulesets["ju3.2"] == true)
    assert(hash_of_matched_rulesets["ju3.4"] == true)
    
    locations = p1.evaluate
    assert_equal(1, locations.size)
    assert(locations.include?(File.dirname(actual_filepath1)))

    packages = p1.build_packages
    assert_equal(2, packages.size)
    versions = Set.new
    packages.each { |package|
      assert_equal("junit", package.name)
      assert_equal(File.dirname(actual_filepath1), package.found_at)
      versions << package.version
    }
    assert versions.include?("3.2")
    assert versions.include?("3.4")
    
  end
  
=begin rdoc
  Asserts that the junit project (version 3.8.1) is accurately found.
  RuleSet: only 1, whose result expression is the OR of two match rules
  MatchRule 1: an MD5MatchRule to identify version 3.2
  MatchRule 2: an MD5MatchRule to identify version 3.8.1

  Based on the file of interest we're passing the MatchRule, only version 3.8.1 should be discovered.
=end
  def test_build_packages_2
    p1 = ProjectRule.new("junit", "wild", "all")
    p1.eval_rule = EvalRule.new("junit_md5", 2 )

    # used by both rulesets
    file = File.new(File.dirname(__FILE__) + '/../resources/content-cg/junit/only-junit-3.8.1/junit-3.8.1.jar', "r")
    actual_filepath = File.expand_path(file.path)
    assert(File.exist?(actual_filepath), "Expected test resource did not exist: '#{actual_filepath}'")
    
    # set up RuleSet  
    rs = MatchRuleSet.new("junit_md5")
    rs.result_expression = "ju3.2 OR ju3.8.1"
    
    mr1 = MD5MatchRule.new("ju3.2", "(.+?).jar", "d5171fc6c7860889b8224b9f822fb891", "3.2")
    assert !mr1.match?(actual_filepath)
    rs.match_rules << mr1
    
    mr2 = MD5MatchRule.new("ju3.8.1", "(.+?).jar", "1f40fb782a4f2cf78f161d32670f7a3a", "3.8.1")
    assert mr2.match?(actual_filepath)
    rs.match_rules << mr2
    
    p1.rulesets << rs
    
    location_to_rulesets = p1.get_location_to_rulesets_hash
    assert_equal(1, location_to_rulesets.size)
    hash_of_matched_rulesets = location_to_rulesets[File.dirname(actual_filepath)]
    assert(hash_of_matched_rulesets.size == 1)
    assert(hash_of_matched_rulesets["junit_md5"] == true)
    
    locations = p1.evaluate
    assert_equal(1, locations.size)
    assert(locations.include?(File.dirname(actual_filepath)))

    packages = p1.build_packages    
    assert_equal(1, packages.size)
    versions = Set.new
    packages.each { |package|
      assert_equal("junit", package.name)
      assert_equal(File.dirname(actual_filepath), package.found_at)
      assert_equal("3.8.1", package.version)
    }
    
  end
  
end
