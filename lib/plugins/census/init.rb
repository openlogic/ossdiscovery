$:.unshift File.dirname(__FILE__)
require 'conf/census_config'
enabled = CensusConfig.census_enabled
require 'census_utils' if enabled
puts "  Census plugin loaded.  Census enabled: #{enabled}"

CENSUS_PLUGIN_VERSION = "1.0"
CENSUS_PLUGIN_VERSION_KEY = "29the23special46secret31".to_i(36).to_s(16)
