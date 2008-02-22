require 'rake/packagetask'

PACKAGE_NAME=ENV["NAME"] || "ossdiscovery"
PACKAGE_VERSION=ENV["VERSION"] || "2.0b1"

namespace :release do
  namespace :ruby do 
  
    Rake::PackageTask.new(PACKAGE_NAME, PACKAGE_VERSION) do |p|
      p.need_tar_gz = true
      p.need_zip = true
      p.package_files.include("lib/**/*", "doc/*", "log/*", "log", "license/*", "README*", "discovery", "discovery.bat")
      p.package_files.exclude("lib/**/*.jar")
    end

    desc "Build the distribution files for the Native Ruby version of OSS Discovery"
    task :distributions =>"release:ruby:package"

  end

  namespace :jruby do 
    
    jruby_package_name="#{PACKAGE_NAME}-jruby"
    jruby_package_filename="#{jruby_package_name}-#{PACKAGE_VERSION}"

    desc "Prepare the Discovery/JRuby distribution package"
    task :prepare => "release:jruby:clean" do
      mkdir_p "pkg/#{jruby_package_filename}"
      cp_r "lib", "pkg/#{jruby_package_filename}/lib", :remove_destination=>true
      cp_r "jruby", "pkg/#{jruby_package_filename}/jruby", :remove_destination=>true
      cp_r "license", "pkg/#{jruby_package_filename}/license", :remove_destination=>true
      cp_r "doc", "pkg/#{jruby_package_filename}/doc", :remove_destination=>true
      cp_r "log", "pkg/#{jruby_package_filename}/log", :remove_destination=>true
      cp "README.txt", "pkg/#{jruby_package_filename}/"      
      cp "discovery_jruby", "pkg/#{jruby_package_filename}/discovery"
      cp "discovery_jruby.bat", "pkg/#{jruby_package_filename}/discovery.bat"
      require 'find'

      # Remove all .svn directories.  There's no way to prevent cp_r from copying them,
      # but we don't want them in the distributions
      Find.find("pkg/#{jruby_package_filename}") { |path| rm_rf path if File.directory?(path) and File.basename(path) == ".svn" }

    end

    Rake::PackageTask.new(jruby_package_name, PACKAGE_VERSION) do |p|
      p.need_tar_gz = true
      p.need_zip = true
    end

    desc "Build the distribution files for the JRuby version of OSS Discovery"
    task :distributions =>["release:jruby:prepare", "release:jruby:package"]

    desc "Clean up the Discovery/JRuby package files"
    task :clean do
      rm_rf "pkg/#{jruby_package_filename}"
    end

  end

  namespace :windows do 
    
    package_name="#{PACKAGE_NAME}-windows"
    package_filename="#{package_name}-#{PACKAGE_VERSION}"
    dest_dir="pkg/#{package_filename}"

    desc "Prepare the Windows Discovery distribution package"
    task :prepare => "release:windows:clean" do
      mkdir_p "#{dest_dir}"
      mkdir_p "#{dest_dir}/jre/"
      cp_r "lib", "#{dest_dir}/lib", :remove_destination=>true
      cp_r "jruby", "#{dest_dir}/jruby", :remove_destination=>true
      cp_r "license", "#{dest_dir}/license", :remove_destination=>true
      cp_r "log", "#{dest_dir}/log", :remove_destination=>true
      cp_r "doc", "#{dest_dir}/doc", :remove_destination=>true
      cp_r "jre/jre-1.5.0_07-windows-ia32", "#{dest_dir}/jre", :remove_destination=>true
      cp "README.txt", "#{dest_dir}"      
      cp "discovery_jre_windows.bat", "#{dest_dir}/discovery.bat"
      require 'find'

      # Remove all .svn directories.  There's no way to prevent cp_r from copying them,
      # but we don't want them in the distributions
      Find.find("#{dest_dir}") { |path| rm_rf path if File.directory?(path) and File.basename(path) == ".svn" }

    end

    Rake::PackageTask.new(package_name, PACKAGE_VERSION) do |p|
      p.need_tar_gz = false
      p.need_zip = true
    end

    desc "Build the distribution files for the Windows version of OSS Discovery"
    task :distribution =>["release:windows:prepare", "release:windows:package"]

    desc "Clean up the Windows Discovery package files"
    task :clean do
      rm_rf "#{dest_dir}"
    end

  end

  namespace :linux do 
    
    package_name="#{PACKAGE_NAME}-linux"
    package_filename="#{package_name}-#{PACKAGE_VERSION}"
    dest_dir="pkg/#{package_filename}"

    desc "Prepare the Linux Discovery distribution package"
    task :prepare => "release:linux:clean" do
      mkdir_p "#{dest_dir}"
      mkdir_p "#{dest_dir}/jre/"
      cp_r "lib", "#{dest_dir}/lib", :remove_destination=>true
      cp_r "jruby", "#{dest_dir}/jruby", :remove_destination=>true
      cp_r "license", "#{dest_dir}/license", :remove_destination=>true
      cp_r "log", "#{dest_dir}/log", :remove_destination=>true
      cp_r "doc", "#{dest_dir}/doc", :remove_destination=>true
      cp_r "jre/jre-1.5.0_07-linux-ia32", "#{dest_dir}/jre", :remove_destination=>true
      cp "README.txt", "#{dest_dir}"      
      cp "discovery_jre_linux", "#{dest_dir}/discovery"
      require 'find'

      # Remove all .svn directories.  There's no way to prevent cp_r from copying them,
      # but we don't want them in the distributions
      Find.find("#{dest_dir}") { |path| rm_rf path if File.directory?(path) and File.basename(path) == ".svn" }

    end

    Rake::PackageTask.new(package_name, PACKAGE_VERSION) do |p|
      p.need_tar_gz = true
      p.need_zip = false
    end

    desc "Build the distribution files for the Linux version of OSS Discovery"
    task :distribution =>["release:linux:prepare", "release:linux:package"]

    desc "Clean up the Linux Discovery package files"
    task :clean do
      rm_rf "#{dest_dir}"
    end

  end

  namespace :solaris do 
    
    package_name="#{PACKAGE_NAME}-solaris"
    package_filename="#{package_name}-#{PACKAGE_VERSION}"
    dest_dir="pkg/#{package_filename}"

    desc "Prepare the Solaris Discovery distribution package"
    task :prepare => "release:solaris:clean" do
      mkdir_p "#{dest_dir}"
      mkdir_p "#{dest_dir}/jre/"
      cp_r "lib", "#{dest_dir}/lib", :remove_destination=>true
      cp_r "jruby", "#{dest_dir}/jruby", :remove_destination=>true
      cp_r "license", "#{dest_dir}/license", :remove_destination=>true
      cp_r "log", "#{dest_dir}/log", :remove_destination=>true
      cp_r "doc", "#{dest_dir}/doc", :remove_destination=>true
      cp_r "jre/jre-1.5.0_10-b03-solaris-sparc32", "#{dest_dir}/jre", :remove_destination=>true
      cp "README.txt", "#{dest_dir}"      
      cp "discovery_jre_solaris", "#{dest_dir}/discovery"
      require 'find'

      # Remove all .svn directories.  There's no way to prevent cp_r from copying them,
      # but we don't want them in the distributions
      Find.find("#{dest_dir}") { |path| rm_rf path if File.directory?(path) and File.basename(path) == ".svn" }

    end

    Rake::PackageTask.new(package_name, PACKAGE_VERSION) do |p|
      p.need_tar_gz = true
      p.need_zip = false
    end

    desc "Build the distribution files for the Solaris version of OSS Discovery"
    task :distribution =>["release:solaris:prepare", "release:solaris:package"]

    desc "Clean up the Solaris Discovery package files"
    task :clean do
      rm_rf "#{dest_dir}"
    end

  end

  namespace :all do
    desc "Build the distribution files for the all versions of OSS Discovery"
    task :distributions =>["release:ruby:distributions", "release:jruby:distributions", "release:windows:distribution", "release:linux:distribution", "release:solaris:distribution"]
  end
end