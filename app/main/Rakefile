require 'rake/packagetask'


namespace :release do

  PACKAGE_NAME= ( ENV["NAME"] || "ossdiscovery" ) + "-" + (ENV['plugin'].nil? ? "error" : ENV['plugin'])
  PACKAGE_VERSION=ENV["VERSION"] || "2.3.1"


  def prep_dir

    if ( ENV['plugin'].nil? )
      puts "\nWarning: You need to define the plugin environment to package!"
      puts "ie) rake release:all:distributions plugin=inventory"
      puts "ie) rake release:all:distributions plugin=census"
      puts "ie) rake release:all:distributions plugin=olex"
      puts "\n\n"
    end

    puts "Cleaning up discovery.log files"
    `find . -name "discovery.log" -exec rm {} \\;`

    # if inventory, then dynamically enable the plugin - by default it's disabled because census test cases
    # are the ones active in CCrb and consequently, it tries to load both plugins which have colliding command  line parameters
    # so inventory is disabled so cli params don't collide.  

    if ( ENV['plugin'] == "inventory")
      inventory_yml = File.open("lib/plugins/inventory/conf/inventory_config.yml").read
      inventory_yml.gsub!("inventory_enabled: false", "inventory_enabled: true")
      puts inventory_yml
      if ( !inventory_yml.nil? )
        yml_fd = File.open("lib/plugins/inventory/conf/inventory_config.yml","w")
        yml_fd.write(inventory_yml)
        yml_fd.close
      end

    elsif ( ENV['plugin'] == "olex")
      olex_yml = File.open("lib/plugins/olex/conf/olex_config.yml").read
      olex_yml.gsub!("olex_enabled: false", "olex_enabled: true")
      puts olex_yml
      if ( !olex_yml.nil? )
        yml_fd = File.open("lib/plugins/olex/conf/olex_config.yml","w")
        yml_fd.write(olex_yml)
        yml_fd.close
      end
    end

  end

  def cleanup
    if ENV['plugin'] == "inventory"
       # revert the temporary enabling of the inventory plugin 
       puts "reverting inventory_config.yml"
       `svn revert lib/plugins/inventory/conf/inventory_config.yml`
    elsif ENV['plugin'] == "olex"
       # revert the temporary enabling of the olex plugin 
       puts "reverting olex_config.yml"
       `svn revert lib/plugins/olex/conf/olex_config.yml`
    end
  end

  namespace :ruby do 

    Rake::PackageTask.new(PACKAGE_NAME, PACKAGE_VERSION) do |p|
  
      p.need_tar_gz = true
      p.need_zip = true
      p.package_files.include("lib/**/*", "doc/*", "log/*", "log", "license/*", "README*", "discovery", "discovery.bat", "help.txt" )

      if ( ENV['plugin'] == "inventory")  # then exclude census and vica versa
        p.package_files.exclude("lib/**/*.jar", "lib/plugins/census" )
        p.package_files.exclude("lib/**/*.jar", "lib/plugins/olex" )
      elsif ( ENV['plugin'] == "census" )
        p.package_files.exclude("lib/**/*.jar", "lib/plugins/inventory")
        p.package_files.exclude("lib/**/*.jar", "lib/plugins/olex")
      elsif ( ENV['plugin'] == "olex" )
        p.package_files.exclude("lib/**/*.jar", "lib/plugins/inventory")
        p.package_files.exclude("lib/**/*.jar", "lib/plugins/census")
      end

    end

    desc "Build the distribution files for the Native Ruby version of OSS Discovery"
    task :distributions => ["release:ruby:prepare", "release:ruby:package"]
    task :prepare do
      prep_dir
    end

  end

  namespace :jruby do 
  
    plugin = ENV['plugin']    
    jruby_package_name="#{PACKAGE_NAME}-jruby"
    jruby_package_filename="#{jruby_package_name}-#{PACKAGE_VERSION}"

    desc "Prepare the Discovery/JRuby distribution package"
    task :prepare => "release:jruby:clean" do
      prep_dir
      mkdir_p "pkg/#{jruby_package_filename}"
      cp_r "lib", "pkg/#{jruby_package_filename}/lib", :remove_destination=>true

      if ( plugin == "inventory" )
        rm_r "pkg/#{jruby_package_filename}/lib/plugins/census"
        rm_r "pkg/#{jruby_package_filename}/lib/plugins/olex"
      elsif ( plugin == "census" )
        rm_r "pkg/#{jruby_package_filename}/lib/plugins/inventory"
        rm_r "pkg/#{jruby_package_filename}/lib/plugins/olex"
      elsif ( plugin == "olex" )
        rm_r "pkg/#{jruby_package_filename}/lib/plugins/inventory"
        rm_r "pkg/#{jruby_package_filename}/lib/plugins/census"
      end

      cp_r "jruby", "pkg/#{jruby_package_filename}/jruby", :remove_destination=>true
      cp_r "license", "pkg/#{jruby_package_filename}/license", :remove_destination=>true
      cp_r "doc", "pkg/#{jruby_package_filename}/doc", :remove_destination=>true
      cp_r "log", "pkg/#{jruby_package_filename}/log", :remove_destination=>true
      cp "README.txt", "pkg/#{jruby_package_filename}/"      
      cp "help.txt", "pkg/#{jruby_package_filename}/"      
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
   
    plugin = ENV['plugin']    
    package_name="#{PACKAGE_NAME}-windows"

    package_filename="#{package_name}-#{PACKAGE_VERSION}"
    dest_dir="pkg/#{package_filename}"

    desc "Prepare the Windows Discovery distribution package"
    task :prepare => "release:windows:clean" do
      prep_dir
      mkdir_p "#{dest_dir}"
      mkdir_p "#{dest_dir}/jre/"
      cp_r "lib", "#{dest_dir}/lib", :remove_destination=>true

      if ( plugin == "inventory" )
        rm_r "pkg/#{package_filename}/lib/plugins/census"
        rm_r "pkg/#{package_filename}/lib/plugins/olex"
      elsif ( plugin == "census")
        rm_r "pkg/#{package_filename}/lib/plugins/inventory"
        rm_r "pkg/#{package_filename}/lib/plugins/olex"
      elsif ( plugin == "olex")
        rm_r "pkg/#{package_filename}/lib/plugins/inventory"
        rm_r "pkg/#{package_filename}/lib/plugins/census"
      end

      cp_r "jruby", "#{dest_dir}/jruby", :remove_destination=>true
      cp_r "license", "#{dest_dir}/license", :remove_destination=>true
      cp_r "log", "#{dest_dir}/log", :remove_destination=>true
      cp_r "doc", "#{dest_dir}/doc", :remove_destination=>true
      cp_r "jre/jre-1.6.0_13-windows-ia32", "#{dest_dir}/jre", :remove_destination=>true
      cp "README.txt", "#{dest_dir}"      
      cp "help.txt", "#{dest_dir}"      
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

    desc "Build installer"
    task :installer do
      if ENV['INNO_HOME'].nil?
        puts "You must have the INNO_HOME environment variable set in order to build the installer.  Installer will not be built.  Set INNO_HOME to the path to inno setup"
      else
        result=`which wine`
        if result == ""
          puts "You must have wine installed in order to build the installer"      
        else
          system "wine $INNO_HOME/ISCC.exe setup/setup_script.iss"
        end
      end
    end

  end

  namespace :linux do 

    plugin = ENV['plugin']    
    package_name="#{PACKAGE_NAME}-linux"
    package_filename="#{package_name}-#{PACKAGE_VERSION}"
    dest_dir="pkg/#{package_filename}"

    desc "Prepare the Linux Discovery distribution package"
    task :prepare => "release:linux:clean" do
      prep_dir
      mkdir_p "#{dest_dir}"
      mkdir_p "#{dest_dir}/jre/"
      cp_r "lib", "#{dest_dir}/lib", :remove_destination=>true

      if ( plugin == "inventory" )
        rm_r "pkg/#{package_filename}/lib/plugins/census"
        rm_r "pkg/#{package_filename}/lib/plugins/olex"
      elsif ( plugin == "census")
        rm_r "pkg/#{package_filename}/lib/plugins/inventory"
        rm_r "pkg/#{package_filename}/lib/plugins/olex"
      elsif ( plugin == "olex")
        rm_r "pkg/#{package_filename}/lib/plugins/inventory"
        rm_r "pkg/#{package_filename}/lib/plugins/census"
      end

      cp_r "jruby", "#{dest_dir}/jruby", :remove_destination=>true
      cp_r "license", "#{dest_dir}/license", :remove_destination=>true
      cp_r "log", "#{dest_dir}/log", :remove_destination=>true
      cp_r "doc", "#{dest_dir}/doc", :remove_destination=>true
      cp_r "jre/jre-1.6.0_13-linux-ia32", "#{dest_dir}/jre", :remove_destination=>true
      cp "README.txt", "#{dest_dir}"      
      cp "help.txt", "#{dest_dir}"      
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

    plugin = ENV['plugin']    
    package_name="#{PACKAGE_NAME}-solaris"
    package_filename="#{package_name}-#{PACKAGE_VERSION}"
    dest_dir="pkg/#{package_filename}"

    desc "Prepare the Solaris Discovery distribution package"
    task :prepare => "release:solaris:clean" do
      prep_dir
      mkdir_p "#{dest_dir}"
      mkdir_p "#{dest_dir}/jre/"
      cp_r "lib", "#{dest_dir}/lib", :remove_destination=>true

      if ( plugin == "inventory" )
        rm_r "pkg/#{package_filename}/lib/plugins/census"
        rm_r "pkg/#{package_filename}/lib/plugins/olex"
      elsif ( plugin == "census")
        rm_r "pkg/#{package_filename}/lib/plugins/inventory"
        rm_r "pkg/#{package_filename}/lib/plugins/olex"
      elsif ( plugin == "olex")
        rm_r "pkg/#{package_filename}/lib/plugins/inventory"
        rm_r "pkg/#{package_filename}/lib/plugins/census"
      end

      cp_r "jruby", "#{dest_dir}/jruby", :remove_destination=>true
      cp_r "license", "#{dest_dir}/license", :remove_destination=>true
      cp_r "log", "#{dest_dir}/log", :remove_destination=>true
      cp_r "doc", "#{dest_dir}/doc", :remove_destination=>true
      cp_r "jre/jre-1.5.0_10-b03-solaris-sparc32", "#{dest_dir}/jre", :remove_destination=>true
      cp "README.txt", "#{dest_dir}"      
      cp "help.txt", "#{dest_dir}"      
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




