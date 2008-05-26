# inventory_config.rb
#
# LEGAL NOTICE
# -------------
# 
# OSS Discovery is a tool that finds installed open source software.
#    Copyright (C) 2007-2008 OpenLogic, Inc.
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

class InventoryConfig
  def self.[](key)
    value = (@@configs ||= load)[key.to_s]
    if value == nil
      raise("A property does not exist for the key arg '#{key}'. Valid keys: #{@@configs.keys.inspect}")
    else
      value == "nil"?  nil : value
    end
  end
  
  def self.load
    YAML::load_file(File.join(File.dirname(__FILE__), 'inventory_config.yml'))
  end

  def self.method_missing(method)
    self[method.to_s]
  end
end
