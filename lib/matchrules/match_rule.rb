# match_rule.rb
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
# You can learn more about OSSDiscovery, report bugs and get the latest versions at www.ossdiscovery.org.
# You can contact the OSS Discovery team at info@ossdiscovery.org.
# You can contact OpenLogic at info@openlogic.com.


# --------------------------------------------------------------------------------------------------
#


=begin rdoc
  All real MatchRule implementations will extend this class, as this class 
  itself is nearly worthless.  As of now, there are only a few hard rules for 
  MatchRule implementations, they must respond to the following method calls:
  
  1) create(attributes) - Factory method that accepts an 'attributes' Hash 
     (attribute_name -> attribute_value) so that it can set up it's own state 
     and returns and instance of itself.
  2) match?(arg) - The arg will most commonly be a fully qualified filename. 
     It is conceivable that a MatchRule implementation not need an actual file 
     on the file system to do a match (an example case is determining the OS 
     with a command like 'uname -a')- returns [true|false] based on internal state.

  As to the 'worthlessness' of this class.  You'll notice that neither 
  'create(attributes)' or 'match?' are defined as part of it; that's intentional.  
  An error ought to be thrown if you try to call either one of those methods on 
  this class.  Consider this a way of organizing MatchRule implementations, in 
  lieu of the fact that Ruby doesn't have abstract classes or interfaces.  At 
  the very least, this class serves as the single place to put the rdoc for 
  common MatchRule methods.

  Instance variables:
    match_attempts - a count of the number of times 'match?' was called
=end
class MatchRule
  
  TYPE_FILENAME         = 1 unless defined?(TYPE_FILENAME)
  TYPE_MD5              = 2 unless defined?(TYPE_MD5)
  TYPE_BINARY           = 3 unless defined?(TYPE_BINARY)
  TYPE_FILENAME_VERSION = 4 unless defined?(TYPE_FILENAME_VERSION)
  
  attr_accessor :name, :type
  attr_reader :matched_against, :version, :match_attempts
  
  def initialize(name)
    @name = name
    @match_attempts = 0
    @version = ""
  end
  
=begin rdoc
  Returns true if this match_rule has ever matched against anything; returns 
  false if it hasn't.  If it has ever matched against anything, you can get a 
  hold of a unique list of the things it has matched against by using the 
  'matched_against' accessor.  The objects in this list will most likely be 
  Strings (fully qualified file names in most cases).
=end 
  def matched_anything?
    val = nil
    if (@matched_against.size == 0) then
      val = false
    else
      val = true
    end
    return val
  end
  
=begin rdoc
  the last value (version) that came out of a successful (true) match? call
=end   
  def get_latest_matchval()
    return @latest_match_val
  end

end
