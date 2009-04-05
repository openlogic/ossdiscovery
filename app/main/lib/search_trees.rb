require 'class_file_path_ternary_search_tree'
require 'file_name_ternary_search_tree'

# Encapsulate access to a number of search trees for easy access and unified
# loading efficiency.
class SearchTrees
  # for parsing rules files
  PROJECT_DELIMITER  = ';'

  # set or reset the trees
  def self.initialize(language_map, special_map)
    @@language_map = language_map
    @@special_map = special_map
    @@the_file_name_tree = nil
    @@the_class_file_path_tree = nil
  end

  # initialize and seed the trees
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
    count = 0
    IO.foreach(file_name) do |line|
      begin
        package_id, aliases, languages, namespaces = line.split(PROJECT_DELIMITER)
        # make sure we don't have any strange line ending issues
        namespaces.strip!
        file_name_tree.load_from_details(package_id, aliases, languages, namespaces)
        class_file_path_tree.load_from_details(package_id, aliases, languages, namespaces)
        count += 1
        if count == 10000
          count = 0
          putc '.'
          STDOUT.flush
        end
      rescue Exception => e
        puts "problem reading or parsing rule file line: #{line} because #{e.inspect}"
      end
    end
  end

  # forward this to the file name tree
  def self.match_file_name(file_name)
    file_name_tree.match(file_name)
  end

  # forward this to the class file path tree
  def self.match_class_file_path(class_file_path)
    class_file_path_tree.match(class_file_path)
  end


  # accessors
  def self.file_name_tree
    @@the_file_name_tree ||= FileNameSearchTree::FileNameTernarySearchTree.new(@@language_map, @@special_map)
  end

  def self.class_file_path_tree
    @@the_class_file_path_tree ||= ClassFilePathSearchTree::ClassFilePathTernarySearchTree.new
  end
end