# rule_analyzer.rb
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
require 'cliutils'

=begin rdoc
  This is the class that is responsible for taking lists of raw ProjectRule 
  hierarchies (... -> MatchRuleSet -> MatchRule) and crunching through all of 
  the state held in these granular object hierarchies, in order to produce more 
  meaningful, reportable information.
=end
class RuleAnalyzer

=begin rdoc
  The intended caller of this method is the RuleEngine.  This method is to be called when the scan 
  of all files of interest has been completed.  At this time, all MatchRule states (reachable by 
  navigating down in the ProjectRule hierarchy) will have been built up, so that this method can 
  evaluate them (or pass certain evaluation responsibilities off to other classes).  The end result 
  of calling this method is that it returns an aggregated, readable list of Package objects that can 
  be used to report the actual information a user of this tool would care about... namely what do I 
  have installed and where is it installed.
=end
  def self.aggregate_matches(project_rules)
    # Some comments regarding the allpackages_with_unknowns Set
    # This Enumerable is a Set because we need to ensure that the contents of it (all found packages) are unique.
    # You may be thinking now, how would they ever not be unique?  Glad you asked... here's an example:
    # - I have one handwritten dom4j rule, and one dom4j rule that was generated based off of a maven repo.
    # - Both rules are capable of determining that dom4j version X is installed in location Y.
    # - Well, if two different rules both tell me that, then it's non-sensical to report dom4j 
    #   version X as being installed in location Y twice.  In order to prevent this... aka, in 
    #   order for it to report that dom4j version X is installed in location Y only once, the 'eql?' and 'hash'
    #   methods have been implemented for the Package class, and we merge subsequent project results 
    #   into a ever-growing Set (remember that a Set holds no duplicates, which is exactly what we have 
    #   as part of the multiple scan rule scenario described above).
    allpackages_with_unknowns = Set.new
    project_rules.each do | project_rule |
      packages_for_project = project_rule.build_packages()
      allpackages_with_unknowns.merge( packages_for_project )
    end # of project_rules.each
    
    # We have to go through a similar step here since we allow multiple 'project-rule' definitions.  
    # All unneccesary 'unkown' version identifications will have been removed within the context of one 
    # 'project-rule' definition above (specifically, this occurs in the bowels of the 'build_packages' method).  
    # But we could still have something like the following:
    #
    # <project-rule for 'spring' defined in rules-file-A.xml
    # <project-rule for 'spring' defined in rules-file-B.xml
    #
    # The rule from file A identified spring version 'unknown' installed in location X.
    # The rule from file B identified spring version '2.0' installed in location X as well.
    #
    # We only want to report version 2.0 as installed.
    allpackages = Package.make_packages_with_bad_unknowns_removed(allpackages_with_unknowns)
    
    allpackages = self.remove_our_dogfood(allpackages)
    return allpackages
  end
  
  def self.remove_our_dogfood(allpackages)    
    return nil if allpackages.nil?    
    app_home = normalize_dir(ENV['OSSDISCOVERY_HOME'])
    
    running_on_windows = false
    if (major_platform.include?('windows')) then # major_platform lives in cliutils
      app_home.downcase!
      running_on_windows = true
    end    
    
    # normalize_dir lives in cliutils
    allpackages.delete_if do |pkg|
      if (running_on_windows) then
        normalize_dir(pkg.found_at).downcase.include?(app_home)
      else
        normalize_dir(pkg.found_at).include?(app_home)
      end
    end
    
    return allpackages
  end
  
  def self.analyze_audit_records(records)
    file_to_versions_list = Hash.new
    records.each do |r|
      if (file_to_versions_list.has_key?(r.foi_that_matched)) then
        if (r.version != 'unknown') then
          file_to_versions_list[r.foi_that_matched] = file_to_versions_list[r.foi_that_matched] << r.version
        end
      else
        if (r.version != 'unknown') then
          file_to_versions_list[r.foi_that_matched] = Set.new << r.version
        end
      end
    end # of records.each 
    
    file_to_multiple_versions = Hash.new
    file_to_versions_list.each_pair do |key, val|
      if (val.size > 1) then
        file_to_multiple_versions[key] = val
      end
    end # of file_to_versions_list.each_pair
    
    return file_to_multiple_versions
  end
  
end
