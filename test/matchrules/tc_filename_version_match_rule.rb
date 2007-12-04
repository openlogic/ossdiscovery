require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), '..', '..', 'main', 'lib', 'matchrules')
require 'filename_version_match_rule'

class TcFilenameVersionMatchRule < Test::Unit::TestCase
  
  def setup
    
  end
  
  def teardown
    
  end
  
  def test_create
    attributes = Hash["name" => "fvmr", "filename" => "foofile"]
    
    fvmr = eval("FilenameVersionMatchRule.create(attributes)")
    
    assert_equal("fvmr", fvmr.name)
    assert_equal("foofile", fvmr.defined_filename.source)
  end
  
  def test_match_true
    mr = FilenameVersionMatchRule.new("filename-version-rule", 'junit-?([\d\.]+)\.jar')
    
    actual_filepath = "/home/me/junit2.jar"
    assert mr.match?(actual_filepath)
    assert mr.matched_anything?
    assert_equal 1, mr.matched_against.size
    key = File.dirname(actual_filepath)
    assert mr.matched_against.include?(key)
    match_set = mr.matched_against[key]
    assert_equal 1, match_set.size
    match_set.each { |match_val|
      assert_equal "2", match_val
    }
    
    actual_filepath = "/home/me/junit-3.2.jar"
    assert mr.match?(actual_filepath)
    assert mr.matched_anything?
    assert_equal 1, mr.matched_against.keys.size
    assert mr.matched_against.include?(key)
    match_set = mr.matched_against[key]
    assert_equal 2, match_set.size
    match_set.each { |match_val|
      assert(match_val == "2" || match_val = "3.2")
    }

    actual_filepath = "/home/me/junit-3.8.2.jar"
    assert mr.match?(actual_filepath)
    assert mr.matched_anything?
    assert_equal 1, mr.matched_against.size
    assert mr.matched_against.include?(key)
    match_set = mr.matched_against[key]
    assert_equal 3, match_set.size
    match_set.each { |match_val|
      assert(match_val == "2" || match_val = "3.2" || match_val = "3.8.2")
    }
  end
  
end
