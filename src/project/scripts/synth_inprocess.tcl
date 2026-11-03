set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root config project.tcl]
source [file join $root scripts relative_source_compat.tcl]
open_project [file join $root build vivado_full_v1 ${PROJECT_NAME}.xpr]
set_property source_mgmt_mode None [current_project]
set_property top ${BD_NAME}_wrapper [current_fileset]
set_property synth_checkpoint_mode None [get_files -filter {FILE_TYPE == "Block Designs"}]
update_compile_order -fileset sources_1
synth_design -top ${BD_NAME}_wrapper -part $PART
file mkdir [file join $root output reports]
report_utilization -file [file join $root output reports integrated_synth_utilization.rpt]
write_checkpoint -force [file join $root output reports integrated_synth.dcp]
puts FULL_V24_INPROCESS_SYNTH_PASS
