require 'pathname'
require 'fileutils'
require 'zip/stdrubyext'
require 'zip/ioextras'
require 'zip/zip'
require 'zip/zipfilesystem'
require 'zip/tempfile_bugfixed'

begin
  # if we're running under JRuby use the apache httpclient for https posts
  require 'java'
  # #require "#{ENV['OSSDISCOVERY_HOME']}/jruby/lib/commons-httpclient-3.1.jar"
  JAVA_AVAILABLE = true
rescue LoadError
  JAVA_AVAILABLE = false
end


# Look inside the given class file archive to see if we can recognize anything
# inside of it.  For example, see if we detect
# "org/apache/commons/collections/whatever.class".  We might also look in a
# manifest file, if any can be found, or do other Java-specific discovery.
class ClassFileArchiveDiscoverer
  # Look inside the given class file archive to see if we can recognize anything
  # inside of it.  For example, see if we detect
  # "org/apache/commons/collections/whatever.class".  We might also look in a
  # manifest file, if any can be found, or do other Java-specific discovery.
  # Return a map of { package_id => path_inside_archive } where we only report
  # the first path inside the archive that we come across matching each
  # particular package.  We use a map because it's possible to find more than
  # one known package inside a single archive.
  def self.discover(path, archive_parents = [])
    matches = {}
    get_class_file_paths(path).each do |class_file_path|
      # see if we know which package this class file belongs to
      package = class_file_name_match(class_file_path)
      # put our matches in a hash so we don't report each package more than once
      # for this class file archive
      matches.merge!(package => class_file_path) { |key, old, new| old } if package
    end
    record_matches(matches, path, archive_parents)
  end

  # Take a map of { package_id => path_inside_archive }, the path to our
  # archive, and an array of archive parents (including the one we're in) and
  # remember what we found in terms suitable for reporting to a user later.
  def self.record_matches(matches, path, archive_parents)
    # now make sure our matches are remembered
    matches.each do |package_name, path_inside_archive|
      package = Package.new
      package.name = package_name
      package.version = "unknown"
      package.found_at = reportable_location(path, archive_parents)
      package.file_name = path_inside_archive
      package.archive = File.basename(path)
      discovered_packages << package
    end
  end

  # Given a path to a .class file inside an archive, return either the package
  # that the .class file belongs to or nil. Example: given
  # "org/apache/commons/collections/blah.../some.class", return
  # "commons-collections"
  def self.class_file_name_match(class_file_path)
    SearchTrees.match_class_file_path(class_file_path)
  end

  # return a list of all class file paths inside the archive
  def self.get_class_file_paths(zip_path)
    paths = get_paths_from_zip(zip_path)
    paths.find_all { |path| is_class_file?(path) }
  end

  # return an array that represents the table of contents for the given zip file
  def self.get_paths_from_zip(path)
    # if we're running on JRuby, we prefer to use Java for looking inside of
    # jars because the Ruby zip library has seemingly random issues reading the
    # contents of certain jar files.
    if JAVA_AVAILABLE
      paths = get_paths_from_zip_via_java(path)
    else
      paths = get_paths_from_zip_via_ruby(path)
    end
    paths.sort
  end

  # return an array that represents the table of contents for the given zip file
  # using Java libraries
  def self.get_paths_from_zip_via_java(path)
    paths = []
    begin
      # this spews out a bunch of Java debug to the console even though no debug
      # flags are set and no exceptions are thrown, so I'm commenting all this
      # out and using zip input stream instead - we'll have to re-investigate
      # when it's time to look at manifest files
      # #jar_input_stream = java.util.jar.JarInputStream.new(java.io.FileInputStream.new(path), false)
      # #entry = jar_input_stream.next_jar_entry
      zip_input_stream = java.util.zip.ZipInputStream.new(java.io.FileInputStream.new(path))
      while entry = zip_input_stream.next_entry
        paths << entry.name
      end
    rescue java.io.IOException => e
      puts "Java ZipInputStream could not examine the contents of class file archive: #{path} because #{e.inspect}:  #{e.backtrace}"
    ensure
      zip_input_stream.close if zip_input_stream rescue nil
    end
    paths
  end

  # return an array that represents the table of contents for the given zip file
  # using Ruby libraries
  def self.get_paths_from_zip_via_ruby(path)
    paths = []
    begin
      Zip::ZipFile.open(path) do |zip_file|
        zip_file.entries.each do |entry|
          paths << entry.name
        end
      end
    rescue Exception => e
      puts "ruby unzip could not examine contents of class file archive: #{path} because #{e.inspect}:  #{e.backtrace}"
    end
    paths
  end

  # Return a location that includes a potential chain of archive parents along
  # with a given directory.  For example, if web-inf/lib/ant.jar is found in
  # myapp.war which in turn is found in /deploy/bigproj.ear, the result will
  # look like this:
  #   /deploy/bigproj.ear!/myapp.war!/web-inf/lib/ant.jar
  # NOTE: we can't re-use Package.reportable_location because of our special
  # treatment of class file archive location reporting.
  def self.reportable_location(dir, archive_parents)
    if archive_parents.empty?
      dir
    else
      parents = archive_parents.collect { |parent| parent[0] }.join('!')
      # handle the special case where the class file archive is at the top 
      # level of a parent archive and therefore we could wind up with two
      # "/"'s next to each other
      (ends_with?(parents, "/") ? parents[0..-2] : parents) + "!"
    end
  end

  # Return true if the given file name ends with ".class"
  def self.is_class_file?(file_name)
    ends_with?(file_name, ".class")
  end

  # Return true if the given source string ends with the given target string
  def self.ends_with?(source, target)
    source.rindex(target) == source.size - target.size
  end

  # Provide access to everything we've found in this class
  def self.discovered_packages
    @@discovered_packages ||= Set.new
  end

  # Forget everything we've found so far and prepare for a fresh start
  def self.reset
    discovered_packages.clear
  end
end