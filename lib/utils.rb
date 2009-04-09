require 'rbconfig'

module Utils
  module_function
  def number_with_delimiter(number, delimiter=",", separator=".")
    begin
      parts = number.to_s.split('.')
      parts[0].gsub!(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{delimiter}")
      parts.join separator
    rescue
      number
    end
  end

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
end