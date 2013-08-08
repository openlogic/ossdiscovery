 require 'java'
 
 puts "JAVA SYSTEM PROPERTIES"
 java.lang.System.getProperties().list(java.lang.System.out);
 # you can get at the individual properties if you want like this...
 #   java_version = java.lang.System.get_property("java.version") 
 # which is the same as...
 #   java_version = Java::JavaLang::System.getProperty