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

$:.unshift File.join(File.dirname(__FILE__), '..')
require 'package'
require 'ternary_search_tree'
require 'matchrules/match_rule'
require File.join(File.dirname(__FILE__), '..', 'conf', 'config')

require 'set'

class FilenameListMatchRule < MatchRule
  
  # unused, but required by the framework at this point
  attr_accessor :defined_filename
  
  def initialize(name, defined_filename, project_file)
    super(name)
    @type = MatchRule::TYPE_FILENAME_LIST
    @matched_against = {}
    @defined_filename = defined_filename

    # should only be one of these, so make a class variable
    @@tst = TernarySearchTree.new
    @@tst.seed_tree

    tst_file = File.expand_path(File.join(
          File.dirname(__FILE__), '..', 'rules', 'openlogic', project_file))

    start = Time.now
    puts "Loading name-based rules"
    @@tst.load_from_file(tst_file)
    puts "done loading rules in #{Time.now - start} seconds."
  end
  
  def match?(actual_filepath, archive_parents)
    @match_attempts = @match_attempts + 1
    val = FilenameListMatchRule.match?(@defined_filename, actual_filepath)
    
    # match returns an array of [name, version] where name is 
    # nil if there's no match
    if val && val[0]
      (@matched_against[File.dirname(actual_filepath)] ||= Set.new) << [val, archive_parents, File.basename(actual_filepath)]
      @latest_match_val = val[1]
      return true
    end
    
    false
  end

  # we don't do versions
  def get_found_versions(location)
    @matched_against[location] || []
  end
  
  # look up path in our ternary search tree
  def FilenameListMatchRule.match?(defined_filename, actual_filepath)
    unless FilenameMatchRule.match?(defined_filename, actual_filepath)
      return false
    end
    @@tst.match(File.basename(actual_filepath)) || false
  end

  def FilenameListMatchRule.create(attributes)
    FilenameListMatchRule.new(attributes['name'], attributes['filename'], attributes['projectfile'])
  end
end
