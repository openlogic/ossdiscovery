require 'package'
require 'rexml/document'
require 'pathname'
require 'fileutils'
require 'zip/stdrubyext'
require 'zip/ioextras'
require 'zip/zip'
require 'zip/zipfilesystem'
require 'zip/tempfile_bugfixed'

begin
  # if Java is available, we can use it to open zip files as it's more reliable
  # than Ruby's zip library
  require 'java'
  JAVA_AVAILABLE = true unless defined?(JAVA_AVAILABLE)
rescue LoadError
  JAVA_AVAILABLE = false unless defined?(JAVA_AVAILABLE)
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
      package.found_at = reportable_location(path, archive_parents)
      package.file_name = path_inside_archive
      package.version = get_version(matches)
      package.archive = File.basename(path)
      discovered_packages << package
    end
  end

  # Get the version from the manifest file or Maven POM file only if we
  # matched a single package in the archive, otherwise set it to "unknown".
  # If we have both a manifest file with a version and a Maven POM file with
  # version, they have to match otherwise we play it safe and say "unknown".
  def self.get_version(matches)
    (matches.size == 1 && get_reported_version(@@manifest_version, @@maven_pom_version)) || "unknown"
  end

  # given an array of versions, choose the best, if any to report to users
  # for now, there can only be two and they have to match
  def self.get_reported_version(*versions)
    # either can be nil
    return versions[0] unless versions[1]
    return versions[1] unless versions[0]

    # if both have values, they must match
    versions[0] == versions[1] ? versions[0] : nil
  end

  # As opposed to the method above, this is called on a new archive that has not
  # been opened by this class.  It opens the given archive and attempts to get
  # a file name out of it by looking at the manifest and/or POM files, if any.
  def self.try_to_get_version(package_name, path, archive_parents = [])
    info = get_info_from_zip(path)
    version = get_reported_version(*info[0].values)
    if version
      record_version_match(package_name, version, path, archive_parents = [])
    end
  end
    
  # Record the version we found when opening a "cold" archive
  def self.record_version_match(package_name, version, path, archive_parents = [])
    package = Package.new
    package.name = package_name
    package.found_at = File.dirname(path)
    package.file_name = File.basename(path)
    package.version = version
    discovered_packages << package
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
    info = get_info_from_zip(zip_path)
    info[1].find_all { |path| is_class_file?(path) }
  end

  # return an array of arrays that represents the table of contents for the given zip file
  # plus additional information like this:
  # [{:manifest_version => "2.3", :pom_version => "2.3.1"}, ["org/apache/commons/collections/Thing.class", ...] ]
  def self.get_info_from_zip(path)
    # if we're running on JRuby, we prefer to use Java for looking inside of
    # jars because the Ruby zip library has seemingly random issues reading the
    # contents of certain jar files.
    if JAVA_AVAILABLE
      info = get_info_from_zip_via_java(path)
    else
      info = get_info_from_zip_via_ruby(path)
    end

    # pull out some version information
    @@manifest_version = info[0][:manifest_version]
    @@maven_pom_version = info[0][:pom_version]

    # order the paths alphabetically as you can't be sure of the order that comes
    # back when reading from the archive table of contents
    info[1].sort!
    info
  end

  # return an array of arrays that represents the table of contents for the given zip file
  # using Java libraries plus additional information like this:
  # [{:manifest_version => "2.3", :pom_version => "2.3.1"}, ["org/apache/commons/collections/Thing.class", ...] ]
  def self.get_info_from_zip_via_java(path)
    info = [{}, []]
    paths = info[1]
    begin
      # this spews out a bunch of Java debug to the console even though no debug
      # flags are set and no exceptions are thrown, so I'm commenting all this
      # out and using zip input stream instead - we'll have to re-investigate
      # when it's time to look at manifest files
      # #jar_input_stream = java.util.jar.JarInputStream.new(java.io.FileInputStream.new(path), false)
      # #entry = jar_input_stream.next_jar_entry
      zip_file = java.util.zip.ZipFile.new(path)
      zip_file.entries.each do |entry|
        name = entry.name
        paths << name
        if is_manifest_file?(name)
          info[0][:manifest_version] = get_version_from_manifest(read_java_input_stream(zip_file.get_input_stream(entry)))
        end
        if is_maven_pom_file?(name)
          info[0][:pom_version] = get_version_from_maven_pom(read_java_input_stream(zip_file.get_input_stream(entry)))
        end
      end
    rescue java.io.IOException => e
      puts "Java ZipInputStream could not examine the contents of class file archive: #{path} because #{e.inspect}:  #{e.backtrace}"
    ensure
      zip_file.close if zip_file rescue nil
    end
    info
  end

  # Return an array of arrays that represents the table of contents for the given zip file
  # using Ruby libraries plus additional information like this:
  # [{:manifest_version => "2.3", :pom_version => "2.3.1"}, ["org/apache/commons/collections/Thing.class", ...] ]
  def self.get_info_from_zip_via_ruby(path)
    info = [{}, []]
    paths = info[1]
    begin
      Zip::ZipFile.open(path) do |zip_file|
        zip_file.entries.each do |entry|
          name = entry.name
          paths << name
          if is_manifest_file?(name)
            info[0][:manifest_version] = get_version_from_manifest(read_ruby_zip_entry(entry))
          end
          if is_maven_pom_file?(name)
            info[0][:pom_version] = get_version_from_maven_pom(read_ruby_zip_entry(entry))
          end
        end
      end
    rescue Exception => e
      puts "ruby unzip could not examine contents of class file archive: #{path} because #{e.inspect}:  #{e.backtrace}"
    end
    info
  end

  # return true if the given file name is a jar file's manifest file
  def self.is_manifest_file?(name)
    name == "META-INF/MANIFEST.MF"
  end

  # return true if the given file name is a jar file's optional Maven POM file
  def self.is_maven_pom_file?(name)
    name =~ %r{^META-INF/maven/.*/pom\.xml$}
  end

  # look through a manifest file to pull out the version, if any
  def self.get_version_from_manifest(manifest)
    /Implementation-Version:\s(.*)$/ =~ manifest
    version = $1
    # let's see if the version is too long
    if version && version.length > 10
      # it is, so let's try to split it at the first " ", if any
      if space = version.index(" ")
        version = version[0...space]
      end
    end
    version.strip.gsub(/"/, "") if version
  end

  # look through a Maven POM file to pull out the version, if any
  def self.get_version_from_maven_pom(pom)
    doc = REXML::Document.new(pom)
    version_node = doc.root.elements["version"]
    version_node ? version_node.text.strip.gsub(/"/, "") : nil
  end

  # fully read the given input stream into a string
  def self.read_java_input_stream(is)
    reader = java.io.BufferedReader.new(java.io.InputStreamReader.new(is))
    text = ""
    while line = reader.read_line
      text << line << "\n"
    end
    text
  end

  # read the given ZipFileEntry into a string
  def self.read_ruby_zip_entry(entry)
    text = ""
    entry.get_input_stream do |is|
      buf = ""
      while buf = is.sysread(32768, buf)
        text << buf
      end
    end
    text
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
    @@manifest_version = nil
    @@maven_pom_version = nil
  end
end