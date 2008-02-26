require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), "..", "main", "lib")
require 'scan_rules_reader'

require 'digest/md5' 
require 'test_helper'

class TcScanRulesReader < Test::Unit::TestCase
  
  def setup
    
  end
  
  def teardown
    
  end
  
  def test_find_all_scanrules_files
    rulesfiledir = File.dirname(File.new(File.dirname(__FILE__) + '/resources/rules/test_dir_01_multiple_unnested_files/README.txt', "r").path)
    rules_files = ScanRulesReader.find_all_scanrules_files(rulesfiledir)
    assert_equal(2, rules_files.size)
    
    rulesfiledir = File.dirname(File.new(File.dirname(__FILE__) + '/resources/rules/test_dir_02_multiple_nested_files/README.txt', "r").path)
    rules_files = ScanRulesReader.find_all_scanrules_files(rulesfiledir)
    assert_equal(3, rules_files.size)
  end
  
  def test_find_all_scanrules_files_not_a_directory
    assert_raise RuntimeError do
      rulesfiledir = File.new(File.dirname(__FILE__) + '/resources/rules/test_dir_00_valid_original/scan-rules.xml', "r").path
      ScanRulesReader.setup_project_rules(rulesfiledir, 2)
    end
  end
  
  def test_find_all_scanrules_files_in_dir_containing_backed_up_files
    rulesfiledir = File.dirname(File.new(File.dirname(__FILE__) + '/resources/rules/test_dir_08_backed_up_files/README.txt', "r").path)
    
    all_files = TestHelper.find_all_files(rulesfiledir)
    xml_files_count = 0
    all_files.each { |file| if (File.expand_path(file).include?('xml')) then xml_files_count = xml_files_count + 1 end }
    assert_equal(2, xml_files_count)
    
    rules_files = ScanRulesReader.find_all_scanrules_files(rulesfiledir)
    assert_equal(1, rules_files.size)
  end
  
  def test_get_match_rule_class_name()
    
    filename_mr = ScanRulesReader.get_match_rule_class_name("filename")
    assert_equal "FilenameMatchRule", filename_mr
    
    binary_mr = ScanRulesReader.get_match_rule_class_name("binary")
    assert_equal "BinaryMatchRule", binary_mr
    
    md5_mr = ScanRulesReader.get_match_rule_class_name("MD5")
    assert_equal "MD5MatchRule", md5_mr
    
    filename_version_mr = ScanRulesReader.get_match_rule_class_name("filenameVersion")
    assert_equal "FilenameVersionMatchRule", filename_version_mr
    
    pluggable_mr = ScanRulesReader.get_match_rule_class_name("newPluggable")
    assert_equal "NewPluggableMatchRule", pluggable_mr
    
  end
  
  def test_setup_project_rules_dir_is_empty
#    assert_raise RuntimeError do
      rulesfiledir = File.dirname(File.new(File.dirname(__FILE__) + '/resources/rules/test_dir_03_empty/README.txt', "r").path)
      ScanRulesReader.setup_project_rules(rulesfiledir, 2)
#    end

     assert(true, "This used to throw an exception, but it no longer is, because we provided a '/rules/drop_ins' directory to allow users to add new rules.  By default, this directory is empty, which is what previously caused the RuntimeError.")
  end
  
  def test_setup_project_rules_with_duplicate_project_element
    rulesfiledir = File.dirname(File.new(File.dirname(__FILE__) + '/resources/rules/test_dir_04_duplicate_project_elements/README.txt', "r").path)
    projects = ScanRulesReader.setup_project_rules(rulesfiledir, 2)
    assert projects.size > 0
  end
  
  def test_setup_project_rules_valid
    rulesfiledir = File.dirname(File.new(File.dirname(__FILE__) + '/resources/rules/test_dir_05_valid/README.txt', "r").path)
    projects = ScanRulesReader.setup_project_rules(rulesfiledir, 2)
    assert_equal(2, projects.size)
  end
  
  def test_discoverable_projects_one_scanrules_file
    rulesfiledir = File.dirname(File.new(File.dirname(__FILE__) + '/resources/rules/test_dir_00_valid_original/README.txt', "r").path)
    projects = ScanRulesReader.discoverable_projects(rulesfiledir)
    assert projects.size > 0
  end
  
  def test_discoverable_projects_multiple_scanrules_files
    rulesfiledir = File.expand_path(File.dirname(File.new(File.dirname(__FILE__) + '/resources/rules/test_dir_01_multiple_unnested_files/README.txt', "r").path))
    projects = ScanRulesReader.discoverable_projects(rulesfiledir)
    project_from_file_1 = ProjectRule.new("apache", "wild", ["windows"].to_set)
    project_from_file_2 = ProjectRule.new("junit", "wild", ["all"].to_set)
    
    assert projects.include?(project_from_file_1)
    assert projects.include?(project_from_file_2)
  end
  
  def test_validate_expressions
    rulesfiledir = File.dirname(File.new(File.dirname(__FILE__) + '/resources/rules/test_validate_dir_06_valid/scan-rules.xml', "r").path)
    projects = ScanRulesReader.setup_project_rules(rulesfiledir, 2)
    val = ScanRulesReader.validate_expressions(projects)
    assert val
  end
 
  def test_validate_expressions_eval_expression_typo
    assert_raise RuntimeError do
      rulesfiledir = File.dirname(File.new(File.dirname(__FILE__) + '/resources/rules/test_validate_dir_07_invalid/eval_expression_typo/scan-rules.xml', "r").path)
      projects = ScanRulesReader.setup_project_rules(rulesfiledir, 2)
      val = ScanRulesReader.validate_expressions(projects)
    end
  end
  
  def test_validate_expressions_eval_expression_missing
    assert_raise RuntimeError do
      rulesfiledir = File.dirname(File.new(File.dirname(__FILE__) + '/resources/rules/test_validate_dir_07_invalid/eval_expression_missing/scan-rules.xml', "r").path)
      projects = ScanRulesReader.setup_project_rules(rulesfiledir, 2)
      val = ScanRulesReader.validate_expressions(projects)
    end
  end
  
  def test_validate_expressions_result_expression_typo
    assert_raise RuntimeError do
      rulesfiledir = File.dirname(File.new(File.dirname(__FILE__) + '/resources/rules/test_validate_dir_07_invalid/result_expression_typo/scan-rules.xml', "r").path)
      projects = ScanRulesReader.setup_project_rules(rulesfiledir, 2)
      val = ScanRulesReader.validate_expressions(projects)
    end
  end
  
  def test_validate_expressions_result_expression_missing
    assert_raise RuntimeError do
      rulesfiledir = File.dirname(File.new(File.dirname(__FILE__) + '/resources/rules/test_validate_dir_07_invalid/result_expression_missing/scan-rules.xml', "r").path)
      projects = ScanRulesReader.setup_project_rules(rulesfiledir, 2)
      val = ScanRulesReader.validate_expressions(projects)
    end
  end
  
  # commented out because we decided to allow this
#  def test_validate_expressions_multiple_match_rules_with_same_name
#    assert_raise RuntimeError do
#      rulesfiledir = File.dirname(File.new(File.dirname(__FILE__) + '/resources/rules/test_validate_dir_07_invalid/multiple_match_rules_with_same_name/scan-rules.xml', "r").path)
#      projects = ScanRulesReader.setup_project_rules(rulesfiledir)
#      val = ScanRulesReader.validate_expressions(projects)
#    end
#  end

  def test_generate_aggregate_md5
    test_dir = File.expand_path(File.join(File.dirname(__FILE__), 'resources', 'aggregate_md5_resources'))
    assert(File.directory?(test_dir))
    files = ScanRulesReader.find_all_scanrules_files(test_dir).to_a.sort
    md5s = Array.new
    files.each do |f|
      file = File.new( f )
      file.binmode
      md5_val = Digest::MD5.hexdigest( file.read )
      md5s << md5_val
    end # of files.each
    
    concatted_md5_str = ""
    md5s.each do |md5|
      concatted_md5_str << md5
    end # of md5s.each
    
    expected = Digest::MD5.hexdigest(concatted_md5_str)    
    actual = ScanRulesReader.generate_aggregate_md5(test_dir)    
    assert_equal(expected, actual)
  end

  def test_get_universal_rules_version
    urv = ScanRulesReader.get_universal_rules_version
    assert(!urv.nil? && urv != "")
  end
  
end
