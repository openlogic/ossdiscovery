require 'class_file_path_ternary_search_tree'
require 'file_name_ternary_search_tree'
require 'yaml'
require 'utils'

# Encapsulate access to a number of search trees for easy access and unified
# loading efficiency.
class SearchTrees
  # for parsing rules files
  PROJECT_DELIMITER  = ';'

  @@initialized = false

  # set or reset the trees
  def self.initialize
    return if @@initialized
    @@initialized = true

    # set up our search trees to know about languages and their file extensions
    language_mapping_file = File.expand_path(File.join(
          File.dirname(__FILE__), 'rules', 'openlogic', 'languages.yml'))
    @@language_map = YAML.load_file(language_mapping_file)

    # they also need to know about special files
    special_mapping_file = File.expand_path(File.join(
          File.dirname(__FILE__), 'rules', 'openlogic', 'special-projects.yml'))
    @@special_map = YAML.load_file(special_mapping_file)

    @@the_file_name_tree = nil
    @@the_class_file_path_tree = nil

    tst_file = File.expand_path(File.join(
          File.dirname(__FILE__), 'rules', 'openlogic', 'projects.txt'))

    print "Loading and initializing generated signature groups..."
    start = Time.now
    load_from_file(tst_file)
    puts "done loading #{Utils.number_with_delimiter(@@line_count)} in #{Time.now - start} seconds."

    # prepare the trees with some seed data designed to more evenly
    # distribute the real data once it's loaded
    seed_trees
  end

  # forward this to the file name tree
  def self.match_file_name(file_name)
    initialize
    file_name_tree.match(file_name)
  end

  # forward this to the class file path tree
  def self.match_class_file_path(class_file_path)
    initialize
    class_file_path_tree.match(class_file_path)
  end

  protected

  # seed the trees
  def self.seed_trees
    file_name_tree.seed_tree
    class_file_path_tree.seed_tree
  end

  # load the tree from a rules file that looks like this: projectid;Project
  # Name;aliasid1,aliasid2,...;language1,language2,...;namespace1,namespace2,...
  #  Where:
  #   projectid - the id to report when a match is found - [a-z0-9_+-]
  #   Project Name - optionally reported to users - anything but a ;
  #   aliasids - look for file names that match these aliases, one of which
  #              is almost always identical to the projectid - [a-z0-9_+-]
  #   languages - programming languages (e.g., java, c++) - used to determine
  #               which file extensions are relevant - must exactly match a
  #               known value as determined in (TODO - do something with languages)
  #   namespaces - currently only used for Java projects - used to match against
  #                class files inside a jar (e.g., org.apache.commons.collections)
  def self.load_from_file(file_name)
    @@line_count = 0
    IO.foreach(file_name) do |line|
      begin
        package_id, aliases, languages, namespaces = line.split(PROJECT_DELIMITER)
        # make sure we don't have any strange line ending issues
        namespaces.strip!
        file_name_tree.load_from_details(package_id, aliases, languages, namespaces)
        class_file_path_tree.load_from_details(package_id, aliases, languages, namespaces)
        @@line_count += 1
        if @@line_count % 10000 == 0
          putc '.'
          STDOUT.flush
        end
      rescue Exception => e
        puts "problem reading or parsing rule file line: #{line} because #{e.inspect}"
      end
    end
  end


  # accessors
  def self.file_name_tree
    @@the_file_name_tree ||= FileNameSearchTree::FileNameTernarySearchTree.new(@@language_map, @@special_map)
  end

  def self.class_file_path_tree
    @@the_class_file_path_tree ||= ClassFilePathSearchTree::ClassFilePathTernarySearchTree.new
  end
end