require 'package'
require 'pathname'
require 'fileutils'

# Look inside the given source file to see if we can recognize anything inside
# of it.  For example, see if we detect "import org.apache.commons.collections.*".
# We might also look for package statements or do other Java-specific discovery.
class SourceFileDiscoverer

  # Look inside the given source file to see if we can recognize anything
  # inside of it.  For example, see if we detect "import org.apache.commons.collections.*".
  # We might also look for package statements or do other Java-specific discovery.
  # Return a map of { package_id => path_inside_archive } where we only report
  # the first path inside the archive that we come across matching each particular
  # package.  We use a map because it's possible to find more than one known
  # package inside a single archive.
  def self.discover(path, archive_parents = [])
    matches = {}
    get_references(path).each do |reference|
      # see if we know which package this reference refers to
      package = reference_name_match(reference[1])
      # put our matches in a hash so we don't report each package more than once
      # for this source file
      matches.merge!(package => reference[1]) { |key, old, new| old } if package
    end
    record_matches(matches, path, archive_parents)
  end

  # Take a map of { package_id => reference }, the path to our
  # source file, and an array of archive parents (including the source file
  # we're in) and remember what we found in terms suitable for reporting to a
  # user later.
  def self.record_matches(matches, path, archive_parents)
    # now make sure our matches are remembered
    matches.each do |package_name, reference|
      package = Package.new
      package.name = package_name
      package.found_at = reportable_location(path, archive_parents)
      package.file_name = reference
      package.version = "unknown"
      package.archive = File.basename(path)
      discovered_packages << package
    end
  end

  # Given a reference to open source inside a source file, return either the
  # package that the reference belongs to or nil. Example: given
  # "import org.apache.commons.collections.blah...SomeClass", return
  # "commons-collections"
  def self.reference_name_match(reference)
    SearchTrees.match_class_file_path(reference.gsub(/\./, '/'))
  end

  # Return a list of all open source references inside the source file like this:
  #   [["package", "org.apache.commons.*"], ["import", "other.pkg.Name],
  #    ["usage", "org/apache/commons/ArrayStack", ...]
  def self.get_references(source_file_path)
    text = IO.read(source_file_path)
    text.scan(/(package|import)\s+([^;\s]+)/) + text.scan(/L([\w\/]*?);/).collect { |klass_path| ["usage", klass_path[0]] }
  end

  # Return a location that includes a potential chain of archive parents along
  # with a given directory.  For example, if web-inf/lib/ant.jar is found in
  # myapp.war which in turn is found in /deploy/bigproj.ear, the result will
  # look like this:
  #   /deploy/bigproj.ear!/myapp.war!/web-inf/lib/ant.jar
  # NOTE: we can't re-use Package.reportable_location because of our special
  # treatment of source file location reporting.
  def self.reportable_location(dir, archive_parents)
    if archive_parents.empty?
      dir
    else
      parents = archive_parents.collect { |parent| parent[0] }.join('!')
      # handle the special case where the class file archive is at the top level
      # of a parent archive and therefore we could wind up with two "/"'s next
      # to each other
      ((parents[-1] == "/"[0]) ? parents[0..-2] : parents) + "!"
    end
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