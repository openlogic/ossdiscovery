package lib;

import org.jruby.Ruby;
import org.jruby.RubyRuntimeAdapter;
import org.jruby.javasupport.JavaEmbedUtils;  
import java.util.ArrayList;

// This technique for starting JRuby is taken from
// http://wiki.jruby.org/wiki/Direct_JRuby_Embedding
/*
public class Main {
  public static void main(String[] args) {
    Ruby runtime = JavaEmbedUtils.initialize(new ArrayList());
    RubyRuntimeAdapter evaler = JavaEmbedUtils.newRuntimeAdapter();
    evaler.eval(runtime, "require 'lib/application_bootstrap'");
    JavaEmbedUtils.terminate(runtime);
  }
}
*/

/* Alternative implementation - allows for command line parameters, but may be more
 * brittle between JRuby versions. */
public class Main {
  public static void main(String[] args) {
    String[] jrubyArgs = new String[2 + args.length];
    //jrubyArgs[0] = "-J-Xms256m";
    //jrubyArgs[1] = "-J-Xmx256m";
    jrubyArgs[0] = "-e";
    jrubyArgs[1] = "require 'lib/application_bootstrap'";
    for (int i = 2; i < 2 + args.length ; i++) {
       jrubyArgs[i] = args[i - 2];
    }
     org.jruby.Main.main(jrubyArgs);
  }
}
