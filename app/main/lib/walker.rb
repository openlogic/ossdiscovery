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


# -----------------------------------------------------------------------------
# A walker is the object which will scan directories, look for file matches and
# then notify the rule engine (or any subscriber) of a filename match.
# Multiple instances of Walkers are allowed - for example a global Walker may be
# scanning the disk, it encounters a jar file, passes that jar file to the
# RuleEngine and the rule itself decides to crack the jar, then create a walker
# for just walking the exploded jar directory contents.
# An instance of Walker is given a directory from which it will start walking
# through files and directories.  In order to walk individual directories which
# aren't nested, you must call walkDir() once for each directory.
# For example, to walk /usr, /opt, and /tmp without walking the entire root
# directory, you'd call walkDir 3 times, once for each directory off of root
# that you want scanned.  You can use the same Walker instance for each walkDir
# call or create one Walker instance for each directory - it doesn't matter.

require 'pathname'
require 'fileutils'
require 'zip/stdrubyext'
require 'zip/ioextras'
require 'zip/zip'
require 'zip/zipfilesystem'
require 'zip/tempfile_bugfixed'
require 'class_file_archive_discoverer'
require 'source_file_discoverer'

require File.join(File.dirname(__FILE__), 'conf', 'config')

# how many times we try to create a temporary directory for storing archive contents until we give up
MAX_TEMP_DIR_CREATION_RETRIES = 5 unless defined?(MAX_TEMP_DIR_CREATION_RETRIES)

# Figure out if we have an 'unzip' program on the operating system
@@unzip ||= begin
  major_platform =~ /windows/i ? "" : `which unzip`.strip
rescue
  ""
end

=begin rdoc
  an instance of Walker is given a directory from which it will start walking through
  files and directories.  In order to walk individual directories which aren't
  nested, you must call walkdir once for each directory.

  For example, to walk /usr, /opt, and /tmp without walking the entire root directory, you'd
  walkdir 3 times, once for each directory off of root that you want scanned.  You can
  use the same Walker instance for each walkdir.
=end

class Walker

  @@log = Config.log

  attr_accessor :file_ct, :dir_ct, :sym_link_ct, :bad_link_ct, :permission_denied_ct, :foi_ct, :not_found_ct, :archives_found_ct, :class_file_archives_found_ct
  attr_accessor :follow_symlinks, :symlink_depth, :not_followed_ct, :show_every, :show_verbose, :show_progress, :throttling_enabled, :throttle_number_of_files, :throttle_seconds_to_pause
  attr_accessor :open_archives, :dont_open_discovered_archives
  attr_accessor :archive_temp_dir
  attr_accessor :archive_extensions
  attr_accessor :class_file_archive_extensions, :no_class_files, :always_open_class_file_archives
  attr_accessor :examine_source_files, :source_file_extensions, :source_files_found_ct
  attr_accessor :unopenable_archive_ct
  attr_accessor :list_exclusions, :list_files, :show_permission_denied, :starttime
  attr_reader :total_seconds_paused_for_throttling

  # criteria[:]
  # is a hash of filenames or regular expressions that can match a filename.
  # the key to the hash is the string representing the criteria (the filename or regex.)
  # the value of the hash is a list of subscribers to be notified on a match for this
  # criteria.
  #
  # criteria effectively holds what are called the "files of interest" but more than that
  # handles who to notify when a file of interest is found.

  @criteria = nil

  # dir_exclusions is an array of dirs/ or regular expressions which, if matched,
  # will exclude the dir from any further processing.  The Walker will count excluded
  # files and directories for diagnostic purposes, but no subscriber will get a chance
  # to see any file that's excluded through the generic exclusion mechanism

  @dir_exclusions = nil
  @file_exclusions = nil

  # this is used to detect circular symlinks...if a file or directory to resolve is in this
  # cache, it can't be resolved again - a circular link will be reported instead by the
  # walker and the package will move on.  It's a class variable due to recursive walking.

  @@symlink_cache = {}

  # If we are running under jruby, we might as well require java so that it is available to
  # this class.
  if RUBY_PLATFORM =~ /java/
    require 'java'
  end

  def initialize()

    $stdout.sync = true        # used so progress indicators will flush to console immediately

    @file_ct = 0
    @dir_ct = 0
    @sym_link_ct = 0
    @bad_link_ct = 0
    @not_followed_ct = 0
    @foi_ct = 0
    @permission_denied_ct = 0
    @not_found_ct = 0
    @archives_found_ct = 0
    @class_file_archives_found_ct = 0
    @unopenable_archive_ct = 0
    @source_files_found_ct = 0
    @show_progress = false
    @show_permission_denied = false
    @show_verbose = false
    @throttling_enabled = false
    @total_seconds_paused_for_throttling = 0

    @criteria = Hash.new
    @dir_exclusions = Array.new   # the directory basenames to filter out
    @file_exclusions = Array.new   # the directory basenames to filter out

  end


=begin rdoc
  takes an array of exclusions such as literals or regular expressions which if
  matched to a directory that's encountered by the walker will cause that file or
  directory to be ignored.  No subscriber will ever get a chance to process a file or
  directory ignored through the generic exclusion mechanism
=end
  def add_dir_exclusions(exclusion_list)
    @dir_exclusions.concat(exclusion_list.values)

    # get all the exclusions except for temp dirs
    @no_temp_dir_exclusions = exclusion_list.reject { |key, value| key =~ /No te?mp files/ }.collect { |key_value| key_value[1] }
  end

=begin rdoc
  takes an array of exclusions such as literals or regular expressions which if
  matched to a directory that's encountered by the walker will cause that file or
  directory to be ignored.  No subscriber will ever get a chance to process a file or
  directory ignored through the generic exclusion mechanism
=end
  def add_file_exclusions( exclusion_list )
    @file_exclusions.concat( exclusion_list )
  end


=begin rdoc
  clear out the generic exclusions list
=end
  def clear_exclusions()
    @dir_exclusions.clear
    @file_exclusions.clear
  end


=begin rdoc
    this method will recursively walk the given directory.  It will compare the
    files it encounters with the filter list, both the generic filters first, and
    then the list of files gleaned from the subscribers (usually a RuleEngine instance.)
    If it finds a file of interest, it notifies the subscriber for that file match
    of the match, passes the file and location to the subscriber.

    Pass in true for override_dir_exclusions to check every file in the given
    directory.  This flag is set when opening an archive file because they will
    often be temporarily extracted to a temp dir and then have their contents
    scanned there.  If the standard temp dir exclusions applied, these archive
    contents would always be ignored.  This flag will be propagated when walking
    any nested directories.

    The archive_parents parameter is used to keep track of a hierarchy of nested
    archive files so we can report where a particular matched file actually lives.
    For example, we could find apache-ant.jar inside of myproj.war inside of
    bigproj.ear.

    returns false if given fileordir is a directory excluded by a filter
    returns true if given fileordir was walked
=end

  def walk_dir(fileordir, override_dir_exclusions = false, archive_parents = [])
    @root_scan_dir = fileordir if @root_scan_dir.nil?
    # crude progress indicator
    if ( !@show_verbose && @show_progress && @file_ct != 0 )
      q,r = @file_ct.divmod( @show_every )
      if ( r == 0 )
        putc "."
      end
    end

    if ( @show_verbose && @file_ct != 0 && @show_every != 0)
      q,r = @file_ct.divmod( @show_every )
      if ( r == 0 )
        progress_report(fileordir)
      end
    end

    # crude throttler
    if (@throttling_enabled) then
      q,r = @file_ct.divmod(@throttle_number_of_files)
      if (r == 0) then
        Kernel.sleep(@throttle_seconds_to_pause)
        @total_seconds_paused_for_throttling = @total_seconds_paused_for_throttling + @throttle_seconds_to_pause
      end
    end

    # we have a file or directory.  before we process it further we need to see if it
    # is of interest to us or if it matches a filter that indicates it should be excluded
    #
    # this is a major part of the optimized scan because there's no sense in applying rules,
    # getting MD5s or anything else on a file that is not of interest

    # if we're looking at the contents of an archive file, it will probably be
    # in a temp dir, so don't exclude the temp dir
    dir_exclusions = override_dir_exclusions ? @no_temp_dir_exclusions : @dir_exclusions

    if File.directory?(fileordir)
      dir_exclusions.each do |filter|
        if fileordir.match(filter)
          if @list_exclusions || $DEBUG
            puts "'#{fileordir}' is excluded by: #{filter} directory filter"
          end
          #  blow out of here if this file matches an exclusion condition,
          #  false because this is a directory which needs to be pruned
          return false
        end
      end
    end

    if File.file?(fileordir)
      @file_exclusions.each do |filter|
        if File.basename(fileordir).match(filter)
          if @list_exclusions || $DEBUG
            puts "'#{fileordir}' is excluded by: #{filter} file filter"
          end
          return true  # blow out of here if this file matches an exclusion condition, true because this is a file and got walked
        end
      end
    end

    # --list-files flag implementation
    # will show only files that made it through the exclusion filters

    if @list_files || $DEBUG
      puts fileordir
    end

    resolved = true

    begin
      if File.file?(fileordir)
        if File.readable?(fileordir)
          @file_ct += 1

          if is_symlink?(fileordir)
            if @follow_symlinks
              resolved, fileordir = resolve_symlink(fileordir)
            else
              resolved = false
              @sym_link_ct += 1
              @not_followed_ct += 1
            end
          end

          # see if this entry is resolvable and matches anything anyone's looking for
          if resolved
            # always match against the given file
            discovered = name_match(fileordir, archive_parents)
            file_string = fileordir.to_s

            # we didn't recognize the file, so check to see if we're supposed
            # to examine the contents of source files
            if !discovered && @examine_source_files && is_source_file?(file_string)
              @source_files_found_ct += 1
              examine_source_file(fileordir, archive_parents)
            end

            # we didn't recognize the file, so check to see if it might
            # contain class files we recognize
            if ((!discovered && !@no_class_files) || @always_open_class_file_archives) && is_class_file_archive?(file_string)
              @class_file_archives_found_ct += 1
              examine_class_file_archive(fileordir, archive_parents)
            end

            # if it's an archive file, we may also want to open it up and look
            # inside for any nested archives and other interesting files
            if @open_archives && is_archive?(file_string)
              @archives_found_ct += 1

              # open the archive now unless we already discovered something from
              # just the name of the archive
              if !discovered || !@dont_open_discovered_archives
                open_archive(fileordir, archive_parents)
              end
            end
          end
        else # the file was not readable
          increment_permission_denied_ct(fileordir)
          return false
        end
      elsif File.directory?(fileordir)
        have_perms_for_dir = true
        pwd = Dir.pwd
        begin
          Dir.chdir(fileordir)
          Dir.chdir(pwd)
        rescue Errno::EACCES, Errno::EPERM, Errno::ETIMEDOUT
          have_perms_for_dir = false
        end

        if (have_perms_for_dir) then
          @dir_ct += 1

          # list the contents of this directory (the pwd) and recursively call walkdir
          # if it's not empty
          begin
            if is_symlink?(fileordir)
              if @follow_symlinks
                # need to resolve the symlink
                resolved, fileordir = resolve_symlink(fileordir)
                # @@log.info("Walker") {"resolved: " + resolved.to_s + " fileordir: " + fileordir }
              else
                resolved = false
                @sym_link_ct += 1
                @not_followed_ct += 1
              end
            end
          rescue Exception
            # the only times we've seen this hit are when a symlink is completely orphaned => points to nothing
            # this has only occurred on a symlink found in /lost+found on Solaris.  otherwise, there's no way
            # to make a symlink like this using ln.
            @not_followed_ct += 1
            @bad_link_ct += 1
            @@log.info("Walker") {"WARNING: Bad lstat on symlink check - #{fileordir} - likely an orphaned symlink"}
            resolved = false
          end

          if resolved
            pwd = fileordir
            Dir.foreach(fileordir) do |direntry|
              # recurse into this directory if it's not current or parent directories
              if direntry != "." && direntry != ".."
                direntry = (pwd == '/' ? "/#{direntry}" : "#{pwd}/#{direntry}" )

                # check to see if we need to prune a directory
                if !walk_dir(direntry, override_dir_exclusions, archive_parents)
                  if @list_exclusions || $DEBUG
                    puts "'#{direntry}' pruned"
                  end
                end
              end
            end
          end
          return true
        else # the file was not readable
          increment_permission_denied_ct(fileordir)
          return false
        end
      end

    rescue Errno::EACCES, Errno::EPERM
      increment_permission_denied_ct(fileordir)
      return false
    rescue Errno::ENOENT, Errno::ENOTDIR
      # it may seem odd that a file that was scanned would end up not found, but it's possible that
      # a file existed and in the moments between when it was encountered and when it was scanned, was removed or moved.
      @not_found_ct += 1
      return false
    end

    true
  end

  def increment_permission_denied_ct(fileordir)
    @permission_denied_ct += 1
    if ( @show_permission_denied )
      printf("permission denied: %s\n", fileordir)
    end
  end

  def is_symlink?(fileordir)
    # If we are running under jruby, we need to use the old abs/can path to check
    # if a directory is a symlink.  Otherwise, we can use the file system.  This call
    # using the ruby File object returns false even on symlinks when running under JRuby
    is_symlink=false
    if RUBY_PLATFORM =~ /notneeded/
      java_file=java.io.File.new(fileordir)
      begin
        is_symlink = java_file.getCanonicalPath.casecmp(java_file.getAbsolutePath) != 0
      rescue java.io.IOException
        is_symlink = true
      end
    else
      is_symlink=File.lstat(fileordir).symlink?
    end
    is_symlink
  end

  # Return true if the given file name ends with an archive extension,
  # as defined through the configuration file
  def is_archive?(file_name)
    @archive_extensions.any? { |ext| ends_with?(file_name, ext) }
  end

  # Return true if the given file name ends with an archive extension that may
  # contain .class files as defined through the configuration file
  def is_class_file_archive?(file_name)
    @class_file_archive_extensions.any? { |ext| ends_with?(file_name, ext) }
  end

  # Return true if the given file name ends with ".java".  We'll add other
  # languages in the future.
  def is_source_file?(file_name)
    @source_file_extensions.any? { |ext| ends_with?(file_name, ext) }
  end

  # Return true if the given file name ends with ".class"
  def is_class_file?(file_name)
    file_name.ends_with?(".class")
  end

  # Return true if the given source string ends with the given target string
  def ends_with?(source, target)
    source.rindex(target) == source.size - target.size
  end

  # Open the given archive file and walk it
  def open_archive(path, archive_parents = [])
    # create a temporary directory to store the archive file contents
    archive_file = File.basename(path)
    target_dir = create_temp_dir(archive_file)

    # fail immediately unless the create temp dir worked
    unless target_dir
      @unopenable_archive_ct += 1
      return false
    end

    success = false
    begin
      success = unzip_file(path, target_dir)
    rescue
      @@log.info("Walker") { "\ncould not unzip archive: #{path}" }
    end

    if success
      # Walk the new temporary directory containing the archive file's contents
      # We pass 'true' as the second argument to override the temp dir exclusion
      @@log.info("Walker") { "Walking archive temp dir: #{target_dir}" }

      # if we're the topmost archive, include our full path
      if archive_parents.empty?
        archive_file = path
      else
        # otherwise, strip our most recent parent's path from our path
        archive_file = remove_parent_path(path, archive_parents.last[1])
      end
      new_parents = ([].concat(archive_parents)) << [archive_file, target_dir]
      walk_dir(target_dir, true, new_parents)

      # remove the temporary directory now that we're done with it
      @@log.info("Walker") { "Deleting archive temp dir: #{target_dir}" }
      FileUtils.rm_rf(target_dir)
    else
      @unopenable_archive_ct += 1
    end
  end

  # Given two paths such as:
  #   p1 = /tmp/solr.war20090127-32155-8pp7xr-0/WEB-INF/lib/commons-io.zip
  # and
  #   p2 = /tmp/solr.war20090127-32155-8pp7xr-0
  # return a path like this:
  #   p = /WEB-INF/lib/commons-io.zip
  def remove_parent_path(full_path, parent_path)
    full_path[parent_path.size..-1]
  end

  # unzip the zip file found at the given path into the given destination
  def unzip_file(zip_path, destination)
    @@log.info("Walker") { "unzipping file: #{zip_path} to #{destination}" }
    success = false
    unless @@unzip.empty?
      # we found unzip on the system, so try to use it
      begin
        line = "#{@@unzip} #{zip_path} -d #{destination}"
        @@log.info("Walker") { "execing unzip program:\n  #{line}" }
        `#{line} 2>&1 > /dev/null`
        success = true
      rescue Exception => e
        @@log.info("Walker") { "unzip program could not unzip archive: #{path} because #{e.inspect}" }
      end
    end

    # we may have already tried the 'unzip' program if it's installed, but if
    # it failed we might as well try the slow way in case it works
    unless success
      begin
        Zip::ZipFile.open(zip_path) do |zip_file|
          zip_file.entries.sort.each do |entry|
            entry.extract("#{destination}/#{entry}")
          end
        end
        success = true
      rescue Exception => e
        @@log.info("Walker") { "ruby unzip could not unzip archive: #{path} because #{e.inspect}" }
      end
    end

    success
  end

  # create a new temporary directory
  def create_temp_dir(name)
    # do a little footwork here to create a temporary file that is
    # guaranteed to be unique, then delete it and create a directory
    # with the same name
    final_path = nil
    failures = 0
    begin
      if archive_temp_dir
        @@log.debug("Walker") { "creating temp file in temp dir: #{archive_temp_dir}" }
        t = Tempfile.new(name, archive_temp_dir)
      else
        @@log.debug("Walker") { "creating temp file in os default temp dir" }
        t = Tempfile.new(name)
      end
      path = t.path
      @@log.debug("Walker") { "new temp file located at #{path}" }
      # this will also delete the temp file
      t.close(true)
      @@log.debug("Walker") { "about to make directories" }
      final_path = FileUtils.makedirs path, :mode => 0700
    rescue Exception => e
      @@log.debug("Walker") { "failure: #{e.inspect}" }
      failures += 1
      retry if failures < MAX_TEMP_DIR_CREATION_RETRIES
    end
    final_path
  end

  # Look inside the given class file archive to see if we can recognize anything
  # inside of it.  For example, see if we detect
  # "org/apache/commons/collections/whatever.class".  We might also look in a
  # manifest file, if any can be found, or do other Java-specific discovery.
  def examine_class_file_archive(path, archive_parents = [])
    # if we're the topmost archive, include our full path
    if archive_parents.empty?
      archive_file = path
    else
      # otherwise, strip our most recent parent's path from our path
      archive_file = remove_parent_path(path, archive_parents.last[1])
    end
    #new_parents = ([].concat(archive_parents)) << ["/", File.dirname(archive_file)]
    new_parents = ([].concat(archive_parents)) << [archive_file, archive_file]
    #new_parents = ([].concat(archive_parents)) << [archive_file, archive_file]
    #new_parents = ([].concat(archive_parents)) << [File.dirname(archive_file), File.dirname(path)]
    #new_parents = ([].concat(archive_parents)) << [File.dirname(archive_file), File.dirname(archive_file)]
    ClassFileArchiveDiscoverer.discover(path, new_parents)
  end

  # Look inside the given source file to see if we can recognize anything
  # inside of it.  For example, see if we detect
  # "import org.apache.commons.collections.*".  We might also look for package
  # statements or do other Java-specific discovery.
  def examine_source_file(path, archive_parents = [])
    # if we're the topmost "archive", include our full path
    if archive_parents.empty?
      archive_file = path
    else
      # otherwise, strip our most recent parent's path from our path
      archive_file = remove_parent_path(path, archive_parents.last[1])
    end
    new_parents = ([].concat(archive_parents)) << [archive_file, archive_file]
    SourceFileDiscoverer.discover(path, new_parents)
  end

=begin rdoc
  return true or false if the symlink could be resolved and the realpath if it can

  always returns a resolved state of false if @follow_symlinks is false

  true - link resolved to a real path
  false - link was broken or circular and could not be resolved to a real path
=end

  def resolve_symlink( fileordir )

    @@log.debug("Walker") {"\n-------------\nresolving symlink: #{fileordir}"}

    if ( @@symlink_cache[fileordir] != nil )
      # then we've seen this sym link before and we have just detected a circular
      # reference, so don't resolve this again
      @bad_link_ct += 1
      @@log.warn("Walker") {"detected circular link #{fileordir}"}
      return false, fileordir
    end

    begin

      @sym_link_ct += 1
      realpath = Pathname.new( fileordir ).realpath
      @@symlink_cache[fileordir] = realpath
      @@log.info("Walker") {"realpath: #{realpath}\n"}
      return true, realpath

    rescue Errno::ENOENT

      @bad_link_ct += 1
      return false, fileordir

    end

  end

=begin rdoc
  periodically called to show more verbose progress
=end

  def progress_report(fileordir)
    if @last_verbose_report.nil?
      @last_verbose_report = @starttime
      if @root_scan_dir_split_count.nil?
        @root_scan_dir_split_count = @root_scan_dir.split(File::SEPARATOR).size
        @root_scan_dir_split_count = 1 if @root_scan_dir_split_count == 0
      end
      now_scanning = fileordir.split(File::SEPARATOR)[0..@root_scan_dir_split_count].join(File::SEPARATOR)
      puts "\nelapsed time: #{((Time.new - @starttime).to_i)} seconds - scanning '#{now_scanning}' - walked #{dir_ct()} directories - scanned #{foi_ct()} files"
    else
      now = Time.new
      if ((now - @last_verbose_report) >= 120) then
        if (@root_scan_dir_split_count.nil?) then
          @root_scan_dir_split_count = @root_scan_dir.split(File::SEPARATOR).size
          if (@root_scan_dir_split_count == 0) then @root_scan_dir_split_count = 1 end
        end
        now_scanning = fileordir.split(File::SEPARATOR)[0..@root_scan_dir_split_count].join(File::SEPARATOR)
        puts "\nelapsed time: #{((now - @starttime).to_i / 60)} minutes - scanning '#{now_scanning}' - walked #{dir_ct()} directories - scanned #{foi_ct()} files"
        @last_verbose_report = now
      end
    end
  end

=begin rdoc
  given the filename, this code will check the list of subscribers and
  notify those subscribers whose filename criteria matches this filename
  a subscriber must have a notify method that receives filename, location
  parameters, and a potentially empty list of archive parents that contain
  the file.
=end

  def notify_subscribers(subscribers, location, filename, rule_used, archive_parents)
    any_matches = false
    subscribers.each{ |subscriber|
      any_matches ||= subscriber.found_file(location, filename, rule_used, archive_parents)
    }
    any_matches
  end


=begin rdoc
  this is the main method which compares a filename found by the walker against the list of
  files of interest to see if there's a match.  if there is a match, this code will fire the
  subscriber notification method to tell the subscriber (ie RuleEngine) a file of interest
  has been found. The archive_parents parameter gives us a path back up the archive hiearchy,
  if any, that contains the given file or directory.
  
  Return true if any rules match the given file, false otherwise.
=end
  def name_match(fileordir, archive_parents)

    # FUTURE - determine if it may be necessary to pull this optimization out and do a literal match on
    # all criteria, not just take the first match....right now, with a one-subscriber model (RuleEngine),
    # any match is going to notify the subscriber, so it's an optimization to not try to
    # find any more matches in the criteria after the first match.  Later we may not have this luxury
    # if we need to support more than one subscriber in the system.

    # do a direct/literal look up first since this will be the fastest match, do it first
    basename = File.basename(fileordir)
    dirname =  File.dirname(fileordir)

    if @criteria[basename]
      # found a literal filename match in the criteria list, so notify its subscribers
      @foi_ct += 1
      return notify_subscribers(@criteria[basename], dirname, basename, basename, archive_parents)
    end

    # no literal filename match was found - check all other match types - regex's

    # now try to match each criterion against the given filename and build a list of subscribers
    # that care - because the filename might match more than one criterion, we can't just find the
    # first match and return the subscriber list

    @criteria.each_key { | criterion |
      if basename.match(criterion)
        @foi_ct += 1
        # notify array of subscribers
        return notify_subscribers(@criteria[criterion], dirname, basename, criterion, archive_parents)
      end
    }

    false
  end

=begin rdoc
  this method receives a subscriber who is interested in a certain set of files.
  The files list may include regex's or literal filenames.  Each of the files of
  interest will be associated with one or more subscribers who are interested in
  that same file or file type.  When a file match is found, the subscriber will
  be notified.  Subscribers must support a:

  found_file( location, filename, rule_used )

  method so the walker can notify it of a found file.
=end

  def set_files_of_interest( subscriber, filelist )

    # spin through the list of files and either add it to the criteria hash if it's not already found in the hash.
    # After that, associate the subscriber with it.  The list of files of interest, @criteria, is
    # a hash key'd by the file of interest whose value is a list of subscribers to
    # notify in a found file condition.
    #
    # it's assumed that the given file list has no duplicates in it, but even if it did, they'd
    # get filtered out by virtue that the criteria is keyed by filename
    #
    # a file of interest can be a regex or a literal filename, but it's a filename
    # or basename of a dir only, not a path

    filelist.each { | file_of_interest |
      if ( @criteria[ file_of_interest ] == nil )  # then this is a new file or file type to watch for

        # add the new type to the criteria list and register the subscriber
        @criteria[ file_of_interest ] = Array.new         # each file of interest may have multiple subscribers interested in it
        @criteria[ file_of_interest ].push( subscriber )  # add a subcriber to the list for that file

      else
        # TODO - if we can't enforce or trust that filelist has no duplicates, then we need to
        # check to see if this file of interest already has this subscriber in it.

        @criteria[ file_of_interest ].push( subscriber )

      end
    }

  end

=begin rdoc
  returns the keys of the criteria as an array
=end

  def get_files_of_interest()
    return @criteria.keys
  end

end

