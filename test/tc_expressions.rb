require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), "..", "main", "lib")

require 'expression.rb'

=begin rdoc
  This set of test cases will shake down the BooleanExpression class which can take expressions such as
  those defined in a rule set like:  (httpd AND htpasswd) OR (executables AND versionstring)
  and a hash of name/value pairs and evalue the rule.  These test cases check evaluation results as
  well as the translated ruby evaluation string after the value substitutions have been made by the 
  BooleanExpression class
=end

class TcExpressions < Test::Unit::TestCase
  
  def setup
    @booleval = BooleanExpression.new
  end
  
  def teardown
    
  end
  
=begin rdoc
  test to see if expression evaluation string is correct after the translation (evaluation) has occurred.
  The BooleanExpression class will take an expression and a hash of name/value pairs and turn it into
  a ruby expression that can be evaluated to true or false.  The ruby expression is really the intermediate
  value and typically isn't ever used by an application, but it does determine the outcome of the evaluation
  so it's critical to make sure the string substitutions were done correctly
=end
  def test_expression_translation
assert false
     name_value_pairs = { "httpd" => true, "htpasswd" => true, "executables" => true, "versionstring" => true }
     test_expression = "(httpd AND htpasswd) OR (executables AND versionstring)"
     
     @booleval.evaluate( test_expression, name_value_pairs )
     assert_equal(eval("(true && true) || (true && true)"), eval(@booleval.expression) )
#     assert_equal("(true && true) || (true && true)", eval(@booleval.expression) )
     
     name_value_pairs["httpd"] = false
     name_value_pairs["versionstring"] = false
     
     @booleval.evaluate( test_expression, name_value_pairs )
     assert_equal( eval("(false && true) || (true && false)"), eval(@booleval.expression) ) 
     
  end

=begin rdoc
  test to see if all AND expressions given true operands will evaluate to true
=end  
  def test_expressions_and_true
    
    name_value_pairs = { "httpd" => true, "htpasswd" => true, "executables" => true, "versionstring" => true }
    
    ["(httpd AND htpasswd)", 
      "httpd AND htpasswd", 
      "executables AND versionstring", 
      "(executables) AND (versionstring)"].each { | expression |
      
      assert( @booleval.evaluate( expression, name_value_pairs ) )
    }
    
  end
  
  

=begin rdoc
  test to see if all AND expressions given false operands will evaluate to false
=end  
  def test_expressions_and_false

    name_value_pairs = { "httpd" => false, "htpasswd" => false, "executables" => false, "versionstring" => false }

    ["(httpd AND htpasswd)", 
      "httpd AND htpasswd", 
      "executables AND versionstring", 
      "(executables) AND (versionstring)"].each { | expression |

      assert( ! @booleval.evaluate( expression, name_value_pairs ) )
    }

  end  

=begin rdoc
  test to see if all AND expressions given one true and one false operand evaluates to false
=end  
  def test_expressions_and_mixed_operands_false

    name_value_pairs = { "httpd" => true, "htpasswd" => false, "executables" => true, "versionstring" => false }

    ["(httpd AND htpasswd)", 
      "httpd AND htpasswd", 
      "executables AND versionstring", 
      "(executables) AND (versionstring)"].each { | expression |

      assert( ! @booleval.evaluate( expression, name_value_pairs ) )
    }

  end
 
  
   def test_expression_with_vals_that_have_substrings_of_other_vals
     the_expression = "httpd OR httpsd OR httpsd_prefork OR httpsd_worker"
     name_value_pairs = Hash["httpsd_prefork"=>true, "httpsd"=>false, "httpsd_worker"=>true, "httpd"=>false]
     
     exp_str = @booleval.create_expression_to_eval(the_expression, name_value_pairs)
     assert_equal("false || false || true || true", exp_str)
     
   end
   
   def test_get_or_all_expr()
     expr = BooleanExpression.get_or_all_expr(["THING_1", "THING_2", "THING_3"])
     assert_equal("THING_1 OR THING_2 OR THING_3", expr)
   end
   
   def test_get_and_all_expr()
     expr = BooleanExpression.get_and_all_expr(["THING_1", "THING_2", "THING_3"])
     assert_equal("THING_1 AND THING_2 AND THING_3", expr)
   end
   
   def test_is_verbose_or_all
     assert BooleanExpression.is_verbose_or_all("A OR B OR C OR D")
     assert BooleanExpression.is_verbose_or_all("(A OR B) OR (C OR D)")
     assert !BooleanExpression.is_verbose_or_all("A AND B OR C OR D")
     assert !BooleanExpression.is_verbose_or_all("A && B OR C OR D")
     assert !BooleanExpression.is_verbose_or_all("NOT A")
     assert !BooleanExpression.is_verbose_or_all("!A")
   end
   
   def test_evaluate_exp_with_nothing_params()
     @booleval.expression = nil
     assert(!@booleval.evaluate_exp(nil))
     
     @booleval.expression = ""
     assert(!@booleval.evaluate_exp(nil))
   end
   
end
