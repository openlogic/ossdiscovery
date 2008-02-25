# walker.rb
#
# LEGAL NOTICE
# -------------
# 
# OSS Discovery is a tool that finds installed open source software.
#    Copyright (C) 2007 OpenLogic, Inc.
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
#
#  A walker is the object which will scan directories, look for file matches and then
#  notify the rule engine (or any subscriber) of a filename match.
#
#  Multiple instances of Walkers are allowed - for example a global Walker may be 
#  scanning the disk, it encounters a jar file, passes that jar file to the RuleEngine
#  and the rule itself decides to crack the jar, then create a walker for just walking
#  the exploded jar directory contents.
#
#  An instance of Walker is given a directory from which it will start walking through
#  files and directories.  In order to walk individual directories which aren't
#  nested, you must call walkDir() once for each directory.  
#
#  For example, to walk /usr, /opt, and /tmp without walking the entire root directory, you'd
#  call walkDir 3 times, once for each directory off of root that you want scanned.  You can
#  use the same Walker instance for each walkDir call or create one Walker instance for each
#  directory - it doesn't matter.


require "pathname"

require File.join(File.dirname(__FILE__), 'conf', 'config')

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

  attr_accessor :file_ct, :dir_ct, :sym_link_ct, :bad_link_ct, :permission_denied_ct, :foi_ct, :not_found_ct
  attr_accessor :follow_symlinks, :symlink_depth, :not_followed_ct, :show_every, :show_verbose, :show_progress, :throttling_enabled, :throttle_number_of_files, :throttle_seconds_to_pause
  attr_accessor :list_exclusions, :list_files, :show_permission_denied
  attr_reader :total_seconds_paused_for_throttling

  # criteria[:] 
  # is a hash of filenames or regular expressions that can match a filename.
  # the key to the hash is the string representing the criteria (the filename or regex.)
  # the value of the hash is a list of subscribers to be notified on a match for this
  # criteria.
  #
  # criteria effectively holds what are called the "files of interest" but more than that
  # handles who to notify when a file of interest is found.

  @criteria
  
  # dir_exclusions is an array of dirs/ or regular expressions which, if matched,
  # will exclude the dir from any further processing.  The Walker will count excluded
  # files and directories for diagnostic purposes, but no subscriber will get a chance
  # to see any file that's excluded through the generic exclusion mechanism
  
  @dir_exclusions
  @file_exclusions
  
  # this is used to detect circular symlinks...if a file or directory to resolve is in this
  # cache, it can't be resolved again - a circular link will be reported instead by the 
  # walker and the package will move on.  It's a class variable due to recursive walking.
  
  @@symlink_cache = Hash.new
  
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
  def add_dir_exclusions( exclusion_list )
      @dir_exclusions.concat( exclusion_list )
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
    
    returns false if given fileordir is a directory excluded by a filter
    returns true if given fileordir was walked
=end

   def walk_dir( fileordir )
    # crude progress indicator
    if ( @show_progress && @file_ct != 0 ) 
      q,r = @file_ct.divmod( @show_every )
      if ( r == 0 )
        printf "."
      end
    end
    
    if ( @show_verbose && @file_ct != 0 ) 
      q,r = @file_ct.divmod( @show_every )
      if ( r == 0 )
        # puts fileordir # Uncomment this line in order to see the directories being walked
        progress_report()
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
    
    @dir_exclusions.each do | filter | 

       if ( File.directory?(fileordir) && fileordir.match( filter ) != nil )   # found a directory exclusion
          if ( @list_exclusions || $DEBUG )
            printf("'%s' is excluded by: %s directory filter\n", fileordir, filter )
          end
          #  blow out of here if this file matches an exclusion condition, 
          #  false because this is a directory which needs to be pruned
          return false  
        end
    end

    @file_exclusions.each do | filter | 

        if ( File.basename( fileordir ).match( filter ) != nil )   # found an exclusion
          if ( @list_exclusions || $DEBUG )
            printf("'%s' is excluded by: %s file filter\n", fileordir, filter )
          end
          return true  # blow out of here if this file matches an exclusion condition, true because this is a file and got walked
        end
      end
    
    # --list-files flag implementation
    # will show only files that made it through the exclusion filters

    if ( @list_files || $DEBUG )
      printf("%s\n", fileordir )
    end

    resolved = true

    begin
      
      if( File.file?(fileordir) )
        if (File.readable?(fileordir)) then
          @file_ct += 1

          if ( is_symlink?(fileordir) )
            if ( @follow_symlinks )
              resolved, fileordir = resolve_symlink( fileordir )
            else
              resolved = false
              @sym_link_ct += 1
              @not_followed_ct += 1
            end
          end
         
          # see if this entry is resolvable and matches anything anyone's looking for 
          if ( resolved )        
            name_match( fileordir )
          end
        else # the file was not readable
          increment_permission_denied_ct(fileordir)
          return false
        end # of if (File.readable?
        
        
      elsif( File.directory?(fileordir) )
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
                      
            if ( is_symlink?(fileordir) )
              if ( @follow_symlinks )
                # need to resolve the symlink
                resolved, fileordir = resolve_symlink( fileordir )
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
          
          if ( resolved ) 
            
            # printf("fileordir resolved: #{fileordir}\n")
            
            pwd = fileordir
  
            Dir.foreach(fileordir) do | direntry | 
  
                # recurse into this directory if it's not current or parent directories
                if ( direntry != "." && direntry != ".." ) 
                  direntry = (pwd == '/' ? "/#{direntry}" : "#{pwd}/#{direntry}" )
                  
                  # @@log.info("Walker") { "pwd: #{pwd} direntry: #{direntry}" }                
  
                  # check to see if we need to prune a directory
                  if ( !walk_dir( direntry ) )
                      if ( @list_exclusions || $DEBUG )
                        printf("'%s' pruned\n", direntry )
                      end
                  end
                end 
            end
          end
          return true
        else # the file was not readable
          increment_permission_denied_ct(fileordir)
          return false
        end # of if (File.readable?(fileordir))        
      end # of if (File.readable?(fileordir))
  
    rescue Errno::EACCES, Errno::EPERM
      increment_permission_denied_ct(fileordir)
      return false
    rescue Errno::ENOENT, Errno::ENOTDIR
      # it may seem odd that a file that was scanned would end up not found, but it's possible that 
      # a file existed and in the moments between when it was encountered and when it was scanned, was removed or moved.
      @not_found_ct += 1
      return false
    end
  
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
    if RUBY_PLATFORM =~ /java/
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

  def progress_report()
    
    printf( "directories walked: %d\n", dir_ct() )
    printf( "files encountered : %d\n", file_ct() )
    printf( "symlinks found    : %d\n", sym_link_ct() )
    printf( "bad symlink count : %d\n", bad_link_ct() )
    printf( "permission denied : %d\n", permission_denied_ct() )
    printf( "files of interest : %d\n...\n", foi_ct() )
    
  end

=begin rdoc
  given the filename, this code will check the list of subscribers and 
  notify those subscribers whose filename criteria matches this filename
  a subscriber must have a notify method that receives filename, location parameters
=end

  def notify_subscribers( subscribers, location, filename, rule_used )
    subscribers.each{ | subscriber |
      subscriber.found_file( location, filename, rule_used )
    }
    
  end

  
=begin rdoc
  this is the main method which compares a filename found by the walker against the list of
  files of interest to see if there's a match.  if there is a match, this code will fire the
  subscriber notification method to tell the subscriber (ie RuleEngine) a file of interest 
  has been found
=end
  
  def name_match( fileordir )
        
    # FUTURE - determine if it may be necessary to pull this optimization out and do a literal match on 
    # all criteria, not just take the first match....right now, with a one-subscriber model (RuleEngine),
    # any match is going to notify the subscriber, so it's an optimization to not try to 
    # find any more matches in the criteria after the first match.  Later we may not have this luxury
    # if we need to support more than one subscriber in the system.
    
    
    # do a direct/literal look up first since this will be the fastest match, do it first
    
    basename = File.basename( fileordir )
    dirname =  File.dirname( fileordir )
        
    if ( @criteria[ basename ] )
      # found a literal filename match in the criteria list, so notify its subscribers
      @foi_ct += 1
      notify_subscribers( @criteria[ basename ], dirname, basename, basename )
      return
    end

    # no literal filename match was found - check all other match types - regex's
    
    # now try to match each criterion against the given filename and build a list of subscribers
    # that care - because the filename might match more than one criterion, we can't just find the
    # first match and return the subscriber list
    
    @criteria.each_key { | criterion |
      if ( basename.match(criterion) )
        @foi_ct += 1
        # notify array of subscribers
        notify_subscribers( @criteria[ criterion ], dirname, basename, criterion )
        return
      end
    }

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

