# eval_rule.rb
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
#

require 'expression'

=begin rdoc
  this class encapsulates the information held in a project's eval rule
  
  something like a scan rule file eval entry:
  		<eval rule="versionstring" speed="2" />
  		
=end

class EvalRule
  attr_reader :expression, :speed
  
  def initialize( expression, speed )
    @expression = expression
    self.expression=(expression)
    @speed = speed
    @evalrulesets = ""
  end
  
  def expression=(e)
    @expression = e
    @expression.gsub!(" or ", " OR ")
    @expression.gsub!(" and ", " AND ")
    @expression.gsub!(" not ", " NOT ")
  end
  
=begin rdoc
  this method is useful to extract an array of names that are in the expression.  this is 
  useful for finding which rulesets are valid for a particular eval rule for example.
  
  this method returns an array of names used in the rule
=end

  def get_rule_names()
    # boil the expression down to just the rulesets that are in it
    return BooleanExpression.get_operands(@expression)
  end
  
end