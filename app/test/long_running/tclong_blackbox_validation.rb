# ruby requires
require 'test/unit'

# main source tree requires
$:.unshift File.join(File.dirname(__FILE__), '..', '..', 'main', 'lib')
require 'conf/config'

class TclongBlackboxValidation < Test::Unit::TestCase
  
  @@log = Config.log
  
  DIR_TO_DISCOVER = File.expand_path(File.join(File.dirname(__FILE__), '..', 'resources')) unless defined? DIR_TO_DISCOVER
  DISCOVERY_RB = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'main', 'lib', 'discovery.rb')) unless defined? DISCOVERY_RB
  
  def setup
    @results_file = File.expand_path(File.join(File.dirname(__FILE__), "#{ScanRulesUpdater.get_YYYYMMDD_HHMM_str}_scan_results.txt"))
    @baseline_file = File.expand_path(File.join(File.dirname(__FILE__), '..', 'resources', 'blackbox_validation_baseline_scan_results.txt'))
  end
  
  def teardown
    if (File.exist?(@results_file)) then
      File.delete(@results_file)
    end
  end

  def test_discovery
    t1 = Time.new
    @@log.info('TclongBlackboxValidation') {"Performing a default scan... #{t1}"}
    cmd = "ruby #{DISCOVERY_RB} --path #{DIR_TO_DISCOVER} --machine-results #{@results_file}"
    output = `#{cmd}`
    t2 = Time.new
    @@log.info('TclongBlackboxValidation') {"It took '#{(t2-t1).to_s}' seconds to run the default scan."}
    
    assert(!output.include?('Unsupported option'), "There was a problem with the command (#{cmd}), because the help text was returned.")    
    assert(!output.include?('decoy'), "The test was testing that content that should not be discovered (content living somewhere underneath a 'decoy' directory) is actually NOT being discovered.  Some of the 'decoy' stuff must've been discovered.")
    
    #####
    # Asserting that the portions of the baseline results file and the results file created from 
    # performing the above discovery run that should be the same are the same.
    #####
    lines_test_file = Array.new
    start_adding_lines = false
    File.open(@results_file) do |test_file|
      while line = test_file.gets
        if (start_adding_lines) then
          lines_test_file << line
        elsif (line.include?("package,version"))
          start_adding_lines = true
          next
        end
      end # of while
    end # of File.open
    
    lines_baseline_file = Array.new
    start_adding_lines = false
    File.open(@baseline_file) do |test_file|
      while line = test_file.gets
        if (start_adding_lines) then
          lines_baseline_file << line
        elsif (line.include?("package,version"))
          start_adding_lines = true
          next
        end
      end # of while
    end # of File.open
    
    lines_test_file.sort!
    lines_baseline_file.sort!
    0.upto(lines_baseline_file.size - 1) do |i|
      assert_equal(lines_baseline_file[i], lines_test_file[i])
    end # of 0.upto
    
    #####
    # Testing that throttling is working (doing this here so we don't have to 
    # take the time to do another full discovery run elsewhere)    
    #####
    
    # This value can be one of two things:
    #   1) disabled (total seconds paused: 0)
    #   or
    #   2) enabled (total seconds paused: X)
    disabled_str = 'disabled'
    throttling_val_default = output.match(/^throttling\s+:\s+(.*)$/)[1]
    if (throttling_val_default[0..(disabled_str.size - 1)] != disabled_str) then
      fail("Throttling should be disabled by default.")
    else
      throttling_time_default = throttling_val_default.match(/^disabled\s+\(total seconds paused:\s+(.*)\)$/)[1]
      assert_equal(0, throttling_time_default.to_i, "When throttling is disabled (it is by default), then the scan should not have paused at all (zero seconds). Instead, the scan paused for '#{throttling_time_default}' seconds.")
    end
    
    t11 = Time.new
    @@log.info('TclongBlackboxValidation') {"Performing a throttled scan... #{t1}"}
    cmd = "ruby #{DISCOVERY_RB} --path #{DIR_TO_DISCOVER} --throttle"
    output = `#{cmd}`
    t22 = Time.new
    @@log.info('TclongBlackboxValidation') {"It took '#{(t22-t11).to_s}' seconds to run the throttled scan."}
    
    enabled_str = 'enabled'
    throttling_val_throttled = output.match(/^throttling\s+:\s+(.*)$/)[1]
    if (throttling_val_throttled[0..(enabled_str.size - 1)] != enabled_str) then
      fail("Throttling should've been disabled since the '--throttle' cli option was passed in.")
    else
      throttling_time_throttled = throttling_val_throttled.match(/^enabled\s+\(total seconds paused:\s+(.*)\)$/)[1]
      assert(throttling_time_throttled.to_f > 0, "When throttling is enabled, then the scan should not have paused for some amount of time greater than zero seconds. The pause time reported was '#{throttling_time_throttled}'.")
    end
    
  end
  
end
