require 'pp'
require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), "..", "main", "lib")

require 'search_trees'
require File.join(File.dirname(__FILE__), 'test_helper')

class TcClassFilePathTernarySearchTree < Test::Unit::TestCase

  def setup
    SearchTrees.initialize
    @tst = SearchTrees.class_file_path_tree
  end
  
  def test_creation
    assert_equal 1, @tst.nodes.size
  end

  def test_basic_get_and_put
    items = %w{apache}
    items.each do |item|
      @tst.put(item, item)
      assert_equal item, @tst.get(item)
    end
    assert_nil @tst.get('notthere')
    @tst.put('nil', nil)
    assert_nil @tst.get('nil')
  end

  def test_advanced_get_and_put
    items = %w{a aa a-a a+a nil}
    items.each do |item|
      @tst.put(item, item)
      assert_equal item, @tst.get(item)
    end
  end

  def test_load_from_simple_file
    @tst.load_from_file(simple_test_file_name)
    items = %w{ant antlr apache apache2 apache-tomcat tomcat}
    items.each do |item|
      @tst.put(item, item)
      assert_equal item, @tst.get(item)
    end
  end

  def test_simple_class_file_path_match
    @tst.load_from_file(simple_test_file_name)
    items = [
      %w{ant org/apache/tools/ant/thing.class},
      %w{antlr org/antlr/thing.class},
      %w{apache-tomcat org/apache/tomcat/thing.class},
      %w{apache-tomcat org/catalina/thing.class},
      %w{ant-tools org/apache/tools/test/thing.class},
      %w{ant-tools org/apache/tools/antsy/logging/Ant.class},
      %w{tomcat org/tomcat/thing.class},
      %w{ant WEB-INF/lib/org/apache/tools/ant/thing.class}]
    items.each do |item|
      assert_equal item[0], @tst.match(item[1])
    end
  end

  def test_simple_class_file_path_no_match
    @tst.load_from_file(simple_test_file_name)
    items = %w{org/jboss org/apache org/dude/antlr/thing org/apache/stuff/Ant.class Ant.class}
    items.each do |item|
      assert_nil @tst.match(item)
    end
  end

  def test_load_from_real_file
    @tst.load_from_file(full_test_file_name)
    items = %w{ant antlr apache apache2 apache-tomcat tomcat}
    items.each do |item|
      @tst.put(item, item)
      assert_equal item, @tst.get(item)
    end
  end

  def no_test_real_file_search_against_small_file
    @tst.load_from_file(full_test_file_name)
    targets = []
    file = File.new(target_test_file_name)
    while filename = file.gets
      targets << filename.strip
    end

    puts Time.now
    targets.each do |target|
      match = @tst.match(target)
      if match
        #        assert_equal target, match.package_id
      else
        puts "couldn't find #{target}"
      end
    end
    puts Time.now
  end

  def test_simple_jar_file
    @tst.load_from_file(simple_test_file_name)

    targets = %w()

    targets.each do |target|
      match = @tst.match(target)
      if match
        #        assert_equal target, match.package_id
      else
        puts "couldn't find #{target}"
      end
    end
  end

  protected

  def simple_test_file_name
    @@simple_test_file_name ||= File.join(File.dirname(__FILE__), "resources", "rules", "test_file_names", "filenames.txt")
  end

  def full_test_file_name
    @@full_test_file_name ||= File.join(File.dirname(__FILE__), "resources", "rules", "test_file_names", "projects.txt")
  end
end