require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), "..", "main", "lib")

require 'eval_rule'
require 'project_rule'
require 'match_rule_set'
require 'matchrules/binary_match_rule'
require 'matchrules/filename_match_rule'
require 'matchrules/md5_match_rule'

require File.join(File.dirname(__FILE__), 'test_helper')

class TcProjectRule < Test::Unit::TestCase
  
  def setup
    
  end
  
  def teardown
    
  end

  def test_eql_and_hash()
    p1 = ProjectRule.new("foo", "wild", ["linux", "sunos-5.10", "sunos-5.9", "sunos-5.8", "macosx"].to_set)
    p2 = ProjectRule.new("foo", "wild", ["linux", "sunos-5.10", "sunos-5.9", "sunos-5.8", "macosx"].to_set)
    assert(p1.eql?(p2))
    assert(p1 == p2)
    assert(p1.hash == p2.hash)
    projects = Set.new
    projects << p1
    assert(projects.include?(p2))    
    projects = Set.new
    projects << p2
    assert(projects.include?(p1))
    
    p1 = ProjectRule.new("foo", "wild", ["windows", "linux"].to_set)
    p2 = ProjectRule.new("foo", "wild", ["linux", "windows"].to_set)
    assert(p1.eql?(p2))
    assert(p1 == p2)
    assert(p1.hash == p2.hash)
    projects = Set.new
    projects << p1
    assert(projects.include?(p2))    
    projects = Set.new
    projects << p2
    assert(projects.include?(p1))
    
    p1 = ProjectRule.new("foo")
    p2 = ProjectRule.new("foo", "wild", ["all"].to_set)
    assert(p1.eql?(p2))
    assert(p1 == p2)
    assert(p1.hash == p2.hash)
    projects = Set.new
    projects << p1
    assert(projects.include?(p2))    
    projects = Set.new
    projects << p2
    assert(projects.include?(p1))
    
    p1 = ProjectRule.new("foo", "wild", ["all"].to_set)
    p2 = ProjectRule.new("foo", "wild", ["not-all"].to_set)
    assert(!p1.eql?(p2))
    assert(p1 != p2)
    
    p1 = ProjectRule.new("foo", "wild", ["all"].to_set)
    p2 = ProjectRule.new("foo", "wild", ["all", "all2"].to_set)
    assert(!p1.eql?(p2))
    assert(p1 != p2)
    
    p1 = ProjectRule.new("foo", "wild", ["all"].to_set)
    p2 = ProjectRule.new("foo", "openlogic", ["all"].to_set)
    assert(!p1.eql?(p2))
    assert(p1 != p2)
    
    p1 = ProjectRule.new("foo", "openlogic", ["all"].to_set)
    p2 = ProjectRule.new("bar", "openlogic", ["all"].to_set)
    assert(!p1.eql?(p2))
    assert(p1 != p2)
  end
  
end