# rule_engine.rb
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
#
#  implements the RuleEngine class whose primary responsibility to to manage the
#  rule sets, accept found files from the walker and apply match rules to the found
#  file as appropriate.

=begin rdoc
  an instance of RulesEngine manages the project's rulesets for a given scan rules file
  it communicates with the walker what files and file types the walker should be allowing
  during the scan.  Generally, RuleEngine is a singleton, though nothing technically 
  keeps it from being instantiated more.
=end

# from the Ruby library
require 'set'
require 'rexml/document'
include REXML

$:.unshift File.join(File.dirname(__FILE__))

# from internal source
require 'eval_rule'
require 'project_rule'
require 'match_rule_set'
require 'rule_analyzer'
require 'scan_rules_reader'
require 'matchrules/binary_match_rule'
require 'matchrules/filename_match_rule'
require 'matchrules/filename_version_match_rule'
require 'matchrules/match_audit_record'
require 'matchrules/md5_match_rule'


class RuleEngine
  
  @@log = Config.log
  
  attr_reader :project_rules, :speed, :analysis_elapsed, :audit_records

  @scan_rules_dir = nil
  @walker = nil

  # project_rules is a Set of Project objects.  Each Project object contains a list of
  # RuleSets - RuleSets contain a list MachRules and the expression to evaluate the MatchRules
  @project_rules = nil
     
=begin rdoc
    create a RuleEngine with a full path to a rules filename and an instance of a Walker
=end    
  def initialize( rulesdirs, walker, speedhint )

    @scan_rules_dirs = rulesdirs
    @walker = walker
    @project_rules = Set.new
    @speed = speedhint
    @audit_records = Array.new

    load_scan_rules
  end
     
=begin rdoc
    callback from the walker to notify the RuleEngine a file of interest was found.
    The walker will call its registered subscribers with the location of the found
    file, the filename itself, and what filter matched.
    
    Since multiple rules may match the same file, the rule_used is mainly a diagnostic
    or hint which can tell the RuleEngine how the walker is picking stuff up

    The archive parents parameter is a potentially empty list of archive
    files that contains the found file.

    Return true if the file matches at least one rule.
=end

  def found_file(location, filename, filter_used, archive_parents)
  
    if $DEBUG
      printf("found_file %s, %s, %s in %s\n", location, filename, filter_used, archive_parents.join('!'))
    end

    any_matches = false
    
    digest_of_found_file = nil
    binary_content_of_found_file = nil
    produce_match_audit_records = Config.prop(:produce_match_audit_records)

    # each project_rule object contains a collection of rulesets.  each ruleset contains a collection of match rules

    @project_rules.each do | project_rule |
      project_rule.rulesets.each do | ruleset | 
        has_md5_match_occurred = false
        match_or_not = false
        ruleset.match_rules.each do | match_rule |
          begin
              if (match_or_not && ruleset.is_result_expression_or_all) then
                # an optimization, if the rule is a bunch of OR's, we know one true will be enough to make the whole thing true, so there's no point in calling match? again
                break
              else
                begin
                  if (has_md5_match_occurred && match_rule.type == MatchRule::TYPE_MD5) then
                    # an optimization, don't call 'match_rule.match?', it's not necessary
                    next
                  else
                    if (match_rule.type == MatchRule::TYPE_MD5) then
                      match_or_not, digest_of_found_file = match_rule.match?(location + "/" + filename, digest_of_found_file, archive_parents)
                      print_stuff = true if digest_of_found_file
                      has_md5_match_occurred = match_or_not ? true : false
                    elsif (match_rule.type == MatchRule::TYPE_BINARY) then
                      match_or_not, binary_content_of_found_file = match_rule.match?(location + "/" + filename, binary_content_of_found_file, archive_parents)
                      print_stuff = true if binary_content_of_found_file
                    else
                      match_or_not = match_rule.match?(location + "/" + filename, archive_parents)
                    end
                    # make sure any_matches is set to true if any rule has matched
                    any_matches ||= match_or_not
                    # For debugging purposes
                    if (produce_match_audit_records && match_or_not)
                      @audit_records << MatchAuditRecord.new(project_rule.name, ruleset.name, match_rule.name, location + "/" + filename, match_rule.get_latest_matchval)
                    end
                  end
                rescue 
                  $stderr.printf("\nMatch exception (#{$!.inspect}) with %s/%s project_rule: %s, ruleset: %s, matchrule: %s\n", location, filename, project_rule.name, ruleset.name, match_rule.name )
                end
            end
          rescue Errno::EACCES, Errno::EPERM
            @@log.error('RuleEngine') {"Expected all files with permissions issues to have been filtered out already. #{$!.inspect}"}
          end
        end # of ruleset.match_rules.each
      end # of project_rule.rulesets.each
    end # of @project_rules.each

    any_matches
  end
  
=begin rdoc
  this method is a call back from the Framework.  It's job is to now evaluate the ruleset combinations for 
  all the projects and return an aggregated list of packages that were found during the scan
=end 
  def scan_complete
    @analysis_start = Time.new    
    @all_packages = RuleAnalyzer.aggregate_matches(@project_rules)
    @analysis_stop = Time.new  
    @analysis_elapsed = @analysis_stop - @analysis_start
    @all_packages 
  end

=begin rdoc 
    reads the scan rules XML file, scan_rules_filename, loads the projects and rulesets
    into the engine
=end
  def load_scan_rules
    @project_rules = ScanRulesReader.setup_project_rules(@scan_rules_dirs, @speed)    
    register_with_walker
  end

  def register_with_walker
   # register for a callback from the walker when a file of interst is found
   # tell the walker what the list of files of interest are
   @walker.set_files_of_interest(self, files_of_interest)
  end
     
=begin rdoc
  This method returns a Set of files that the rule engine wants the walker to 
  be able to detect.  This list of files should contain no duplicates and may 
  consist of regular expressions that can match basenames or literal filenames.
=end
  def files_of_interest
    files = Set.new
    @project_rules.each { |prule|
      prule.rulesets.each { |ruleset|
        ruleset.match_rules.each { |match_rule|
          files.add(match_rule.defined_filename)
        }
      }
    }
    return files
  end

=begin rdoc
  getter/setter for speed hint.  this value is used to filter out which match rules, rulesets and evaluation expressions
  should be used during this scan and analysis.  
  
  current valid values for speedhint are:
    1 - Fastest  (package name only)
    2 - Medium   (package and usually vesion)
    3 - Slow     (looks for matches on a wider array of files of interest - less strict file of interest filter)
=end
  def speed=(speedhint)
    @speed = speedhint
  end
end
  
