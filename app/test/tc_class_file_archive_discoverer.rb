require 'pp'
require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), "..", "main", "lib")
require File.join(File.dirname(__FILE__), 'test_helper')

require 'search_trees'
require 'class_file_archive_discoverer'

class TcClassFileArchiveDiscoverer < Test::Unit::TestCase

  def setup
    SearchTrees.initialize({}, {})
    @tst = SearchTrees.class_file_path_tree
  end
  
  def test_load_simple_jar_file
    paths = ClassFileArchiveDiscoverer.get_class_file_paths(simple_test_jar_file_name)
    assert_equal 1, paths.size
    assert_equal "org/apache/commons/collections/thing.class", paths.first
  end

  def test_discover_simple_jar_file
    @tst.load_from_file(simple_test_file_name)
    matches = ClassFileArchiveDiscoverer.discover(simple_test_jar_file_name)
    assert_equal 1, matches.size
    assert_equal "commons-collections", matches.keys.first
    assert_equal "org/apache/commons/collections/thing.class", matches.values.first
  end

  def test_discover_collections_jar_files
    @tst.load_from_file(simple_test_file_name)
    matches = ClassFileArchiveDiscoverer.discover(collections_jar_file_name)
    assert_equal 1, matches.size
    assert_equal "commons-collections", matches.keys.first
    assert_equal "org/apache/commons/collections/ArrayStack.class", matches.values.first
  end

  def test_discover_collections_jar_files_loaded_through_search_trees
    SearchTrees.load_from_file(simple_test_file_name)
    matches = ClassFileArchiveDiscoverer.discover(collections_jar_file_name)
    assert_equal 1, matches.size
    assert_equal "commons-collections", matches.keys.first
    assert_equal "org/apache/commons/collections/ArrayStack.class", matches.values.first
  end

  protected

  def simple_test_jar_file_name
    @@simple_test_jar_file_name ||= File.join(File.dirname(__FILE__), "resources", "content-archives", "simple.jar")
  end

  def collections_jar_file_name
    @@collections_jar_file_name ||= File.join(File.dirname(__FILE__), "resources", "content-archives", "A.jar")
  end

  def simple_test_file_name
    @@simple_test_file_name ||= File.join(File.dirname(__FILE__), "resources", "rules", "test_file_names", "filenames.txt")
  end

  def full_test_file_name
    @@full_test_file_name ||= File.join(File.dirname(__FILE__), "resources", "rules", "test_file_names", "projects.txt")
  end
end