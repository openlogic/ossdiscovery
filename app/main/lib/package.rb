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
=begin rdoc
  This class essentially represents a simple, flattened rendition of what packages were discovered
  by the tool.  In addition to package names, versions and locations where they were found are
  encapsulated here.  The class doesn't come into play until the scan itself is complete, and the
  process is on the stage of rolling up and analyzing results.

  There are also a few class methods that are used by the RuleAnalyzer to help roll up the results
  of MatchRule states.  Namely, create_instances and make_packages_with_bad_unknowns_removed.
=end 

require 'set'

require File.join(File.dirname(__FILE__), 'conf', 'config')

class Package
  VERSION_UNKNOWN = "unknown"
  attr_accessor :name, :version, :found_at
  
=begin rdoc
  I don't know why they call this the 'spaceship' operator.  It looks more like
  a mouth to me, so I'm calling it the 'mouth' operator.
=end  
  def <=>(other)
    val = 0
    if (self.name == other.name) then
      if (self.version == other.version) then
        if (self.found_at == other.found_at) then
          val = 0
        else
          val = self.found_at <=> other.found_at
        end
      else
        val = self.version <=> other.version
      end
    else
      val = self.name <=> other.name
    end
    
    return val
  end
  
  def eql?(other)
    if ((self.==(other)) && (self.class == other.class)) then
      return true
    else
      return false
    end
  end
  
  def ==(other)
    val = false
    if ((other.name == @name) && 
          (other.version == @version) &&
          (other.found_at == @found_at)) then
      val = true
    end
    val
  end
  
  def hash
    val = 17
    val += 37 * @name.hash
    val += 37 * @version.hash
    val += 37 * @found_at.hash
    
    val
  end

  def self.make_packages_with_bad_unknowns_removed(packages)
    no_unknowns = Set.new
    only_unknowns = Set.new
    packages.each do |pkg|
      if (pkg.version != VERSION_UNKNOWN)
        no_unknowns << pkg
      else
        only_unknowns << pkg
      end
    end

    valid_packages = Set.new
    valid_packages.merge(no_unknowns)

    only_unknowns.each do |upkg|
      valid_unknown = true
      no_unknowns.each do |vpkg|
        if (vpkg.name == upkg.name && vpkg.found_at == upkg.found_at)
          valid_unknown = false
          break
        end
      end # of no_unknowns.each
      if valid_unknown
        valid_packages << upkg
      end
    end

    valid_packages
  end
  
  def self.make_packages_with_bad_unknowns_removed_old(packages, project)
    no_unknowns = Set.new
    only_unknowns = Set.new
    packages.each do |pkg|
      # hack to support fast-file-name-matcher because that's a special rule
      # that can find many different packages
      if (pkg.name == project.name || project.name == "fast-file-name-matcher") then
        if (pkg.version != VERSION_UNKNOWN) then
          no_unknowns << pkg
        else
          only_unknowns << pkg
        end
      end
    end # of packages.each
    
    valid_packages = Set.new
    valid_packages.merge(no_unknowns)
    
    only_unknowns.each do |upkg|
      valid_unknown = true
      no_unknowns.each do |vpkg|
        if (vpkg.found_at == upkg.found_at) then
          valid_unknown = false
          break
        end
      end # of no_unknowns.each
      if (valid_unknown) then
        valid_packages << upkg
      end
    end # of only_unknowns.each
    
    return valid_packages
  end
  
=begin rdoc
  Return a set of Package instances.  For all given locations (directories), and one given
  ProjectRule, take the informational state of the ProjectRule hierarchy (the real info is found
  by calling the 'get_found_versions' method on various MatchRule objects).  This method has an
  internal client, so it is safe to assume that all the given 'locations' are actually locations
  where something has been found, as opposed to some arbitrary list of directories on the machine.

  A specific point about what this method does with 'unknown' versions:
    - If "unknown" was the only hit for a given location, report that.
    - If we hit on "unknown" and some actual version, the "unknown" probably
      only exists as kruft left around from an AND of two match rules (One that
      could get us part of the way there, telling us the package existed, but not
      knowing which version, and one that finished the job by telling us the version as well.)
=end 
  def self.create_instances(locations, project_rule)
    
    instances = Set.new
    
    locations.each_with_index do |location, index|

      project_names_and_archive_parents  = nil
      version_and_archive_parents_set = Set.new
      project_rule.rulesets.each do |ruleset|
        ruleset.match_rules.each do |match_rule|
          # hack for filename_list rules
          if match_rule.type == MatchRule::TYPE_FILENAME_LIST
            project_names_and_archive_parents = match_rule.get_found_versions(location)
            versions_and_archive_parents = project_names_and_archive_parents.collect { |pnaap| [VERSION_UNKNOWN, pnaap[1]] }
          else
            versions_and_archive_parents = match_rule.get_found_versions(location)
          end
          versions_and_archive_parents.each do |version_and_archive_parents|
            if (version_and_archive_parents[0] == nil || version_and_archive_parents[0] == "")
              version_and_archive_parents[0] = VERSION_UNKNOWN
            end
            version_and_archive_parents_set << version_and_archive_parents
          end # of found_versions.each
        end
        
        # See the note in this method's rdoc about 'unknown' versions for an
        # explanation of what's going on here.
        if (version_and_archive_parents_set.size > 1) then
          version_and_archive_parents_set.delete_if {|vaap| vaap[0] == VERSION_UNKNOWN}
        end
      end # of project_rule.rulesets.each

      # hack for filename_list rules that can produce a list of found projects
      # in a single directory
      if project_names_and_archive_parents
        project_names_and_archive_parents.each do |pnaap|
          package = Package.new
          package.name = pnaap[0]
          package.version = VERSION_UNKNOWN
          #puts "#{package.name}, location = #{location}, pnaap[1] = #{pnaap[1].inspect}"
          package.found_at = reportable_location(location, pnaap[1])
          instances << package
        end
      else
        version_and_archive_parents_set.each do |vaap|
          package = Package.new
          package.name = project_rule.name
          package.found_at = reportable_location(location, vaap[1])
          # Doing this gsub because we ran into a scenario when using a hex
          # binary match where the version looked like this: 2^@.^@3
          package.version = vaap[0].gsub("\0", "")
          
          instances << package
        end # of version_set.each
      end
    end # of locations.each
    
    instances
  end

  # Return a location that includes a potential chain of archive parents along
  # with a given directory.  For example, if web-inf/lib/ant.jar is found in
  # myapp.war which in turn is found in /deploy/bigproj.ear, the result will
  # look like this:
  #   /deploy/bigproj.ear!myapp.war!web-inf/lib/ant.jar
  def self.reportable_location(dir, archive_parents)
    if archive_parents.empty?
      dir.empty? ? "/" : dir
    else
      dir = remove_parent_path(dir, archive_parents.last[1])
      dir = dir.empty? ? "/" : dir
      archive_parents.collect { |parent| parent[0] }.join('!') << '!' << dir
    end
  end
  
  # Given two paths such as:
  #   p1 = /tmp/solr.war20090127-32155-8pp7xr-0/WEB-INF/lib/commons-io.zip
  # and
  #   p2 = /tmp/solr.war20090127-32155-8pp7xr-0
  # return a path like this:
  #   p = /WEB-INF/lib/commons-io.zip
  def self.remove_parent_path(full_path, parent_path)
    full_path[parent_path.size..-1]
  end

end