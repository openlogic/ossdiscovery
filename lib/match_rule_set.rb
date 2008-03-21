# match_rule_set.rb
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
require 'expression'

class MatchRuleSet
  
  attr_accessor :name, :match_rules, :result_expression, :is_result_expression_or_all
  attr_reader :locations
  
  def initialize(name)
    @name = name
    @match_rules = Set.new
    @is_result_expression_or_all = false
  end
  
  def result_expression=(re)
    @result_expression = re
    @result_expression.gsub!(" or ", " OR ")
    @result_expression.gsub!(" and ", " AND ")
    @result_expression.gsub!(" not ", " NOT ")
  end

=begin rdoc
  Returns a Set of locations (directories) this ruleset evaluates to true for.
=end 
  def evaluate()
    locations = get_ruleset_match_locations
    
    results = Set.new
    if (locations == nil || locations.size == 0) then 
      return results
    end
    
    locations.each { |location, match_rule_hash| 
      name_value_pairs = Hash.new
      match_rule_hash.each { |mr, boolean_val|
        name_value_pairs[mr.name] = boolean_val
      }
      e = BooleanExpression.new
      if (@result_expression == nil || @result_expression == "" || @result_expression == BooleanExpression::AND_ALL) then
        @result_expression = BooleanExpression.get_and_all_expr(name_value_pairs.keys)
      elsif (@result_expression == BooleanExpression::OR_ALL) then
        @result_expression = BooleanExpression.get_or_all_expr(name_value_pairs.keys)
      end
      val = e.evaluate(@result_expression, name_value_pairs)
      if (val) then
        results << location
      end
    }
    
    return results
  end
  
=begin rdoc
  Returns a Hash.  Here's an example:

  Given the follwing

  1) a ruleset defined like this:

    <ruleset name="executables">
      <result>httpd AND apxs AND htpasswd</result>
      <matchrule name="httpd" type="filename" filename="httpd" />
      <matchrule name="apxs" type="filename" filename="apxs" />
      <matchrule name="htpasswd" type="filename" filename="htpasswd" />
    </ruleset>

  2) The matchrule elements for that ruleset all being matched to the locations '/home/me' and 'away/me' for all filenames.  

  -----

  The return value will be a Hash like this (the result of Ruby's inspect method, with a little formatting added):
       KEYS         VALUES (another Hash, whose keys are a MatchRule, and values are a boolean telling you whether or not it matched)
    {
      "/home/me"=>{MatchRule_a=>true, MatchRule_b=>true, MatchRule_c=>true}, 
      "/away/me"=>{MatchRule_a=>true, MatchRule_b=>true, MatchRule_c=>true}
    }

=end  
  def get_ruleset_match_locations
    
    # Hash (match_rule -> matched_against)
    match_rules_hash = Hash.new

    most_matched_hash = Hash.new
    
    @match_rules.each { |mr|
      match_rules_hash[mr] = mr.matched_against
      most_matched_hash = most_matched_hash.merge(mr.matched_against)
    }
    
    # Setting up an Array of 'most_matched_dirs'. This is simply the keys from the 'most_matched_hash'
    most_matched_dirs = Array.new
    most_matched_hash.each_key { |dirs|
      most_matched_dirs << dirs
    }
    
    match_rules_keys = match_rules_hash.keys
    
    # 'location_to_defined_filename_outcome' is what will be returned by this method
    location_to_defined_filename_outcome = Hash.new
    0.upto(most_matched_dirs.size - 1) { |i|
      defined_filename_outcome = Hash.new
      match_rules_keys.each { |match_rules_key|
        val = match_rules_hash[match_rules_key].keys.include?(most_matched_dirs[i])
        defined_filename_outcome[match_rules_key] = val
      }
      location_to_defined_filename_outcome[most_matched_dirs[i]] = defined_filename_outcome
    }
    
    return location_to_defined_filename_outcome
  end
  
end