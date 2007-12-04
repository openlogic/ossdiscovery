require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), '..', 'main', 'lib')

require 'scan_rules_updater'

require File.join(File.dirname(__FILE__), '..', 'main', 'lib', 'conf', 'config')

class TcScanRulesUpdater < Test::Unit::TestCase
  
  @@log = Config.log
  
  def setup
  end
  
  def teardown
  end
 
  
  def test_new
    sru = ScanRulesUpdater.new("http://localhost:3000/")
    assert_equal("http://localhost:3000/", sru.base_url)
    
    sru = ScanRulesUpdater.new("http://localhost:3000")
    assert_equal("http://localhost:3000/", sru.base_url)
    
    sru = ScanRulesUpdater.new(nil)
    assert_equal("http://localhost:3000/", sru.base_url)
  end
  
  def test_scrub_url_path
    scrubbed = ScanRulesUpdater.scrub_url_path("rules_files.xml")
    assert_equal("rules_files.xml", scrubbed)
    
    scrubbed = ScanRulesUpdater.scrub_url_path("/rules_files.xml")
    assert_equal("rules_files.xml", scrubbed)
  end
  
  def test_backup_scanrules_dir
    # setup
    dir_to_backup_path = File.expand_path(File.join(File.dirname(__FILE__), "dir_to_backup"))
    dir_to_backup = Dir.mkdir(dir_to_backup_path)
    assert(File.exist?(dir_to_backup_path) && File.directory?(dir_to_backup_path))
    
    # do the business
    bak_dir_extension = "_" + ScanRulesUpdater.get_YYYYMMDD_HHMM_str + ".bak"    
    backed_up_dir = ScanRulesUpdater.backup_scanrules_dir(dir_to_backup_path, bak_dir_extension)
    
    assert(!File.exist?(dir_to_backup_path))
    assert(File.exist?(backed_up_dir) && File.directory?(backed_up_dir))
    
    # tear down
    FileUtils.remove_dir(backed_up_dir, true)
    assert(!File.exist?(backed_up_dir))
  end
  
  # The first thing that should be looked at if this test ever starts failing would be to verify that this file actually exists:
  #   http://repo1.maven.org/maven2/ant/ant/maven-metadata.xml 
  # I just tried to find a file out there in the wild that I didn't think would be going anywhere any time soon.
  def test_download_file
    
    dest_dir = File.expand_path(File.dirname(__FILE__))
    
    sru = ScanRulesUpdater.new("http://repo1.maven.org/")
    sru.download_file("maven2/ant/ant/maven-metadata.xml", dest_dir)
    
    downloaded_file = File.expand_path(File.join(dest_dir, "maven-metadata.xml"))
    assert(File.exist?(downloaded_file))
    
    # teardown
    File.delete(downloaded_file)
    assert(!File.exist?(downloaded_file))
  end
  
  def test_get_default_scan_rules_dir()
    assert_equal(File.expand_path(Config.prop(:rules_openlogic)), ScanRulesUpdater.get_default_scan_rules_dir)
  end
  
  def test_rollback_update
    # setup
    backed_up_dir_path = File.expand_path(File.join(File.dirname(__FILE__), "backed_up_dir"))
    backed_up_dir = Dir.mkdir(backed_up_dir_path)
    assert(File.exist?(backed_up_dir_path) && File.directory?(backed_up_dir_path))
    
    rules_dir_path = File.expand_path(File.join(File.dirname(__FILE__), "rules_openlogic"))
    rules_dir = Dir.mkdir(rules_dir_path)
    assert(File.exist?(rules_dir_path) && File.directory?(rules_dir_path))
    
    # do the business
    ScanRulesUpdater.rollback_update(backed_up_dir_path, rules_dir_path)
    assert(!File.exist?(backed_up_dir_path))
    assert(File.exist?(backed_up_dir_path + ".failed-update") && File.directory?(backed_up_dir_path + ".failed-update"))
    assert(File.exist?(rules_dir_path) && File.directory?(rules_dir_path))
    
    # tear down
    FileUtils.remove_dir(backed_up_dir_path + ".failed-update", true)
    FileUtils.remove_dir(rules_dir_path, true)
    assert(!File.exist?(backed_up_dir_path + ".failed-update"))
    assert(!File.exist?(rules_dir_path))
  end

################################################################################
# Right now, the following two tests will not work unless a server is running on localhost.
# TODO findme: if possible, the ScanRulesUpdater code should be written in such a way that we should 
# be able to mock some of this 'download' stuff out so we can still at least write a test of the code that passes.
################################################################################
#  def test_http_get_rules_files_to_download
#    puts "********************************************************"
#    sru = ScanRulesUpdater.new("http://localhost:3000/")
#    rules_files = sru.http_get_rules_files_to_download("/rules_files.xml") # 'rules_files.xml' would've worked too
#    puts "********************************************************"
#    puts rules_files.inspect
#    puts "********************************************************"
#    assert true
#  end
  
#  def test_update_scanrules
#    sru = ScanRulesUpdater.new("http://localhost:3000/")
#    sru.update_scanrules(ScanRulesUpdater.get_default_scan_rules_dir, "/rules_files.xml")
#    assert true
#  end

#  def test_cable_yank
#    sru = ScanRulesUpdater.new("http://192.168.10.149:3000/")
#    sru.update_scanrules(ScanRulesUpdater.get_default_scan_rules_dir, "/rules_files.xml")    
#  end
  
end
