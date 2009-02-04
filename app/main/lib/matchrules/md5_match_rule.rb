# md5_match_rule.rb
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
# You can learn more about OSSDiscovery, report bugs and get the latest versions at www.ossdiscovery.org.
# You can contact the OSS Discovery team at info@ossdiscovery.org.
# You can contact OpenLogic at info@openlogic.com.


# --------------------------------------------------------------------------------------------------
#

require 'digest/md5' 
$:.unshift File.join(File.dirname(__FILE__), '..')
require 'matchrules/filename_match_rule'
require File.join(File.dirname(__FILE__), '..', 'conf', 'config')

class MD5MatchRule < FilenameMatchRule
  
  attr_reader :defined_digest, :actual_digest
  
  def initialize(name, defined_filename, defined_digest, version="")
    super(name, defined_filename)
    @type = MatchRule::TYPE_MD5
    
    @defined_digest = defined_digest
    @version = version
    
    # This is a Hash (location (a fully qualified directory) -> set of versions found in that directory)
    @matched_against = Hash.new
  end
  
  def defined_digest=(new_defined_digest)
    @defined_digest = new_defined_digest
  end
  
=begin rdoc
  The 'actual_filepath_digest' is an optional argument intended to be used to 
  improve performance of the application.  This method will work fine without it, 
  and simply calculate the digest using 'Digest::MD5.hexdigest'.  If you choose 
  to pass this value in, it means that the digest has already been calculated 
  (probably prior to the particular method call in a loop) and you simply want 
  to compare the 'defined_digest' for this class with the 'actual_filepath_digest' 
  argument, since this is a cheaper operation than actually computing it.
=end  
  def match?(actual_filepath, actual_filepath_digest, archive_parents)
    @match_attempts = @match_attempts + 1
    match_val, digest = MD5MatchRule.match?(@defined_filename, @defined_digest, actual_filepath, actual_filepath_digest)
    
    if match_val
      @matched_against[File.dirname(actual_filepath)] = [[@version, archive_parents, File.basename(actual_filepath)]]
      @latest_match_val = @version
    end
    
    [match_val, digest]
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
  
  def MD5MatchRule.create(attributes)
    mmr = MD5MatchRule.new(attributes["name"], attributes["filename"], attributes["md5sum"], attributes["version"])
    return mmr
  end
  
  def MD5MatchRule.match?(defined_filename, defined_digest, actual_filepath, actual_digest)
    unless FilenameMatchRule.match?(defined_filename, actual_filepath)
      return [false, actual_digest]
    end

    digest = actual_digest || MD5MatchRule.get_digest_for(actual_filepath)

    [defined_digest == digest, digest]
  end
  
  def MD5MatchRule.get_digest_for(filepath)
    file = File.new( filepath )
    file.binmode
    digest = Digest::MD5.hexdigest( file.read )
    file.close
    return digest
  end
    
end
