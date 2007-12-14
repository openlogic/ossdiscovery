# config.rb
#
# LEGAL NOTICE
# -------------
# 
# OSS Discovery is a tool that finds installed open source software.
#    Copyright (C) 2007 OpenLogic, Inc.
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

require 'logger'
require 'pp'
require 'yaml'

module Config
  
  @@configs_loaded = false
  
  def Config.prop(key)
    if(!@@configs_loaded) then
      Config.load
    end
    if (@@configs.has_key?(key.to_sym)) then
      return @@configs[key.to_sym]
    else
      raise "A property does not exist for the key arg '#{key}'. Valid keys: #{@@configs.keys.inspect}"
    end
  end
  
  def Config.load()
    raw_configs = YAML::load_file(File.join(File.dirname(__FILE__), 'config.yml'))
    @@configs = Hash.new
    # This binding allows us to do things like 'File.dirname(__FILE__)' and have that expression be 
    # evaluated within the context of this Config module.  See the ruby docs for more info.  It 
    # should be used as the 2nd argument to any 'eval' method call made below.
    bind_env = binding()
    raw_configs.each_pair do |key, value| 
      if (value.class == String && value == "nil") then
        @@configs[key.to_sym] = nil
      elsif (value.class == String && value.upcase == "STDOUT") then
        @@configs[key.to_sym] = STDOUT
      elsif (value.class == String && value[0..2] == "<% ") then 
        to_eval = value[3..value.length].strip
        to_eval = to_eval[0..(to_eval.length - 3)].strip
        @@configs[key.to_sym] = eval(to_eval, bind_env)
      else
        @@configs[key.to_sym] = value
      end
    end # of raw_configs.each_pair

    rules_dirs = @@configs[:rules_dirs]
    @@configs[:rules_dirs] = Array.new
    rules_dirs.each { |rd| @@configs[:rules_dirs] << @@configs[rd.to_sym] }
    
    # set up a logger and make it available by putting it in the @@configs hash
    @@configs[:log] = Logger.new(@@configs[:log_device])
    @@configs[:log].level = @@configs[:log_level]
    
    @@configs[:log].debug('Config') {"raw configuration values: #{raw_configs.inspect}"}
    @@configs[:log].debug('Config') {"configuration values: #{@@configs.inspect}"}
    @@configs_loaded = true
  end
  
  def Config.log
    if(!@@configs_loaded) then
      Config.load
    end
    return @@configs[:log]
  end
  
  def Config.configs
    if(!@@configs_loaded) then
      Config.load
    end
    return @@configs
  end
  
end