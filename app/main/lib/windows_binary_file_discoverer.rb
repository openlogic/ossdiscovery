require 'package'
require 'utils'
require 'pathname'
require 'fileutils'

# Look inside the given Windows binary file to see if we can recognize anything
# inside of it.  For example, see if we detect a reference to "webkit.dll".
class WindowsBinaryFileDiscoverer
  # the helper executable we call to extract DLL information from a Windows
  # binary file (e.g., .exe, .dll)
  @@binary_inspector = nil

  # Return a map of { package_id => dll_reference } where we only report
  # the first path inside the archive that we come across matching each
  # particular package.  We use a map because it's possible to find more than
  # one known package inside a single binary.
  def self.discover(path, archive_parents = [])
    matches = {}
    get_dlls(path).each do |dll|
      # see if we know which package this dll belongs to
      package = SearchTrees.match_file_name(dll)
      # put our matches in a hash so we don't report each package more than once
      # for this Windows binary
      matches.merge!(package[0] => [package[1], dll]) { |key, old, new| old } if package && package[0]
    end
    record_matches(matches, path, archive_parents)
  end

  # Take a map of { package_id => dll }, the path to our binary, and an array
  # of archive parents (including the binary we're in) and remember what we
  # found in terms suitable for reporting to a user later.
  def self.record_matches(matches, path, archive_parents)
    # now make sure our matches are remembered
    matches.each do |package_name, version_and_dll|
      package = Package.new
      package.name = package_name
      package.found_at = reportable_location(path, archive_parents)
      package.file_name = version_and_dll[1]
      package.version = version_and_dll[0]
      package.archive = File.basename(path)
      discovered_packages << package
    end
  end

  # Return a list of all dll's inside the binary by calling out to a helper
  # executable and parsing its output
  def self.get_dlls(binary_path)
    result = `#{binary_inspector} "#{binary_path}"` rescue nil
    result ? result.split(/\r?\n/) : []
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
      parents + "!"
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

  # The full path to our helper executable
  def self.binary_inspector
    #@@binary_inspector ||= File.join(File.dirname(__FILE__), 'pedump.exe')
    @@binary_inspector ||= "TODO"
  end
end