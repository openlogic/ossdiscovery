require 'rake/packagetask'

PACKAGE_NAME=ENV["NAME"] || "ossdiscovery"
PACKAGE_VERSION=ENV["VERSION"] || "2.0b1"

namespace :release do
  namespace :ruby do 
  
    Rake::PackageTask.new(PACKAGE_NAME, PACKAGE_VERSION) do |p|
      p.need_tar_gz = true
      p.need_zip = true
      p.package_files.include("lib/**/*.*", "doc/*", "license/*", "README*", "discovery", "discovery.bat")
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

  namespace :all do
    desc "Build the distribution files for the all versions of OSS Discovery"
    task :distributions =>["release:ruby:distributions", "release:jruby:distributions"]
  end

  desc "Remove current distributables"
  task :clean do
    rm_rf 'dist'
  end
end
