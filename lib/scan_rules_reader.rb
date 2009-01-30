# scan_rules_reader.rb
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

#
# The class responsible for reading scan rules (project-rules) out of the xml 
# files that they are contained in.
#

require 'set'
require 'find'
require 'rexml/document'
include REXML

# from internal source
require 'eval_rule'
require 'expression'
require 'project_rule'
require 'match_rule_set'
require 'matchrules/binary_match_rule'
require 'matchrules/filename_match_rule'
require 'matchrules/filename_list_match_rule'
require 'matchrules/filename_version_match_rule'
require 'matchrules/md5_match_rule'

require File.join(File.dirname(__FILE__), 'conf', 'config')

class ScanRulesReader
  
  @@log = Config.log

  ERROR_NO_UNIVERSAL_VERSION_VALUES_SET = "NO_UNIVERSAL_VERSION_VALUES_SET" unless defined? ERROR_NO_UNIVERSAL_VERSION_VALUES_SET
  ERROR_MULTIPLE_UNIQUE_UNIVERSAL_VERSIONS = "MULTIPLE_UNIQUE_UNIVERSAL_VERSIONS" unless defined? ERROR_MULTIPLE_UNIQUE_UNIVERSAL_VERSIONS
  
=begin rdoc
  This method turns stuff from a scanrules xml file into ProjectRule objects (with their 
  underlying hierarchy).  If it was decided that xml was not the way to go, or if 
  additional data formats (eg... yml) should be supported for scan rules representation, 
  then this would be the place to start thinking about breaking that out.
  
  Only add eval rulesets and their match rules if the speed factor for the evaluation rule matches.
  A project's eval rules specify a speed for each eval rule type.  If that speed matches the current speed
  then that eval rule should be activated.  The eval rule describes the expression in terms of the
  rule sets that apply at that speed factor, so we can derive what rulesets we need to pull in.

  Returns a Set of ProjectRule objects
=end
  def ScanRulesReader.setup_project_rules(scan_rules_dirs, speed=1)
    projects = Array.new
    
    scan_rules_dirs.each do |scan_rules_dir|
      
      rules_files = ScanRulesReader.find_all_scanrules_files(scan_rules_dir)
      if (rules_files == nil || rules_files.size == 0) then 
        @@log.warn("ScanRulesReader") { "No scan rules xml files found in directory: '#{scan_rules_dir}'" }
        next
      end
        
      rules_files.each do |filepath| 
        @@log.info("ScanRulesReader") { "Reading rules file: '#{filepath}'" }
        
        file = File.new(filepath)
        xml = Document.new(file)
        root = xml.root
       
        # spin through all the projects in the scan rules file
        root.elements.each do |xproject| 
          
          project = ProjectRule.new(xproject.attributes["name"], 
                                xproject.attributes["from"], 
                                xproject.attributes["os"].split(",").to_set)
    
          # next, dig out project's eval expression for the ruleset evaluation
          #     <eval rule="executables AND versionstring" speed="2" value="100" />
          #
          # from this example, the rulesets of interest for speed level 2 would be 'executables' and 'versionstring'
          evalrulesets = nil
          xproject.elements.each("eval") { | xeval | 
            # look for an eval that matches the given speed hint. speed must be a numeric, so if it's not already, make it one
            if ( xeval.attributes["speed"].to_i <= speed.to_i )
    
              # this eval rule should be activated because it's defined for this speed.
              # to activate it, add it to the project's eval rules.
              # each project should have one eval rule per speed factor
              
              evalrule = EvalRule.new( xeval.attributes["expression"],  xeval.attributes["speed"] )
              project.eval_rule = evalrule
              
              # get a list of rule set names that the project needs for this speed level
              # these names are derived from the EvalRule's expression
              # so, this array will just be something like "executables", "versionstring" - ruleset names
              
              evalrulesets = project.eval_rule.get_rule_names()
              
              projects << project
              break  # right now there should be only one eval per speed factor per project, so break out of this after speed matched
            end           
          }
           
          # now we should have the active rulesets for this speed factor, pull just those from the scan rules for this project and 
          # activate them by adding them into the project's set of rulesets
          
          if ( evalrulesets != nil && !evalrulesets.empty? )
            
            # we have the ruleset names derived from the eval statement; need to add just those rulesets to the project
            
            xproject.elements.each("match-rules") { | xruleset |
    
              ruleset_name = xruleset.attributes["name"]
    
              if ( evalrulesets.include?(ruleset_name) )
                            
                ruleset = MatchRuleSet.new( ruleset_name )
                project.rulesets << ruleset
    
                if (xruleset.elements["result"] != nil) then
                  ruleset.result_expression = xruleset.elements["result"].attributes["expression"]
                end
    
                # add all the match rules for this ruleset into the ruleset match_rules container
                # this initializes the ruleset with the atomic match rules needed
                
                xruleset.elements.each("match-rule") { |xmatchrule|
                  ruletype = xmatchrule.attributes["type"]
                  xmatchrule_attrs = Hash.new
                  xmatchrule.attributes.each { |name, value| xmatchrule_attrs[name] = value }
                  match_rule = create_match_rule(xmatchrule_attrs)
                  ruleset.match_rules << match_rule
                }
                
                if (ruleset.result_expression == nil || ruleset.result_expression == "" || ruleset.result_expression == BooleanExpression::AND_ALL) then
                  names = Array.new
                  ruleset.match_rules.each { |mr|
                    names << mr.name
                  }
                  ruleset.result_expression = BooleanExpression.get_and_all_expr(names)
                elsif (ruleset.result_expression == BooleanExpression::OR_ALL)
                  names = Array.new
                  ruleset.is_result_expression_or_all = true
                  ruleset.match_rules.each { |mr|
                    names << mr.name
                  }
                  ruleset.result_expression = BooleanExpression.get_or_all_expr(names)
                else
                  if (BooleanExpression.is_verbose_or_all(ruleset.result_expression)) then
                    ruleset.is_result_expression_or_all = true
                  end
                end
              end
    
            }  # each xruleset
            
          else
            # TODO - in the case where an eval rule is not supplied in the scan rules file, either decide to throw an error or 
            # default AND all rule set results - just need to decide.  For now, warn of this condition
            @@log.warn("ScanRulesReader") {"Warning: No eval expression was found for project '#{xproject.attributes["name"]}', speed #{speed}"}
          end
    
        end # of root.elements.each
        
      end # of rules_file.each
      
    end # of scan_rules_dirs.each
      
    ScanRulesReader.validate_expressions(projects)
    
    return projects
  end
  
=begin rdoc
  Ensures that for all boolean expressions, an operand for that expression actually exists.

  Returns true if everything is OK, throws a RuntimeError if there's a problem.
  In other words, this is enough of an issue to prevent a discovery run from happening.
=end    
  def ScanRulesReader.validate_expressions(projects)
    # validate the expression for the project
    projects.each do |project|
      operands = BooleanExpression.get_operands(project.eval_rule.expression)
      all_operands_defined_as_rulesets = false
      
      rs_names = Array.new # The operands in the boolean expression
      
      project.rulesets.each do |rs|
        rs_names << rs.name
        operands.delete(rs.name)
      end # of project.rulesets.each
      
      rs_names_copy = Array.new
      rs_names.each do |name|
        if (rs_names_copy.include?(name)) then
          raise "Invalid scan rule declaration for project '#{project.name}'. Duplicate ruleset name of '#{name}'."
        end
        rs_names_copy << name
      end # of rs_name.each
      
      if (operands.size > 0) then
        raise "Invalid scan rule declaration for project '#{project.name}'. Did not have a ruleset for each operand in the eval expression '#{project.eval_rule.expression}'."
      end
    end # of projects.each
    
    # validate the expressions for the rulesets that are part of the project
    projects.each do |project|
      project.rulesets.each do |rs|
        operands = BooleanExpression.get_operands(rs.result_expression)
        mr_names = Array.new # The operands in the boolean expression
        rs.match_rules.each do |mr|
          mr_names << mr.name
          operands.delete(mr.name)
        end # of rs.match_rules.each
        
        mr_names_copy = Array.new
        mr_names.each do |name|
          if (mr_names_copy.include?(name)) then
            raise "Invalid scan rule declaration for project '#{project.name}' and ruleset '#{rs.name}'. Duplicate matchrule name of '#{name}'."
          end
          mr_names_copy << name
        end # of mr_name.each
        
        if (operands.size > 0) then
          raise "Invalid scan rule declaration for project '#{project.name}' and ruleset '#{rs.name}'. Did not have a matchrule for each operand in the eval expression '#{rs.result_expression}'."
        end
      end # of project.rulesets.each
    end # of projects.each
    
    # everything validated
    return true
  end
  
=begin rdoc 
  Constructs a MatchRule in a reflective manner by calling '.create(attributes)'.  
  Built to work with a dynamic, possibly growing list of MatchRules (in other 
  words, it doesn't just know how to construct MatchRule implementations that 
  ship with the product.)

  TODO findme: figure out how to dynamically require new and arbitrary match rules.

  Examples...
    -----------             ------------------
    A type of:              Gets turned into:
    -----------             ------------------
    filename                FilenameMatchRule
    binary                  BinaryMatchRule
    MD5                     MD5MatchRule
    filenameVersion         FilenameVersionMatchRule
    arbitraryPluggable      ArbitraryPluggableMatchRule

  Knows how to construct the default set of MatchRules (Filename, Binary & MD5) 
  given the attributes parameter, which is a Hash(attribute_name -> attribute_value).

  This is where the 'pluggable' ability to add new MatchRule types comes into play.  
  For example, if someone wanted to add a new MatchRule type called FooMatchRule, 
  they would have to implement a foo_match_rule.rb (see the rdoc for MatchRule 
  to find out what it has to respond to).

  Returns an object that responds to 'match?' and 'defined_filename' method calls.
=end  
  def ScanRulesReader.create_match_rule(attributes)
    mr_type = attributes["type"]
    to_eval = get_match_rule_class_name(mr_type) + ".create(attributes)"
    return eval(to_eval)
  end
  
  def ScanRulesReader.get_match_rule_class_name(match_rule_type_str)
    c1 = match_rule_type_str[0..0].capitalize
    the_rest = match_rule_type_str[1..match_rule_type_str.length]
    return c1 + the_rest + "MatchRule"
  end
  
=begin rdoc 
  Simply parses the scan-rules.xml input param and pulls out the scanrule's project name, who it is from, the os's it works and it's description.  
  Populates an Array of ProjectRule objects with only the aforementioned attributes filled in.  
  Returns this Array.
=end  
  def ScanRulesReader.discoverable_projects(scan_rules_dirs) 
    
    projects = Array.new
    
    scan_rules_dirs.each do |scan_rules_dir|
      
      rules_files = ScanRulesReader.find_all_scanrules_files(scan_rules_dir)
      if (rules_files == nil || rules_files.size == 0) then 
        @@log.warn("ScanRulesReader") { "No scan rules xml files found in directory: '#{scan_rules_dir}'" }
        next
      end
        
      rules_files.each_with_index do |filepath, index| 
        file = File.new(filepath)
        xml = Document.new(file)
        root = xml.root
     
        # spin through all the projects in the scan rules file
        root.elements.each do |xproject| 
          
          project = ProjectRule.new(xproject.attributes["name"], 
                                xproject.attributes["from"], 
                                xproject.attributes["os"].split(","))
          if (xproject.elements["description"] != nil) then
            project.desc = xproject.elements["description"].text
          end
  
          projects << project
        end # of root.elements.each
        
      end # of rules_files.each
      
    end # of scan_rules_dirs.each
    
    return projects
  end

=begin rdoc
  Returns all the xml files in a given directory
  Supports nested dirs/files.
  Ignores paths that have '.svn' in them.

  Returns a Set of fully qualified filenames.
=end 
  def ScanRulesReader.find_all_scanrules_files(scanrules_dir)
    if (scanrules_dir == nil || !File.directory?(scanrules_dir)) then raise "'#{scanrules_dir}' is not a directory.  Please specify a directory" end
    all_files = Set.new
    Find.find(scanrules_dir) do |path|
      if (File.file?(path) && 
          !path.include?(".svn") && 
          (path.size >= ".xml".size + 1) &&
          (path[(path.size - ".xml".size)..(path.size)] == ".xml") && 
          !path.include?("bak") 
          ) then
        all_files << File.expand_path(path)
      end
    end
    
    return all_files
  end
  
  def ScanRulesReader.find_duplicated_md5_match_rules(scan_rules_dirs) 
    md5_strings = Array.new
    scan_rules_dirs.each do |scan_rules_dir|
      rules_files = ScanRulesReader.find_all_scanrules_files(scan_rules_dir)
      if (rules_files == nil || rules_files.size == 0) then 
        @@log.warn("ScanRulesReader") { "No scan rules xml files found in directory: '#{scan_rules_dir}'" }
        next
      end
        
      rules_files.each_with_index do |filepath, index| 
        file = File.new(filepath)
        xml = Document.new(file)
        root = xml.root
     
        # spin through all the projects in the scan rules file
        root.elements.each do |xproject| 
          xproject.elements.each("match-rules") do | xruleset |
            xruleset.elements.each("match-rule") do | xmr |
              ruletype = xmr.attributes["type"]
              if (ruletype == "MD5") then
                md5_strings << xmr.attributes["md5sum"]
              end
            end # of xruleset.elements.each
          end # of xproject.elements.each  
        end # of root.elements.each
      end # of rules_files.each
    end # of scan_rules_dirs.each
    dupes = md5_strings.inject({}) {|h,v| h[v]=h[v].to_i+1; h}.reject{|k,v| v==1}.keys
    dupes.each {|dupe| puts dupe}
  end # of the method
  
  def self.generate_aggregate_md5(dir_with_rules_files)
    files = ScanRulesReader.find_all_scanrules_files(dir_with_rules_files).to_a.sort
    md5s = Array.new
    files.each do |f|
      file = File.new( f, "rb" )
      md5_val = Digest::MD5.hexdigest( file.read )
      file.close
      md5s << md5_val
    end # of files.each
    
    concatted_md5_str = ""
    md5s.each do |md5|
      concatted_md5_str << md5
    end # of md5s.each
    
    aggregate_md5_val = Digest::MD5.hexdigest(concatted_md5_str)
    return aggregate_md5_val
  end
  
  def self.get_universal_rules_version()
    openlogic_rules_dir = Config.prop(:rules_openlogic)
    rules_files = ScanRulesReader.find_all_scanrules_files(openlogic_rules_dir)
    
    universal_versions = Set.new
    
    rules_files.each do |rules_file|
      file = File.new(rules_file)
      xml = Document.new(file)
      root = xml.root
      universal_versions << root.attributes['universal-version']
    end # of rules_files.each
    
    if (universal_versions.size == 0 or (universal_versions.size == 1 and universal_versions.to_a.first.nil?)) then
      return ERROR_NO_UNIVERSAL_VERSION_VALUES_SET
    elsif (universal_versions.size > 1) then
      return ERROR_MULTIPLE_UNIQUE_UNIVERSAL_VERSIONS
    else
      return universal_versions.to_a[0]
    end
    
  end
  
end
