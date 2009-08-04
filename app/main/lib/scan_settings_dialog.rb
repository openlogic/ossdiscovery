class ScanSettingsDialog
  include Cheri::Swing

  attr_accessor :always_open_archives, :scan_source, :windows_binary_scan,
    :dont_update_rules, :all_rules, :throttling_enabled, :always_open_class_file_archives,
    :show_rollup_report, :olex_machine_results_file, :olex_human_results_file,
    :olex_rollup_results_file, :olex_mif_results_file

  def initialize(main)
    # default values
    @always_open_archives = false
    @scan_source = false
    @windows_binary_scan = false
    @dont_update_rules = false
    @all_rules = false
    @throttling_enabled = false
    @always_open_class_file_archives = false
    @show_rollup_report = false

    # default the file name values to the values set in the config file
    # with base_dir set according to operating system
    if main.olex_plugin
      @olex_machine_results_file = main.olex_plugin.olex_machine_file
      @olex_human_results_file = main.olex_plugin.olex_local_detailed_file
      @olex_rollup_results_file = main.olex_plugin.olex_local_rollup_file
      @olex_mif_results_file = main.olex_plugin.olex_mif_file
    end

    swing[:auto=>true]
    @main = main
    @main_frame = @main.main_frame
    @dialog = dialog @main_frame, 'Scan Settings', true do |dlg|
      grid_table_layout dlg
      empty_border 4,4,4,4
      size 600,580
      default_close_operation :HIDE_ON_CLOSE
      grid_row do
        grid_table :i=>[0,10] do
          compound_border etched_border(:LOWERED), empty_border(7,7,7,7)
          defaults :i=>[8,1], :a=>:w
          grid_row {@always_open_archives_check_box = check_box('Always open archives')}
          grid_row {@scan_source_check_box = check_box('Scan source code')}
          grid_row {@windows_binary_scan_check_box = check_box('Look inside Windows binaries')}
          grid_row {@dont_update_rules_check_box = check_box("Don't look for rule updates")}
          grid_row {@all_rules_check_box = check_box('Run slow rules in addition to fast rules')}
          grid_row {@throttling_enabled_check_box = check_box('Enable throttling')}
          grid_row {@always_open_class_file_archives_check_box = check_box('Always open class file archives (like jars)')}
          grid_row {@show_rollup_report_check_box = check_box('Show Rollup Report')}
          grid_row {separator}
          grid_row {label 'The absolute path and filename for the results file to upload to the OLEX Server:'}
          grid_row {@olex_results_file_text_field = text_field() {columns 40}}
          grid_row {separator}
          grid_row {label 'The absolute path and filename for the MIF results file:'}
          grid_row {@olex_mif_results_file_text_field = text_field() {columns 40}}
          grid_row {separator}
          grid_row {label 'The absolute path and filename for the human readable results file:'}
          grid_row {@olex_human_results_file_text_field = text_field() {columns 40}}
          grid_row {separator}
          grid_row {label 'The absolute path and filename for the human readable rollup results file:'}
          grid_row {@olex_rollup_results_file_text_field = text_field() {columns 40}}
        end
      end
      grid_row  do
        grid_table :wy=>0.1, :a=>:s do
          grid_row :i=>4 do
            button('Done') {on_click{do_save}}
            button('Cancel') {on_click{@dialog.visible = false; reset_fields}}
          end
        end
      end
    end
    reset_fields
    @main.center(@main_frame, @dialog)
  end

  def reset_fields
    @always_open_archives_check_box.selected = @always_open_archives
    @scan_source_check_box.selected = @scan_source
    @windows_binary_scan_check_box.selected = @windows_binary_scan
    @dont_update_rules_check_box.selected = @dont_update_rules
    @all_rules_check_box.selected = @all_rules
    @throttling_enabled_check_box.selected = @throttling_enabled
    @always_open_class_file_archives_check_box.selected = @always_open_class_file_archives
    @olex_results_file_text_field.text = @olex_machine_results_file
    @olex_human_results_file_text_field.text = @olex_human_results_file
    @olex_rollup_results_file_text_field.text = @olex_rollup_results_file
    @olex_mif_results_file_text_field.text = @olex_mif_results_file
    @show_rollup_report_check_box.selected = @show_rollup_report
  end

  def do_save
    @always_open_archives = @always_open_archives_check_box.selected
    @scan_source = @scan_source_check_box.selected
    @windows_binary_scan = @windows_binary_scan_check_box.selected
    @dont_update_rules = @dont_update_rules_check_box.selected
    @all_rules = @all_rules_check_box.selected
    @throttling_enabled = @throttling_enabled_check_box.selected
    @always_open_class_file_archives = @always_open_class_file_archives_check_box.selected
    @olex_machine_results_file = @olex_results_file_text_field.text
    @olex_human_results_file = @olex_human_results_file_text_field.text
    @olex_rollup_results_file = @olex_rollup_results_file_text_field.text
    @olex_mif_results_file = @olex_mif_results_file_text_field.text
    @show_rollup_report = @show_rollup_report_check_box.selected
      hide
  end

  def show
    #@dialog.frame = @main_frame
    @dialog.visible = true
  end

  def hide
    @dialog.visible = false
  end

end