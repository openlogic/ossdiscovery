# filename_match_rule.rb
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
# If not, see http://www.gnu.org/licenses
#  
# You can learn more about OSSDiscovery, report bugs and get the latest versions at www.ossdiscovery.org.
# You can contact the OSS Discovery team at info@ossdiscovery.org.
# You can contact OpenLogic at info@openlogic.com.


# --------------------------------------------------------------------------------------------------
#

require 'package'
require 'search_trees'
require 'matchrules/match_rule'
require 'conf/config'

require 'set'
require 'yaml'

class FilenameListMatchRule < MatchRule
  
  # unused, but required by the framework at this point
  attr_accessor :defined_filename
  
  def initialize(name, defined_filename)
    super(name)
    @type = MatchRule::TYPE_FILENAME_LIST
    @matched_against = {}
    @defined_filename = Regexp.new(/#{defined_filename}/i)
  end
  
  def match?(actual_filepath, archive_parents)
    @match_attempts = @match_attempts + 1
    val = FilenameListMatchRule.match?(@defined_filename, actual_filepath)
    
    # match returns an array of [name, version] where name is 
    # nil if there's no match
    if val && val[0]
      (@matched_against[File.dirname(actual_filepath)] ||= Set.new) << [val, archive_parents, File.basename(actual_filepath)]
      @latest_match_val = val[1]
      return val
    end
    
    false
  end

  # we don't do versions
  def get_found_versions(location)
    @matched_against[location] || []
  end
  
  # look up path in our ternary search tree
  def FilenameListMatchRule.match?(defined_filename, actual_filepath)
    unless FilenameMatchRule.match?(defined_filename, actual_filepath.downcase)
      return false
    end
    SearchTrees.match_file_name(File.basename(actual_filepath.downcase)) || false
  end

  def FilenameListMatchRule.create(attributes)
    FilenameListMatchRule.new(attributes['name'], attributes['filename'])
  end
end
