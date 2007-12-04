require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), '..', '..', 'main', 'lib', 'matchrules')
require 'binary_match_rule'

class TcBinaryMatchRule < Test::Unit::TestCase
  
  @@log = Config.log
  
  def setup
    
  end
  
  def teardown
    
  end
  
  def test_match_true
    binary_mr = BinaryMatchRule.new("binaryrule", "httpd", /Apache\/([0-9]+\.[0-9]+\.[0-9]+)/)
    actual_filepath = File.new(File.dirname(__FILE__) + '/../resources/content-cg/apache/linux/2.0.58/bin/httpd', "r").path
    assert binary_mr.match?(actual_filepath)
    
    assert binary_mr.matched_anything?
    assert_equal 1, binary_mr.matched_against.size
    key = File.dirname(actual_filepath)
    assert binary_mr.matched_against.include?(key)
    match_set = binary_mr.matched_against[key]
    assert_equal 1, match_set.size
    match_set.each { |match_val|
      assert_equal "2.0.58", match_val
    }
    
    versions = binary_mr.get_found_versions(File.dirname(actual_filepath))
    assert_equal 1, versions.size
    versions.each { |version|
      assert_equal "2.0.58", version
    }
  end
  
  def test_match_true_two_versions_in_same_dir
    binary_mr = BinaryMatchRule.new("binaryrule", 'httpd.*', /Apache\/([0-9]+\.[0-9]+\.[0-9]+)/)
    actual_filepath = File.new(File.dirname(__FILE__) + '/../resources/content-cg/apache/linux/two_versions_in_same_dir/httpd-2.0.58', "r").path
    assert binary_mr.match?(actual_filepath)
    key = File.dirname(actual_filepath)
    
    assert binary_mr.matched_anything?
    assert_equal 1, binary_mr.matched_against.keys.size    
    assert binary_mr.matched_against.include?(key)
    match_set = binary_mr.matched_against[key]
    assert_equal 1, match_set.size
    match_set.each { |match_val|
      assert_equal "2.0.58", match_val
    }
    
    actual_filepath = File.new(File.dirname(__FILE__) + '/../resources/content-cg/apache/linux/two_versions_in_same_dir/httpd-2.0.59', "r").path
    assert binary_mr.match?(actual_filepath)
    assert_equal 1, binary_mr.matched_against.keys.size
    assert binary_mr.matched_against.include?(key)
    match_set = binary_mr.matched_against[key]
    assert_equal 2, match_set.size
    match_set.each { |match_val|
      assert(match_val == "2.0.58" ||  match_val = "2.0.59")
    }
    
    versions = binary_mr.get_found_versions(File.dirname(actual_filepath))
    assert_equal 2, versions.size
    versions.each { |version|
      assert(version == "2.0.58" ||  version = "2.0.59")
    }
  end
  
  def test_match_false
    binary_mr = BinaryMatchRule.new("binaryrule", "httpd", /Apache\/([0-9]+\.[0-9]+\.[0-9]+)/)
    # This httpd file was created like this:
    #   cp ./src/test/resources/content-cg/junit/junit-4.4.jar ./src/test/resources/content-bad/apache/httpd
    actual_filepath = File.new(File.dirname(__FILE__) + '/../resources/content-bad/apache/httpd', "r").path
    assert !binary_mr.match?(actual_filepath)
    
    assert !binary_mr.matched_anything?
    assert_equal 0, binary_mr.matched_against.size
    
    versions = binary_mr.get_found_versions(File.dirname(actual_filepath))
    assert_equal 0, versions.size
  end
  
end
