require 'pp'
require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), "..", "main", "lib")

require 'ternary_search_tree'
require File.join(File.dirname(__FILE__), 'test_helper')

class TcTernarySearchTree < Test::Unit::TestCase

  def setup
    @tst = TernarySearchTree.new
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
    @tst.load_from_simple_test_file(simple_test_file_name)
    items = %w{ant antlr apache apache2 apache-tomcat tomcat}
    items.each do |item|
      @tst.put(item, item)
      assert_equal item, @tst.get(item)
    end
  end

  def test_simple_file_name_match
    @tst.load_from_simple_test_file(simple_test_file_name)
    items = [
      %w{apache apache},
      %w{apache apache.exe},
      %w{apache apache.so},
      %w{apache apache.zip},
      %w{apache apache.tar.gz},
      %w{apache apache-2.3b.zip},
      %w{apache2 apache2}]
    items.each do |item|
      assert_equal item[0], @tst.match(item[1])
    end
  end

  def test_simple_file_name_no_match
    @tst.load_from_simple_test_file(simple_test_file_name)
    items = %w{apache-2b.zip apache-ant apache-beta}
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

  def no_test_real_file_search_against_big_file
    @tst.seed_tree
    puts "Loading big file: #{start = Time.now}"
    @tst.load_from_file(full_test_file_name)
    puts "done loading.  Took #{Time.now - start} seconds."
    targets = []
    file = File.new(big_target_test_file_name)
    while filename = file.gets
      targets << filename.strip
    end

    puts "About to do #{10 * targets.size} matches against tree with #{@tst.nodes.size} nodes"
    puts "  starting at #{start = Time.now}"
    count = 0
    10.times do
      targets.each do |target|
        @tst.match(target)
        count += 1
        if count == 10000
          count = 0
          putc '.'
          STDOUT.flush
        end
      end
    end
    puts "  done.  Took #{Time.now - start} seconds."
  end

  def no_test_real_file_search_against_debian_file
    @tst.seed_tree
    puts "Loading big file: #{start = Time.now}"
    @tst.load_from_file(debian_test_file_name)
    puts "done loading.  Took #{Time.now - start} seconds."
    targets = []
    file = File.new(big_target_test_file_name)
    while filename = file.gets
      targets << filename.strip
    end

    puts "About to do #{10 * targets.size} matches against tree with #{@tst.nodes.size} nodes"
    puts "  starting at #{start = Time.now}"
    count = 0
    10.times do
      targets.each do |target|
        @tst.match(target)
        count += 1
        if count == 10000
          count = 0
          putc '.'
          STDOUT.flush
        end
      end
    end
    puts "  done.  Took #{Time.now - start} seconds."
  end

  protected

  def simple_test_file_name
    @@simple_test_file_name ||= File.join(File.dirname(__FILE__), "resources", "rules", "test_file_names", "filenames.txt")
  end

  def target_test_file_name
    @@target_test_file_name ||= File.join(File.dirname(__FILE__), "resources", "rules", "test_file_names", "targetfilenames.txt")
  end

  def big_target_test_file_name
    @@big_target_test_file_name ||= File.join(File.dirname(__FILE__), "resources", "rules", "test_file_names", "bigfilenames.txt")
  end

  def full_test_file_name
    @@full_test_file_name ||= File.join(File.dirname(__FILE__), "resources", "rules", "test_file_names", "projects.txt")
  end

  def debian_test_file_name
    @@debian_test_file_name ||= File.join(File.dirname(__FILE__), "resources", "rules", "test_file_names", "debian.txt")
  end
end