require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), '..', '..', 'main', 'lib')

require 'eval_rule'
require 'project_rule'
require 'match_rule_set'
require 'matchrules/binary_match_rule'
require 'matchrules/filename_match_rule'
require 'matchrules/md5_match_rule'

require File.join(File.dirname(__FILE__), '..', 'test_helper')

class TcProjectApache < Test::Unit::TestCase
  
  def setup
    
  end
  
  def teardown
    
  end
  
=begin rdoc
  Asserts that the apache project (version 2.0.58) is found using an AND of two rulesets.
  RuleSet 1: comprised of a FilenameMatchRule matching a file named 'httpd'.
  RuleSet 2: comprised of a BinaryMatchRule using a regexp to locate a String like 'Apache/2.0.58' in the binary.
=end  
  def test_build_packages_1
    p1 = ProjectRule.new("apache", nil, nil)
    p1.eval_rule = EvalRule.new("executables AND versionstring", 2 )
    
    # needed by both RuleSets
    file = File.new(File.dirname(__FILE__) + '/../resources/content-cg/apache/linux/2.0.58/bin/httpd', "r")
    actual_filepath = File.expand_path(file.path)
    assert(File.exist?(actual_filepath), "Expected test resource did not exist: '#{actual_filepath}'")
    
    # set up RuleSet 1
    rs1 = MatchRuleSet.new("executables")
    mr1 = FilenameMatchRule.new("httpd", "httpd")    
    assert mr1.match?(actual_filepath)
    rs1.match_rules << mr1
    
    # set up RuleSet 2
    rs2 = MatchRuleSet.new("versionstring")
    mr11 = BinaryMatchRule.new("version", "httpd", "Apache\/([0-9]+\.[0-9]+\.[0-9]+)")
    assert mr11.match?(actual_filepath)
    rs2.match_rules << mr11
    
    p1.rulesets << rs1 << rs2
    
    location_to_rulesets = p1.get_location_to_rulesets_hash
      
    assert_equal(1, location_to_rulesets.size)
    hash_of_matched_rulesets = location_to_rulesets[File.dirname(actual_filepath)]
    assert(hash_of_matched_rulesets.size == 2)
    assert(hash_of_matched_rulesets["executables"] == true)
    assert(hash_of_matched_rulesets["versionstring"] == true)
    
    locations = p1.evaluate
    assert_equal(1, locations.size)
    assert(locations.include?(File.dirname(actual_filepath)))
    packages = p1.build_packages
    assert_equal(1, packages.size)
    package = packages[0]
    assert_equal("apache", package.name)
    assert_equal("2.0.58", package.version)
    assert_equal(File.dirname(actual_filepath), package.found_at)
    
  end
  
=begin rdoc
  Asserts that multiple versions of the apache project (2.0.55 & 1.3.34) are 
  found in a directory structure like so. (These are not actual pathnames, just easy-to-read examples.)
    parent_dir/apache2_child_dir/actual_apache2_binary
    parent_dir/apache1_child_dir/actual_apache1_binary
 
  RuleSet: only 1, whose result expression is the OR of 4 MatchRules
  MatchRules: 4 BinaryMatchRules who specificy unique binary files to look for 'Apache/X.Y.Z' in.

  The final outcome should show that Apache 2.x is installed in 'apache2_child_dir' 
  and Apache 1.x is installed in 'apache1_child_dir'
=end
  def test_build_packages_2
    dir = File.new(File.dirname(__FILE__) + '/../resources/content-cg/apache/covalent-linux/README.txt').path
    dir = File.dirname(dir)
    files = TestHelper.find_all_files(File.expand_path(dir))
    
    p1 = ProjectRule.new("apache", "wild", "linux,sunos-5.10,sunos-5.9,sunos-5.8,macosx")
    p1.eval_rule = EvalRule.new("versionstring", 2 )

    # set up RuleSet  
    rs = MatchRuleSet.new("versionstring")
    rs.result_expression = "httpd OR httpsd OR httpsd_prefork OR httpsd_worker"
    
    mr1 = BinaryMatchRule.new("httpd", "^httpd$", "Apache/([0-9].[0-9]+.[0-9]+)")
    rs.match_rules << mr1
    
    mr2 = BinaryMatchRule.new("httpsd", "^httpsd$", "Apache/([0-9].[0-9]+.[0-9]+)")
    rs.match_rules << mr2
    
    mr3 = BinaryMatchRule.new("httpsd_prefork", "^httpsd.prefork$", "Apache/([0-9].[0-9]+.[0-9]+)")
    rs.match_rules << mr3
    
    mr4 = BinaryMatchRule.new("httpsd_worker", "^httpsd.worker$", "Apache/([0-9].[0-9]+.[0-9]+)")
    rs.match_rules << mr4
    
    p1.rulesets << rs
    
    files.each { |file| 
      val1 = mr1.match?(file)
      val2 = mr2.match?(file)
      val3 = mr3.match?(file)
      val4 = mr4.match?(file)
    }
    
    location_to_rulesets = p1.get_location_to_rulesets_hash
    assert_equal(2, location_to_rulesets.size)
    
    locations = p1.evaluate
    assert_equal(2, locations.size)
    locations.each { |loc|
      assert(loc.include?("content-cg/apache/covalent-linux/ers-3.0.2-20051229-httpd-1.3") || loc.include?("content-cg/apache/covalent-linux/ers-3.0.2-20051229-httpd-2.0"))
    }
    
    packages = p1.build_packages
    assert_equal(2, packages.size)
    packages.each { |package|
      assert_equal("apache", package.name)
      assert(package.version.eql?("2.0.55") || package.version.eql?("1.3.34"))
    }
  end
  
end
