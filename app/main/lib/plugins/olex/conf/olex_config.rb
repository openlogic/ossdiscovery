# olex_config.rb
#
# LEGAL NOTICE
# -------------
# 
# OSS Discovery is a tool that finds installed open source software.
#    Copyright (C) 2007-2009 OpenLogic, Inc.
#  
# OSS Discovery is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License version 3 as 
# published by the Free Software Foundation.  
#  
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License version 3 (discovery2-client/license/OSSDiscoveryLicense.txt) 
# for more details.
#  
# You should have received a copy of the GNU Affero General Public License along with this program.  
# If not, see http://www.gnu.org/licenses/
#  
# You can learn more about OSSDiscovery or contact the team at www.ossdiscovery.com.
# You can contact OpenLogic at info@openlogic.com.
#
#--------------------------------------------------------------------------------------------------

require 'yaml'
require 'utils'

class OlexConfig
  def self.[](key)
    value = (@@configs ||= load)[key.to_s]
    if value == nil
      raise("A property does not exist for the key arg '#{key}'. Valid keys: #{@@configs.keys.inspect}")
    else
      value == "nil"?  nil : value
    end
  end
  
  def self.load
    #@@configs = YAML::load_file(File.join(File.dirname(__FILE__), 'olex_config.yml'))
    @@configs = YAML::load(Utils.load_openlogic_olex_plugin_config_file('olex_config.yml'))

    override_discovery_defaults
    @@configs
  end

  # necessary to point at the OLEX production server instead of the
  # OSS Census production server
  def self.override_discovery_defaults
    Config.configs[:server_base_url] = @@configs["server_base_url"]
    Config.configs[:rules_file_base_url] = @@configs["rules_file_base_url"]
    Config.configs[:update_rules] = @@configs["update_rules"]
    Config.configs[:update_rules_and_do_scan] = @@configs["update_rules_and_do_scan"]
  end

  def self.method_missing(method)
    self[method.to_s]
  end
end
