# project_rule.rb
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
require 'set'

require 'package'
require File.join(File.dirname(__FILE__), 'conf', 'config')

class ProjectRule
  attr_accessor :name, :from, :operating_systems, :rulesets, :eval_rule, :desc
  
  def initialize(name, from="wild", operating_systems=Set["all"]) 
    @name = name
    @from = from
    if operating_systems
      @operating_systems = operating_systems.to_set
    else 
      @operating_systems = nil
    end
    
    @rulesets = Set.new
    @eval_rules = Set.new
    @desc = "not yet defined"
  end
  
  def eql?(other)
    if ((self.==(other)) && (self.class == other.class))
      return true
    else
      return false
    end
  end
  
  def ==(other)
    val = false
    if ((other.name == @name) && 
        (other.from == @from) &&
        (other.operating_systems == @operating_systems))
      val = true
    end
    val
  end
  
  def hash
    val = 17
    val += 37 * @name.hash
    val += 37 * @from.hash
    @operating_systems.each {|os| val += 37 * os.hash}
    
    val
  end

=begin rdoc
  Returns a Set of Package objects.  These Package objects are the resulting 
  aggregation of the state of all MatchRule instances underneath this object in 
  it's hierarchy.
=end
  def build_packages
    locations = evaluate
    results = Package.create_instances(locations, self)
  end

=begin rdoc
  Returns a set of locations (directories) this Project's EvalRule evaluates to true for.
=end
  def evaluate
    
    location_to_rulesets_outcome_hash = get_location_to_rulesets_hash
    
    results = Set.new
    
    if (location_to_rulesets_outcome_hash == nil || location_to_rulesets_outcome_hash.size == 0)
      return results
    end
    
    location_to_rulesets_outcome_hash.each { |location, ruleset_hash| 
      name_value_pairs = Hash.new
      ruleset_hash.each { |rs_name, boolean_val|
        name_value_pairs[rs_name] = boolean_val
      }
      e = BooleanExpression.new
      val = e.evaluate(@eval_rule.expression, name_value_pairs)
      if val
        results << location
      end
    }
    
    return results;

  end

=begin rdoc
  Returns a Hash: (key = directory location) => (value = another Hash where the key = ruleset name and the value is [true|false])
=end 
  def get_location_to_rulesets_hash
    all_possible_locations = Set.new
    
    # (key = ruleset name) => (value = Set of locations that evaluated to true for the ruleset)    
    ruleset_to_locations = Hash.new
    
    @rulesets.each { |ruleset|
      locs = ruleset.evaluate
      all_possible_locations.merge(locs)
      ruleset_to_locations[ruleset.name] = locs
    }
    
    # the Hash that will be returned
    location_to_rulesets = Hash.new
    
    all_possible_locations.each { |location|
      ruleset_names = Set.new
      ruleset_to_locations.each { |ruleset, location_set|
        if (location_set.include?(location))
          ruleset_names << ruleset
        end
      }
      location_to_rulesets[location] = ruleset_names
    }
    
    location_to_rulesets_outcome_hash = Hash.new
    
    location_to_rulesets.each { |location, true_rulesets| 
    
      if (true_rulesets == nil || true_rulesets.size == 0)
        @rulesets.each { |rs|
          location_to_rulesets_outcome_hash[location] =  Hash[rs.name => false]
        }
      else
        rsname_to_boolean_hash = Hash.new
        @rulesets.each { |rs|
          if (true_rulesets.include?(rs.name))
            rsname_to_boolean_hash[rs.name] = true
          else
            rsname_to_boolean_hash[rs.name] = false
          end
        }
        location_to_rulesets_outcome_hash[location] =  rsname_to_boolean_hash
      end
    }
    
    return location_to_rulesets_outcome_hash
  end
  
end