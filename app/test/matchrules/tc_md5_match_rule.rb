require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), '..', '..', 'main', 'lib', 'matchrules')
require 'md5_match_rule'

class TcMD5MatchRule < Test::Unit::TestCase
  
  def setup
    
  end
  
  def teardown
    
  end
  
  def test_match_true
    defined_digest = "f852bbb2bbe0471cef8e5b833cb36078"    
    md5_mr = MD5MatchRule.new("md5rule", "junit-4.4.jar", defined_digest, "4.4")    
    actual_filepath = File.new(File.dirname(__FILE__) + '/../resources/content-cg/junit/junit-4.4.jar', "r").path    
    assert md5_mr.match?(actual_filepath)
    
    assert md5_mr.matched_anything?
    assert_equal 1, md5_mr.matched_against.size
    assert md5_mr.matched_against.include?(File.dirname(actual_filepath))
    
    # make sure the version string makes it all the way down to the MatchRule base class
    assert "4.4" == md5_mr.version
    
    found_versions = md5_mr.get_found_versions(File.dirname(actual_filepath))
    assert_equal 1, found_versions.size
    found_versions.each { |version|
      assert_equal "4.4", version
    }
  end
  
  def test_match_false
    defined_digest = "f852bbb2bbe0471cef8e5b833cb36078"
    md5_mr = MD5MatchRule.new("md5rule", "junit-4.4.jar", defined_digest, "4.4")
    
    actual_filepath = File.new(File.dirname(__FILE__) + '/../resources/content-bad/junit/junit-4.4.jar', "r").path    
    assert !md5_mr.match?(actual_filepath)
    
    assert !md5_mr.matched_anything?
    assert_equal 0, md5_mr.matched_against.size
    
    # make sure the version string makes it all the way down to the MatchRule base class
    assert "4.4" == md5_mr.version
    
    found_versions = md5_mr.get_found_versions(File.dirname(actual_filepath))
    assert_equal 0, found_versions.size
  end
  
  def test_match_true_optimized
    defined_digest = "f852bbb2bbe0471cef8e5b833cb36078"    
    md5_mr = MD5MatchRule.new("md5rule", "junit-4.4.jar", defined_digest, "4.4")    
    actual_filepath = "junit-4.4.jar"  
    assert md5_mr.match?(actual_filepath, defined_digest)
    
    assert md5_mr.matched_anything?
    assert_equal 1, md5_mr.matched_against.size
    assert md5_mr.matched_against.include?(File.dirname(actual_filepath))
    
    # make sure the version string makes it all the way down to the MatchRule base class
    assert "4.4" == md5_mr.version
    
    found_versions = md5_mr.get_found_versions(File.dirname(actual_filepath))
    assert_equal 1, found_versions.size
    found_versions.each { |version|
      assert_equal "4.4", version
    }
  end
  
  def test_match_false_optimized
    defined_digest = "f852bbb2bbe0471cef8e5b833cb36078"
    md5_mr = MD5MatchRule.new("md5rule", "junit-4.4.jar", defined_digest, "4.4")    
    actual_filepath = "junit-4.4.jar"  
    assert !md5_mr.match?(actual_filepath, "foobar")
    
    assert !md5_mr.matched_anything?
    assert_equal 0, md5_mr.matched_against.size
  end
  
end
