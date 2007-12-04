require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), '..', '..', 'main', 'lib', 'matchrules')
require 'filename_match_rule'

class TcFilenameMatchRule < Test::Unit::TestCase
  
  def setup
    
  end
  
  def teardown
    
  end
  
  def test_match_true
    mr = FilenameMatchRule.new("filename-rule", "defined")
    
    actual_filepath = "/home/me/defined"
    assert mr.match?(actual_filepath)
    assert mr.matched_anything?
    assert_equal 1, mr.matched_against.size
    assert mr.matched_against.include?(File.dirname(actual_filepath))
    
    actual_filepath = "/home/you/defined"
    assert mr.match?(actual_filepath)
    assert mr.matched_anything?
    assert_equal 2, mr.matched_against.size
    assert mr.matched_against.include?(File.dirname(actual_filepath))
  end
  
  def test_match_true_regexp
    mr = FilenameMatchRule.new("filename-regexp-rule", "de[a-z]{2}ned")
    
    actual_filepath = "/home/me/defined"
    assert mr.match?(actual_filepath)
    assert mr.matched_anything?
    assert_equal 1, mr.matched_against.size
    assert mr.matched_against.include?(File.dirname(actual_filepath))
    
    actual_filepath = "/home/you/defined"
    assert mr.match?(actual_filepath)
    assert mr.matched_anything?
    assert_equal 2, mr.matched_against.size
    assert mr.matched_against.include?(File.dirname(actual_filepath))
  end
  
  def test_match_false
    mr = FilenameMatchRule.new("filename-rule", "defined.txt")
    
    actual_filepath_1 = "/home/me/defined.txt"    
    assert mr.match?(actual_filepath_1)
    actual_filepath_2 = "/home/me/actual.txt"
    assert !mr.match?(actual_filepath_2)
    assert mr.matched_anything?
    assert_equal 1, mr.matched_against.size
    assert mr.matched_against.include?(File.dirname(actual_filepath_1))
    
    mr2 = FilenameMatchRule.new("filename-rule", "defined")
    actual_filepath_2 = "/home/me/actual.txt"
    assert !mr2.match?(actual_filepath_2)
    assert !mr2.matched_anything?
    assert_equal 0, mr2.matched_against.size
  end
  
  def test_match_false_regexp
    actual_filepath_1 = "/home/me/defined.txt"
    mr = FilenameMatchRule.new("filename-regexp-rule", "de[a-z]ined.txt")
    assert mr.match?(actual_filepath_1)
    actual_filepath_2 = "/home/me/de7ined.txt"
    assert !mr.match?(actual_filepath_2)
    assert mr.matched_anything?
    assert_equal 1, mr.matched_against.size
    assert mr.matched_against.include?(File.dirname(actual_filepath_1))
    
    mr2 = FilenameMatchRule.new("filename-rule", "defined")
    actual_filepath_2 = "/home/me/actual.txt"
    assert !mr2.match?(actual_filepath_2)
    assert !mr2.matched_anything?
    assert_equal 0, mr2.matched_against.size
  end
  
  def test_match_true_state_change
    mr = FilenameMatchRule.new("filename-rule", "defined")
    
    actual_filepath = "/home/me/defined"
    assert mr.match?(actual_filepath)
    assert mr.matched_anything?
    assert_equal 1, mr.matched_against.size
    
    assert mr.match?(actual_filepath)
    # this should still only be 1, because we didn't change the 'actual_filepath'
    assert_equal 1, mr.matched_against.size
    assert mr.matched_anything?
  end
  
end
