# filename_match_rule.rb
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
# If not, see http://www.gnu.org/licenses
#  
# You can learn more about OSSDiscovery, report bugs and get the latest versions at www.ossdiscovery.org.
# You can contact the OSS Discovery team at info@ossdiscovery.org.
# You can contact OpenLogic at info@openlogic.com.


# --------------------------------------------------------------------------------------------------
#

$:.unshift File.join(File.dirname(__FILE__), '..')
require 'package'
require 'matchrules/match_rule'
require File.join(File.dirname(__FILE__), '..', 'conf', 'config')

require 'set'

class FilenameMatchRule < MatchRule
  
  # Considered moving 'defined_filename' up into MatchRule. Seems right to leave 
  # it here for the time being.  An example of a kind of MatchRule that would not 
  # use an actual file in its matching algorithm would be one that runs some kind 
  # of system command (eg... uname -a).  We wouldn't want to force that kind of 
  # MatchRule to inherit a 'defined_filename' attribute.
  attr_accessor :defined_filename
  
  def initialize(name, defined_filename)
    super(name)
    @type = MatchRule::TYPE_FILENAME
    @defined_filename = Regexp.new(/#{defined_filename}/i)
    
    # To understand what this is, see the comments in the 'match?' method.
    @matched_against = Hash.new
  end
  
  def match?(actual_filepath, archive_parents)
    @match_attempts = @match_attempts + 1
    val = FilenameMatchRule.match?(@defined_filename, actual_filepath)
    
    if (val) then
      if (@version == nil || @version == "")
        @latest_match_val = Package::VERSION_UNKNOWN
      else
        @latest_match_val = @version
      end
      @matched_against[File.dirname(actual_filepath)] = [[@latest_match_val, archive_parents, File.basename(actual_filepath)]]
    end
    
    return val
  end

  
=begin rdoc
  Returns a Set of versions (strings) that were found as the result of 
  previously running matches over a set of files with this MatchRule.

  For this particular rule type, the Set returned will have at most 1 version in 
  it. The method is 'get_found_versions' instead of 'get_found_version' because 
  other types of MatchRules could validly return multiple versions for the same 
  directory, and we want all MatchRules to walk and talk like each in this respect.
=end   
  def get_found_versions(location)
    @matched_against[location] || []
  end
  
  # This method tries to do a regexp match every single time, no simple String comparison is performed.
  # This means that if given a defined_filename arg of 'foo' and an 
  # actual_filepath arg of '/usr/local/fee_foo', this method will return true. 
  # Seems reasonable (rather than a straight string comparison) because it errors on the 
  # side of being more inclusive than exclusive.
  def FilenameMatchRule.match?(defined_filename, actual_filepath)
    val = false
    
    basename = File.basename(actual_filepath)
    match_val = basename.match(defined_filename)
    if (match_val != nil) then
      val = match_val
    end
    return val
  end

  def FilenameMatchRule.create(attributes)
    fmr = FilenameMatchRule.new(attributes['name'], attributes['filename'])
    if (attributes['version'] != nil) then 
      fmr.version = attributes['version']
    end
    return fmr
  end
end
