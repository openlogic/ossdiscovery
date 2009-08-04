require 'cheri/swing'
require 'discovery'
require 'scan_settings_dialog'

# Quick and dirty GUI wrapped around discovery to make it easy for infrequent
# users to do a scan and see results.
class DiscoveryGUI
  include Cheri::Swing
  Enter = java.awt.event.KeyEvent::VK_ENTER
  EventQueue = java.awt.EventQueue
  Desktop = java.awt.Desktop

  #  CJava = Cheri::Java
  #  Cheri.img_path = 'cheri/image/'
  #  System = ::Java::JavaLang::System

  # UI look-and-feel init adapted from JConsole
  #  UIManager = ::Java::JavaxSwing::UIManager
  #  system_laf = UIManager.getSystemLookAndFeelClassName
  #  UIManager.setLookAndFeel(system_laf) rescue nil

  @@prepped = false
  attr_accessor :discovery, :olex_plugin

  def initialize
    @project_name = java.lang.System.getProperty("olex.project.name", "Unknown")

    swing[:auto]
    @frame = frame 'OpenLogic Discovery' do |f|
      default_close_operation :EXIT_ON_CLOSE
      #      icon_image CJava.cheri_icon.image
      size 980,600
      box_layout f, :X_AXIS
      empty_border 4,4,4,4
      on_window_closing {@frame.dispose}
      grid_table do
        grid_row :insets=>[6,6,6,6] do
          grid_table :a=>:nw, :f=>:h do
            defaults :i=>[6,2], :wx=>0.1
          end
        end
        grid_row :insets=>[6,6,6,6] do
          label("Discovery Results for Project: #{@project_name}", :weightx=>0.7,:anchor=>:north) {
            font 'Dialog', :BOLD, 20
          }
        end
        grid_row :i=>6, :wy=>0.01 do
          scroll_pane :fill=>:both do
            bevel_border :RAISED; minimum_size 200,100
            @results = text_area { text ""; editable false }
            @results.font = font 'Monospaced', :PLAIN, 12
          end
        end
        grid_row :wy=>0 do
          grid_table :a=>:se, :f=>:h do
            defaults :i=>[6,2], :wx=>0.1
            grid_row :f=>:h do
              @settings_button = button('0. Scan settings...', :a=>:nw) {
                on_click { show_settings_dialog }}
              h_glue
              @chooser_button = button('1. Choose directory to scan...', :a=>:nw) {
                on_click { show_file_chooser }
              }
              h_glue
              @upload_button = button("2. Upload results to OLEX", :a=>:w) {
                on_click{ upload_results }
              }
              h_glue
              @view_button = button("3. View results in OLEX", :a=>:w) {
                on_click{ go_to_olex }
              }
              h_glue
              h_glue
              button('Exit', :a=>:se) {on_click{ @frame.dispose }}
            end
          end
        end

      end
    end
    @frame.visible = true

    # setup Discovery
    prepare_for_discovery

    # prepare the settings dialog box so we have default values for all scan
    # parameters
    create_settings_dialog

    # set the initial button states
    enable_pre_scan_buttons

  end

  # center a child component relative to a parent component
  def center(parent, child)
    x = parent.x + ((parent.width - child.width)/2)
    y = parent.y + ((parent.height - child.height)/2)
    child.set_location(x,y)
    child
  end

  # provide a reference to the main frame for child dialogs to use
  def main_frame
    @frame
  end
  
  # show the scan settings dialog box
  def show_settings_dialog
    @settings_dialog.show
    @settings_button.enabled = true
  end

  # create the settings dialog box that lets users change the default
  # scan parameters
  def create_settings_dialog
    @settings_dialog ||= ScanSettingsDialog.new(self)
  end

  # get discovery ready to run the first time
  def prepare_for_discovery
    begin
      @discovery = Discovery.new(self)
      @discovery.plugin_prep
      if @discovery.plugins_list
        @olex_plugin = @discovery.plugins_list["Olex"]
      end
      if @olex_plugin
        base_dir = "/tmp/"
        if Utils.major_platform =~ /windows/
          base_dir = "c:/temp/"
        end
        @olex_plugin.olex_machine_file = base_dir + @olex_plugin.olex_machine_file
        @olex_plugin.olex_local_detailed_file = base_dir + @olex_plugin.olex_local_detailed_file
        @olex_plugin.olex_local_rollup_file = base_dir + @olex_plugin.olex_local_rollup_file
        @olex_plugin.olex_mif_file = base_dir + @olex_plugin.olex_mif_file
      end
    rescue Error => e
    rescue Exeption => e
      puts e
    end
  end

  # run discovery - may be the first scan or may be the nth
  def run_discovery(path)
    clear
    unless @@prepped
      @discovery.prep
      @@prepped = true
    end
    
    @discovery.validate_directory_to_scan(path)
    @discovery.process_args

    # set up parameters
    return unless set_scan_parameters

    @discovery.run
  end

  # prepare scan parameters
  def set_scan_parameters
    return false unless test_file_permissions

    @discovery.dont_open_discovered_archives = !@settings_dialog.always_open_archives
    @discovery.examine_source_files = @settings_dialog.scan_source
    if Utils.major_platform =~ /windows/
      @discovery.examine_windows_binary_files = @settings_dialog.windows_binary_scan
    end
    @discovery.dont_update_rules = @settings_dialog.dont_update_rules
    @discovery.rule_types = @settings_dialog.all_rules ? "all" : "fast"
    @discovery.throttling_enabled = @settings_dialog.throttling_enabled
    @discovery.always_open_class_file_archives = @settings_dialog.always_open_class_file_archives
    @discovery.olex_machine_results_file = @settings_dialog.olex_machine_results_file
    @discovery.olex_human_results_file = @settings_dialog.olex_human_results_file
    @discovery.olex_rollup_results_file = @settings_dialog.olex_rollup_results_file
    @discovery.olex_mif_results_file = @settings_dialog.olex_mif_results_file
    @discovery.show_rollup_report = @settings_dialog.show_rollup_report

    true
  end

  # output a message so users can see it
  def say(message, newline = true)
    # special check - if we're just saying ".", it's a progress message and we
    # won't append a new line
    if message == "."
      text = "."
    elsif newline
      text = message + "\n"
    else
      text = message
    end
    EventQueue.invoke_and_wait(proc {show(text)})
  end

  # pop up a file chooser so users can choose a directory to scan
  def show_file_chooser
    chooser = file_chooser {
      file_selection_mode :DIRECTORIES_ONLY
    }
    choice = chooser.show_open_dialog(@frame)
    #if choice == JOptionPane::APPROVE_OPTION
    if choice == 0
      clear
      file = chooser.selected_file
      Thread.new do
        enable_in_scan_buttons
        run_discovery(file.absolute_path)
        EventQueue.invoke_later(proc {enable_post_scan_buttons})
      end
    else
      enable_pre_scan_buttons
    end
  end

  # turn on buttons as no scan is in progress
  def enable_pre_scan_buttons
    @chooser_button.enabled = true
    @settings_button.enabled = true
    @upload_button.enabled = false
    @view_button.enabled = false
  end

  # turn off buttons as a scan is in progress
  def enable_in_scan_buttons
    @chooser_button.enabled = false
    @settings_button.enabled = false
    @upload_button.enabled = false
    @view_button.enabled = false
  end

  # turn on buttons as a scan has finished
  def enable_post_scan_buttons
    @chooser_button.enabled = true
    @settings_button.enabled = true
    # if no project is specified, don't allow upload to OLEX
    if @project_name && !@project_name.empty? && @project_name != "Unknown"
      @upload_button.enabled = true
      @view_button.enabled = true
    end
  end

  # upload scan results to OLEX
  def upload_results
    enable_in_scan_buttons
    Thread.new do
      @discovery.send_results = true
      transmission_okay = @discovery.send_scan_results(@settings_dialog.olex_machine_results_file)
      @discovery.send_results = false
      if transmission_okay
        javax.swing.JOptionPane.show_message_dialog(@frame,
          "The upload to OLEX was successful.  Please return to the\n" +
            "project details page on OLEX to see the new scan data.",
          "Success",
          1)
        EventQueue.invoke_later(proc {enable_pre_scan_buttons; @view_button.enabled = true})
      else
        javax.swing.JOptionPane.show_message_dialog(@frame,
          "The upload to OLEX failed.  Please try again later.",
          "Failure",
          0)
        EventQueue.invoke_later(proc {enable_post_scan_buttons; @view_button.enabled = true })
      end
    end
  end

  def show(text)
    @results.text += text
  end

  # wipe the slate clean to prepare for a new scan
  def clear
    @results.text = ""
  end

  def test_file_permissions
    can_proceed = true
    olex_machine_results_file = @settings_dialog.olex_machine_results_file
    olex_human_results_file = @settings_dialog.olex_human_results_file
    olex_rollup_results_file = @settings_dialog.olex_rollup_results_file
    olex_mif_results_file = @settings_dialog.olex_mif_results_file
    files = [olex_machine_results_file, olex_human_results_file, olex_rollup_results_file, olex_mif_results_file]
    files.each do |file_name|
      begin
        # Issue 34: only open as append in this test so we do not blow away an existing results file
        File.open(file_name, "a") {|file|}
      rescue Exception => e
        say "ERROR: Unable to write to file: '#{file_name}'\n"
        if ( !(File.directory?( File.dirname(file_name) ) ) )
          say "The directory " + File.dirname(file_name) + " does not exist\n"
        end
        can_proceed = false
      end
    end

    can_proceed
  end

  # open OLEX in the default browser if possible
  def go_to_olex
    if Desktop.desktop_supported?
      desktop = Desktop.desktop
      if desktop.is_supported(Desktop::Action::BROWSE)
        project_id = java.lang.System.getProperty("olex.project.id", "0")
        olex_url = java.lang.System.getProperty("olex.scan.upload.url", "https://olex.openlogic.com/")
        uri = java.net.URI.new("#{olex_url}projects/#{project_id}/")
        desktop.browse(uri)
      end
    end
  end

end

DiscoveryGUI.new