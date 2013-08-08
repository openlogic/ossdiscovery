require 'ternary_search_tree'
tst = TernarySearchTree.new
tst.load_from_simple_test_file('../../test/resources/rules/test_file_names/olex.list')
tst.save_to_dot('test.dot')

