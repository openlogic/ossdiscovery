require 'find'
require 'set'

class TestHelper

=begin rdoc
  Returns the same thing that this unix command would return. 

  find [dir] -name \* -type f | grep -v svn

  The 'dir' arg is expected to be a fully qualified directory name.
  Specifically, it returns a Set of fully qualified filename Strings.
=end  
  def TestHelper.find_all_files(dir)
    all_files = Set.new
    Find.find(dir) do |path|
      if (File.basename(path) == 'resources') then
        puts "pruning this directory: '#{path}'"
        # The resources directory contains the symlink test directory which intentionally contains
        # is infinitely recursive circular symlink. If jruby is running this code (as opposed to
        # native ruby) then the process goes out to lunch forever.  In addition to this, the 'resources'
        # directory contains no test cases, only resources used by those test cases, so it is safe
        # to exclude it in this case.
        Find.prune
      else
        if (File.file?(path) && !path.include?(".svn")) then
          all_files << File.expand_path(path)
        end
      end

    return all_files
  end

end
