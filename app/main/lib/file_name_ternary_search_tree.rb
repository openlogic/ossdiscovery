module FileNameSearchTree

  # Implemented a simple, limited ternary search tree used to quickly and
  # efficiently load file name rules and then search against them with file
  # names.
  class FileNameTernarySearchTree
    # for maximum efficiency, just stick all the pertinent information into a
    # simple array indexed by these constants
    KEY         = 0
    VALUE       = 1
    LEFT_CHILD  = 2
    RIGHT_CHILD = 3
    EQUAL_CHILD = 4

    # for parsing rules files
    PROJECT_DELIMITER  = ';'
    ALIAS_DELIMITER    = ','
    LANGUAGE_DELIMITER = ','
    NAMESPACE_DELIMITER = ','


    attr_accessor :nodes

    # Store the entire tree in a flat array indexed by integers. Create a single
    # node and call it the root.
    def initialize(language_map)
      @language_map = {}
      # make sure the keys in the language map are symbols
      language_map.each do |language, extensions|
        @language_map[language.downcase.to_sym] = extensions
      end
      @nodes = []
      @root = new_node
    end

    # Add a node to the end of the array.  All it's value are initially nil.
    # Return the array index of the newly added item.
    def new_node
      node = Array.new(5)
      @nodes << node
      @nodes.size - 1
    end

    # To get a node from the "tree", just index into the flat array.
    def get_node(i)
      @nodes.at(i)
    end

    # Implement reads into the tree by following the standard ternary tree
    # algorithm.  We store one character of the string key per node.  The
    # character is actually stored as its integer value to make comparisons
    # fast.
    def get(key)
      # start at the root
      node = get_node(@root)

      # iterate over each character of the key, which must be a string
      for i in 0...key.size
        ch = key[i]
        node = get_node_containing_char_starting_from_node(ch, node)
        return nil unless node

        # To get through the loop above, the current node must now contain the
        # character we're looking for.  This means that if we're not at the end
        # of the entire key string, we need to continue from the 'equal' child.
        if i + 1 != key.length
          return nil unless node[EQUAL_CHILD]
          node = get_node(node[EQUAL_CHILD])
        end
      end

      # We're now at the final node in the chain that defines the given key
      # string so it's time to retrieve our value.  Note that this could still
      # be nil because that's what's explicitly stored here or because the
      # string we're looking for is a subset of some other key with a value
      # further down the tree.
      node[VALUE]
    end

    # Implement writes into the tree by following the standard ternary tree
    # algorithm.  We store one character of the string key per node.  The
    # character is actually stored as its integer value to make comparisons
    # fast.
    def put(key, value)
      # start at the root
      node = get_node(@root)

      # iterate over each character of the key, which must be a string
      for i in 0...key.size
        ch = key[i]
        # keep going until we place (or find) this new character in a node note
        # that we iterate to avoid recursion overhead
        while node[KEY] != ch
          # if we're in a node with no key (meaning character), put ours here
          if node[KEY] == nil
            node[KEY] = ch
          elsif ch < node[KEY]
            # our character is less than the current node's key, so move to the
            # node's left child and look there
            unless node[LEFT_CHILD]
              node[LEFT_CHILD] = new_node
            end
            node = get_node(node[LEFT_CHILD])
          elsif ch > node[KEY]
            # our character is greater than the current node's key, so move to
            # the node's right child and look there
            unless node[RIGHT_CHILD]
              node[RIGHT_CHILD] = new_node
            end
            node = get_node(node[RIGHT_CHILD])
          end
        end

        # To get through the loop above, the current node must now contain the
        # character we're looking for.  This means that if we're not at the end
        # of the entire key string, we need to create a new 'equal' child node
        # and proceed from there.
        if i + 1 != key.length
          if node[EQUAL_CHILD] == nil
            node[EQUAL_CHILD] = new_node
          end
          node = get_node(node[EQUAL_CHILD])
        end
      end

      # we're now at the final node in the chain that defines the given key
      # string so it's time to store our value
      node[VALUE] = value
    end

    # Return a node containing the given character starting from the given node,
    # or nil if none exists
    def get_node_containing_char_starting_from_node(ch, node)
      # keep going until we find the given character in a node. note that we
      # iterate to avoid recursion overhead
      while node[KEY] != ch
        if ch < node[KEY]
          # our character is less than the current node's key, so move to the
          # node's left child and look there
          return nil unless node[LEFT_CHILD]
          node = get_node(node[LEFT_CHILD])
        elsif ch > node[KEY]
          # our character is greater than the current node's key, so move to the
          # node's right child and look there
          return nil unless node[RIGHT_CHILD]
          node = get_node(node[RIGHT_CHILD])
        end
      end
      node
    end

    # Return the value associated with the key matching the given file name or
    # nil if none is found.  The definition of 'match' is based on this
    # algorithm:
    #
    # let bm = nil, will store best match so far, if any for each character in
    # given file name
    #   if character is a 'stop' character
    #     return bm and end the search
    #   if character is a 'reset' character
    #     set bm = nil
    #   look for character in tree
    #   if character found, advanced position in tree
    #     if value found in tree, store in bm
    #   if character not found
    #     for each remaining character in given file name
    #       if character is a 'reset' character
    #         return nil (no match) and end the search
    #       if character is a 'stop' character
    #         return bm and end the search
    # return bm and end the search
    #
    # Where:
    #   stop character is '.' or any other character outside of [a-z0-9_+-]
    #   reset character is 'a-z'
    #
    # Examples:
    #   File name    Tree contents    Match
    #   ------------ ---------------- -----
    #   apache       apache           true
    #   apache.exe   apache           true
    #   apache.so    apache           true
    #   apache.zip   apache           true
    #   apache1      apache           true
    #   apache-2.3b  apache           true
    #   apache-2b    apache           false
    #   apache-ant   apache           false
    #   apache-beta  apache           false
    def match(filename)
      # start searches at the root
      node = get_node(@root)

      # keep track of our best match so far, if any
      best_match = nil

      # iterate through each character of the given file name
      for i in 0...filename.size
        # prepare the current character for analysis
        CharacterInfo.current_character = filename[i]

        # if we hit a stop character like '.', we're done
        if CharacterInfo.stop_character?
          return prepare_answer(best_match, filename)
        end
        # if we hit a reset character like a-z, we need to forget our best match
        # so far as it's now obsolete
        if CharacterInfo.reset_character?
          best_match = nil
        end
        # look for the character in the tree starting from the current node
        node = get_node_containing_char_starting_from_node(CharacterInfo.current_character, node)
        if node
          # update our best match so far if there's a value in this node
          best_match = node[VALUE] if node[VALUE]
          # now advance to this node's 'equal' child, if any
          node = get_node(node[EQUAL_CHILD]) if node[EQUAL_CHILD]
        else
          # couldn't find the character, so we're done with the tree. look at
          # the rest of the file name to see if we're already up to the version
          # number, an extension, or the end of the file name
          for j in i+1...filename.size
            # prepare the current character for analysis
            CharacterInfo.current_character = filename[j]
            # if we hit a reset character, we're toast
            return nil if CharacterInfo.reset_character?
            # if we hit a stop character, return the best results so far, if any
            return prepare_answer(best_match, filename) if CharacterInfo.stop_character?
          end
          # we made it to the end of the file name without any issues, so return
          # the best match so far, if any
          return prepare_answer(best_match, filename)
        end
      end
      # we made it to the end of the file name without any issues, so return the
      # best match so far, if any
      return prepare_answer(best_match, filename,  false)
    end

    # post-process our current best match and the given filename to create a
    # value suitable for return to the callers of "match"
    def prepare_answer(best_match, filename, guess_version = true)
      language_okay = check_language(best_match, filename)
      if language_okay
        version = guess_version ? guess_version(filename, best_match) : "unknown"
        [best_match ? best_match[1] : nil, version]
      else
        [nil, "unknown"]
      end
    end

    # we need to make sure the matched project and the file name extension
    # agree with the language information we have on the project, if any
    def check_language(best_match, filename)
      # if there's not match, then let it go through
      return true unless best_match && best_match[2].any?
      ext = File.extname(filename).downcase
      best_match[2].any? { |language| language_has_extension(language, ext) }
    end

    # return true if the given language (as a symbol) typically has file names
    # with the given extension.  Example:  Java uses .jar, .war, .ear, .class,
    # and .java
    # The language map is usually defined in rules/openlogic/languages.yml
    def language_has_extension(language, ext)
      specific_language_list = @language_map[language]
      # if we don't know about the language, return true for now until we get
      # extremely clean language data on all rules
      !specific_language_list || specific_language_list.include?(ext)
    end

    # Given a file name and a package name that matches part of it, return a
    # best guess at the version number.
    #
    # Examples:
    #    File name            Package name   Guessed Version
    #    ------------         -------------- ---------------
    #    ant.jar              ant            unknown
    #    ant2.0.jar           ant            2.0
    #    ant-2.3.jar          ant            2.3
    #    ant_3b               ant            3b
    #    ant-2.3-beta-2.jar   ant            2.3-beta-2
    #    ant-2-3.4_2a.jar     ant-2          3.4_2a
    def guess_version(filename, best_match)
      return "unknown" unless best_match
      version = ""
      ext = File.extname(filename)
      start = false
      for i in best_match[0].size...(filename.size - ext.size)
        version << filename[i] if start || CharacterInfo.is_digit_character?(filename[i])
        start ||= (CharacterInfo.is_name_version_delimiter_character?(filename[i]) ||
            CharacterInfo.is_digit_character?(filename[i]))
      end
      version.empty? ? "unknown" : version
    end

    # print the tree to the console as plain text
    def print
      print_node(@root)
    end

    # print the given node and all children to the console in plain text
    def print_node(node_index, indent = 0, left_right = '')
      node = get_node(node_index)
      puts "#{node_index.to_s.rjust(3)}#{' ' * indent}#{left_right}#{node[KEY].chr}#{node[VALUE] ? (' --> ' + node[VALUE].to_s) : ''}"
      print_node(node[EQUAL_CHILD], indent + 1, '=') if node[EQUAL_CHILD]
      print_node(node[LEFT_CHILD],  indent + 1, '<') if node[LEFT_CHILD]
      print_node(node[RIGHT_CHILD], indent + 1, '>') if node[RIGHT_CHILD]
    end

    # generate a .dot file for use in graphing
    def save_to_dot(file_name)
      File.open(file_name, "w") do |file|
        file.puts(print_to_dot)
      end
    end

    # print the tree in dot format
    def print_to_dot
      lines = []
      print_node_to_dot(lines, @root, '=')
      'digraph G { ' << lines.join(';') << '}'
    end

    # print the given node and all children in dot format
    def print_node_to_dot(lines, node_index, left_right = '')
      node = get_node(node_index)
      if node[VALUE]
        node_attrs = %{\\n(#{node[VALUE]})", color=aquamarine, style=filled}
      elsif left_right == '='
        node_attrs = %{", color=yellow, style=filled}
      else
        node_attrs = '"'
      end
      lines << %(n#{node_index} [label="#{node[KEY].chr}#{node_attrs}])
      lines << "n#{node_index} -> n#{node[EQUAL_CHILD]}" if node[EQUAL_CHILD]
      lines << "n#{node_index} -> n#{node[LEFT_CHILD]}" if node[LEFT_CHILD]
      lines << "n#{node_index} -> n#{node[RIGHT_CHILD]}" if node[RIGHT_CHILD]
      print_node_to_dot(lines, node[EQUAL_CHILD], '=') if node[EQUAL_CHILD]
      print_node_to_dot(lines, node[LEFT_CHILD],  '<') if node[LEFT_CHILD]
      print_node_to_dot(lines, node[RIGHT_CHILD], '>') if node[RIGHT_CHILD]
    end

    # load the tree from a flat text file containing one string per line
    def load_from_simple_test_file(file_name)
      IO.foreach(file_name) do |id|
        id.strip!
        put(id, id)
      end
    end

    # load the tree from a rules file that looks like this: projectid;Project
    # Name;aliasid1,aliasid2,...;language1,language2,... Where:
    #   projectid - the id to report when a match is found - [a-z0-9_+-]
    #   Project Name - optionally reported to users - anything but a ;
    #   aliasids - look for file names that match these aliases, one of which
    #              is almost always identical to the projectid - [a-z0-9_+-]
    #   languages - programming languages (e.g., java, c++) - used to determine
    #               which file extensions are relevant - must exactly match a
    #               known value as determined in (TODO - do something with languages)
    #   namespaces - currently only used for Java projects - used to match against
    #                class files inside a jar (e.g., org.apache.commons.collections)
    def load_from_file(file_name)
      count = 0
      IO.foreach(file_name) do |line|
        begin
          package_id, aliases, languages, namespaces = line.split(PROJECT_DELIMITER)
          load_from_details(package_id, aliases, languages, namespaces.strip)
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

    # Load a single line of data from a file into the tree
    def load_from_details(package_id, aliases, languages, namespaces)
      language_symbols = languages.split(LANGUAGE_DELIMITER).reject { |language| language == "none" }.collect { |language| language.to_sym }
      aliases.split(ALIAS_DELIMITER).each do |project_alias|
        put(project_alias, [project_alias, package_id, language_symbols])
      end
    end

    # attempt to get a wider, bushier tree by seeding with some starting nodes
    # separated nicely across the alphabet
    def seed_tree(max_key_length = 4)
      seed_tree_recursive('', max_key_length, 'mfs')
    end

    def seed_tree_recursive(prefix, num_chars, key_chars)
      if num_chars == 0
        put(prefix, nil)
      else
        for i in 0...key_chars.size
          seed_tree_recursive(prefix + key_chars[i].chr, num_chars - 1, key_chars)
        end
      end
    end
  end

  # a simple class used to analyze a particular character for certain
  # characteristics, pardon the pun
  class CharacterInfo
    STOP_CHARACTER = '.'[0]
    MIN_RESET_CHARACTER = 'a'[0]
    MAX_RESET_CHARACTER = 'z'[0]
    MIN_DIGIT_CHARACTER = '0'[0]
    MAX_DIGIT_CHARACTER = '9'[0]
    NAME_VERSION_DELIMITER_CHARACTERS = ['_'[0], '-'[0], '.'[0]]

    @@current_character = nil

    def self.current_character
      @@current_character
    end

    def self.current_character=(ch)
      @@current_character = ch
    end

    def self.reset_character?
      @@current_character >= MIN_RESET_CHARACTER &&
        @@current_character <= MAX_RESET_CHARACTER
    end

    def self.stop_character?
      @@current_character == STOP_CHARACTER
    end

    def self.is_name_version_delimiter_character?(ch)
      NAME_VERSION_DELIMITER_CHARACTERS.include?(ch)
    end

    def self.is_digit_character?(ch)
      ch >= MIN_DIGIT_CHARACTER && ch <= MAX_DIGIT_CHARACTER
    end
  end
end