# rule_analyzer.rb
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
# You can learn more about OSSDiscovery, report bugs and get the latest versions at www.ossdiscovery.org.
# You can contact the OSS Discovery team at info@ossdiscovery.org.
# You can contact OpenLogic at info@openlogic.com.


# --------------------------------------------------------------------------------------------------
#

require 'set'

require 'package'

=begin rdoc
  This is the class that is responsible for taking lists of raw ProjectRule 
  hierarchies (... -> MatchRuleSet -> MatchRule) and crunching through all of 
  the state held in these granular object hierarchies, in order to produce more 
  meaningful, reportable information.
=end
class RuleAnalyzer
  
  def RuleAnalyzer.analyze_matches(project_rules)
    # Some comments regarding the allpackages Set
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
    # All unneccesary 'unkown' version identifications will have been removed with the context of one 
    # 'project-rule' definition above.  But we could still have something like the following:
    #
    # <project-rule for 'spring' defined in rules-file-A.xml
    # <project-rule for 'spring' defined in rules-file-B.xml
    #
    # The rule from file A identified spring version 'unknown' installed in location X.
    # The rule from file B identified spring version '2.0' installed in location X as well.
    #
    # We only want to report version 2.0 as installed.
    allpackages = Set.new
    project_rules.each do | project_rule |
      packages_for_project = Package.make_packages_with_bad_unknowns_removed(allpackages_with_unknowns, project_rule)
      allpackages.merge( packages_for_project )
      
      if ( $DEBUG )
        printf("project has %d packages in it\n", packages_for_project.length )
        printf("project %s, all packages length: %d\n", project_rule.name, allpackages.length )
      end
    end # of project_rules.each
    
    return allpackages
  end
end