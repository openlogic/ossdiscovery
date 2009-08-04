require 'rbconfig'
require 'digest/md5'

module Utils
  module_function

  # show a number like 131165 as 131,165
  def number_with_delimiter(number, delimiter=",", separator=".")
    begin
      parts = number.to_s.split('.')
      parts[0].gsub!(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{delimiter}")
      parts.join separator
    rescue
      number
    end
  end

  # show elapsed time like "almost a minute" or "about 2 hours" instead of just
  # a large number of seconds
  def elapsed_time(from_time, include_seconds = false)
    from_time = from_time.to_time if from_time.respond_to?(:to_time)
    to_time = Time.new
    distance_in_minutes = (((to_time - from_time).abs)/60).round
    distance_in_seconds = ((to_time - from_time).abs).round

    case distance_in_minutes
    when 0..1
      return distance_in_minutes == 0 ?
        "less than a minute" :
        "%i minutes" % distance_in_minutes unless include_seconds

      case distance_in_seconds
      when 0..4   then "less than 5 seconds"
      when 5..9   then "less than 10 seconds"
      when 10..19 then "less than 20 seconds"
      when 20..39 then "half a minute"
      when 40..59 then "almost a minute"
      else             "1 minute"
      end

    when 2..44           then "%i minutes" % distance_in_minutes
    when 45..89          then "about %i hours" % 1
    when 90..1439        then "about %i hours" % (distance_in_minutes.to_f / 60.0).round
    when 1440..2879      then "%i days" % 1
    when 2880..43199     then "%i days" % (distance_in_minutes / 1440).round
    when 43200..86399    then "about %i months" % 1
    when 86400..525599   then "%i months" % (distance_in_minutes / 43200).round
    when 525600..1051199 then "about %i years" % 1
    else                      "over %i years" % (distance_in_minutes / 525600).round
    end
  end

  # get the major platform on which this instance of the app is running.
  # possible return values are: linux, solaris, windows, macosx
  def major_platform
    @@major_platform ||= case RUBY_PLATFORM
    when /linux/     # ie: x86_64-linux
      "linux"
    when /solaris/   # ie: sparc-solaris2.8
      "solaris"
    when /mswin/     # ie: i386-mswin32
      "windows"
    when /darwin/    # ie: powerpc-darwin8.10.0
      "macosx"
    when /cygwin/
      "cygwin"
    when /freebsd/
      "freebsd"
    when /java/      # JRuby returns java regardless of platform so we need to turn this into a real platform string

      case RbConfig::CONFIG['host_os']
      when "Mac OS X", "darwin"
        # "host_os"=>"Mac OS X",
        "macosx"

      when /inux/
        # "host_os"=>"Linux",  # some platforms return "linux" others "Linux"
        "linux"

      when /Windows/
        "jruby-windows"

      when /mswin32/
        "jruby-windows"

      when /SunOS/
        "solaris"

      when /freebsd/i
        "freebsd"
      end

    end
  end

  # fully read the given input stream into a string
  def read_java_input_stream(is)
    reader = java.io.BufferedReader.new(java.io.InputStreamReader.new(is))
    text = ""
    while line = reader.read_line
      text << line << "\n"
    end
    reader.close
    is.close
    text
  end

  # compute a checksum for the given string
  def get_checksum(text)
    Digest::MD5.hexdigest(text)
  end

  # Return the contents of the given rules file in a string
  def load_openlogic_rules_file(file_name)
    load_file_in_jar("rules/openlogic/#{file_name}")
  end

  # Return the contents of the given config file in a string
  def load_openlogic_config_file(file_name)
    load_file_in_jar("conf/#{file_name}")
  end

  # Return the contents of the given olex plugin config file in a string
  def load_openlogic_olex_plugin_config_file(file_name)
    load_file_in_jar("plugins/olex/conf/#{file_name}")
  end

  # Return the contents of the given file path that represents a file inside the
  # jar that contains our application, or nil if the file could not be found or
  # loaded for some reason.
  def load_file_in_jar(path)
    begin
      # Use some ugly JRuby syntax to grab a reference to our Main class, which
      # is written in Java, so we can then get it's "java_class", which tells
      # JRuby that we really want access to the underlying Java and not just a
      # Ruby-esque wrapper.  From there we can get to the Java class loader that
      # knows how to find stuff in the jar in which we live.  That class loader
      # can then give us a stream to the file we want in the jar.
      is = Java::lib.Main.new.java_class.class_loader.get_resource_as_stream(path)
      if is
        read_java_input_stream(is)
      else
        nil
      end
    rescue Exception, java.io.IOException => e
      puts "problem loading #{path} from jar: #{e.inspect}"
      nil
    end
  end

end