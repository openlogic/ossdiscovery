require 'pp'
require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), "..", "main", "lib")

require 'package'
require 'project_rule'
require File.join(File.dirname(__FILE__), 'test_helper')

class TcPackage < Test::Unit::TestCase
  
  def setup
    
  end
  
  def teardown
    
  end

  def test_eql_and_hash()
    # scenario 1
    p1 = Package.new
    p1.name = 'dom4j'
    p1.version = 'unknown'
    p1.found_at = '/home/bnoll/projects/openlogic/discovery2-client/src/test/resources/content-cg/dom4j/1.4'
    
    p2 = Package.new
    p2.name = 'dom4j'
    p2.version = 'unknown'
    p2.found_at = '/home/bnoll/projects/openlogic/discovery2-client/src/test/resources/content-cg/dom4j/1.4'
    
    assert(p1.eql?(p2))
    assert(p1.hash == p2.hash)
    packages = Set.new
    packages << p1
    assert(packages.include?(p2))
    packages = Set.new
    packages << p2
    assert(packages.include?(p1))
    
    # scenario 2
    p1 = Package.new
    p1.name = 'dom4j'
    p1.version = 'unknown'
    p1.found_at = '/home/bnoll/projects/openlogic/discovery2-client/src/test/resources/content-cg/dom4j/1.4'
    
    p2 = Package.new
    p2.name = 'dom4j' # same
    p2.version = 'unknown' # same
    p2.found_at = '/home/bnoll/projects/openlogic/discovery2-client/src/test/resources/content-cg/dom4j/1.4' # same 
    
    assert(p1.eql?(p2))
    assert(p1.hash == p2.hash)
    packages = Set.new
    packages << p1
    assert(packages.include?(p2))
    packages = Set.new
    packages << p2
    assert(packages.include?(p1))
  end
  
  def test_make_packages_with_bad_unknowns_removed
    packages = Set.new
    
    p1 = Package.new 
    p1.name = 'spring'
    p1.version = '2.0'
    p1.found_at = '/home/me/spring'
    
    p2 = Package.new 
    p2.name = 'spring'
    p2.version = 'unknown'
    p2.found_at = '/home/me/spring'
    
    packages << p1 << p2
    
    project = ProjectRule.new('spring')
    
    packages = Package.make_packages_with_bad_unknowns_removed(packages, project)
    assert_equal(1, packages.size)
    packages.each {|pkg| assert_equal('2.0', pkg.version)}
  end
  
  def test_spacheship_operator
    p1 = Package.new
    p1.name = 'alligator'
    p1.version = '1.0'
    p1.found_at = '/home/me/alligator'
    
    p2 = Package.new
    p2.name = 'bear'
    p2.version = '1.0'
    p2.found_at = '/home/me/bear'
    
    p3 = Package.new
    p3.name = 'bear'
    p3.version = '1.0'
    p3.found_at = '/home/you/bear'
    
    p4 = Package.new
    p4.name = 'bear'
    p4.version = '2.0'
    p4.found_at = '/home/me/bear'    
    
    p5 = Package.new
    p5.name = 'cougar'
    p5.version = '3.0'
    p5.found_at = '/home/me/cougar'
    
    p6 = Package.new
    p6.name = 'cougar'
    p6.version = 'unknown'
    p6.found_at = '/home/me/cougar'
    
    # add them to the Array in a random order
    packages = Array.new << p6 << p3 << p1 << p5 << p4 << p2
    
    packages.sort!
    
    0.upto(packages.length - 1) do |i|
      if (i+1 == 1) then
        assert_same(p1, packages[i])
      elsif (i+1 == 2) then
        assert_same(p2, packages[i])
      elsif (i+1 == 3) then
        assert_same(p3, packages[i])
      elsif (i+1 == 4) then
        assert_same(p4, packages[i])
      elsif (i+1 == 5) then
        assert_same(p5, packages[i])
      elsif (i+1 == 6) then
        assert_same(p6, packages[i])
      end
    end
  end
  
end