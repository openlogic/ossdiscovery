# expression.rb
#
# LEGAL NOTICE
# -------------
# 
# OSS Discovery is a tool that finds installed open source software.
#    Copyright (C) 2007-2009 OpenLogic, Inc.
#  
# OSS Discovery is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License version 3 as 
# published by the Free Software Foundation.  
#  
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License version 3 (discovery2-client/license/OSSDiscoveryLicense.txt) 
# for more details.
#  
# You should have received a copy of the GNU Affero General Public License along with this program.  
# If not, see http://www.gnu.org/licenses/
#  
# You can learn more about OSSDiscovery, report bugs and get the latest versions at www.ossdiscovery.org.
# You can contact the OSS Discovery team at info@ossdiscovery.org.
# You can contact OpenLogic at info@openlogic.com.
# --------------------------------------------------------------------------------------------------


=begin rdoc
  this class implements the logic necessary to evaluate Scan Rules logical expressions that
  are found in rule sets (combination of matchrules outcomes) and projects (combination of rulesets outcomes)
=end

class BooleanExpression
  
  AND_ALL = "AND-ALL"
  OR_ALL  = "OR-ALL"
  
  @@count = 0
  
  attr_accessor :expression, :name
  
  def initialize

  end  
  
=begin rdoc
  this method takes a rule evaluation expression like:
  
  (httpd AND htpasswd) OR (executables AND versionstring)
  
  and a Hash of name/value pairs and evaluates the expression returning a true or false
  
  The name/value pairs typically get harvested by evaluating MatchRules or other items by the
  RuleEngine and the structure might look something like this:
  
  name_value_pairs = { "httpd" => true, "htpasswd" => true, "executables" => false, "versionstring" => true }
  
  So, the name is the name of the rule in the expression like 'httpd' - the name will get substituted
  with the value for the name and the whole expression evaluated.
  
  Possible errors can be generated if the hash of name/value pairs doesn't include a name or an improper
  value for every element represented in the expression
  
=end
  
  def evaluate( the_expression, name_value_pairs )
    @@count = @@count + 1
    @expression = create_expression_to_eval(the_expression, name_value_pairs)
    return eval( @expression )
  end
  
  def create_expression_to_eval(the_expression, name_value_pairs)
    # TODO - at some point we should probably add a syntax validation step to this
    
    @expression = " "
    @expression << the_expression
    
    # translate the English logical operators to their Ruby equivalents    
    @expression.gsub!( "AND", " && " )
    @expression.gsub!( "OR", " || " )
    @expression.gsub!( "NOT", " ! " )
    @expression.gsub!( "(", " ( " )
    @expression.gsub!( ")", " ) " )
    @expression << " "
    
    
    # translate the rule names to their boolean outcomes
    name_value_pairs.each_pair { | name, value |
      @expression.gsub!( " #{name} ", value.to_s )
    }
    
    # we now have string composed of boolean operations that can be evaluated directly by Ruby
    # it's a string that will look something like this:
    #
    #  "(false && true) || (true && false)"
    #
    # the result of evaluating this will be a boolean that corresponds to the evaluation of the
    # rule sets or match rules
    return @expression
  end

=begin rdoc
  evaluate the current expression. The current expression is set by expression=
=end
  def evaluate_exp( name_value_pairs )
    if ( @expression != nil && @expression != "" )
      return evaluate( @expression, name_value_pairs )
    else
      return false
    end
  end

  
  def BooleanExpression.get_alternating_expr(names, alt_str="AND")
    result_expression = ""
    names.each { |name|
      result_expression << name << " #{alt_str} "
    }
    result_expression = result_expression[0..(result_expression.rindex(" #{alt_str} ")-1)]
    return result_expression
  end
  
  def BooleanExpression.get_or_all_expr(names)
    return BooleanExpression.get_alternating_expr(names, "OR");
  end
  
  def BooleanExpression.get_and_all_expr(names)
    return BooleanExpression.get_alternating_expr(names, "AND");
  end
  
  def BooleanExpression.get_operands(the_expression="")
    if (the_expression == nil) then 
      the_expression = ""
    end
    # boil the expression down to just the operands that are in it
    operands = "" << the_expression
    operands.gsub!("(","")
    operands.gsub!(")","")
    operands.gsub!("AND", "")
    operands.gsub!("OR", "")
    operands.gsub!("NOT", "")
    
    return operands.split(" ")
  end
  
  def BooleanExpression.get_evaluate_call_count()
    return @@count
  end
  
  def BooleanExpression.is_verbose_or_all(expression)
    val = false
    if (expression.include?("AND") || expression.include?("&&") || expression.include?("NOT") || expression.include?("!"))
      val = false
    else
      val = true
    end
    
    return val
  end
 
end
