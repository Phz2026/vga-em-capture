# Source this once per image. The external VGA display remains unchanged.
# This script never programs the FPGA or initializes clocks.
namespace eval ::vga_formal {
    variable root [file normalize [file join [file dirname [info script]] ..]]
    variable matlab {D:/MATLAB/R2025b/bin/matlab.exe}
    if {[info exists ::env(VGA_MATLAB_EXE)]} {set matlab $::env(VGA_MATLAB_EXE)}
    variable capture_root {D:/capture}
    if {[info exists ::env(VGA_CAPTURE_ROOT)]} {set capture_root $::env(VGA_CAPTURE_ROOT)}
}

proc ::vga_formal::matlab_string {value} {
    return [string map [list "'" "''" "\\" "/"] $value]
}

proc ::vga_formal::capture {{mode generic}} {
    variable root
    variable matlab
    variable capture_root
    switch -- $mode {
        generic {
            set analyzer analyze_current_image
            set analysis_dir analysis_current
            set png rf_response.png
        }
        bars64 {
            set analyzer analyze_bars64
            set analysis_dir analysis_bars64
            set png bars_measured_profile.png
        }
        default {error "mode must be generic or bars64"}
    }
    if {![file isfile $matlab]} {error "MATLAB not found: $matlab"}
    if {![file isfile [file join $root formal_capture ${analyzer}.m]]} {
        error "MATLAB analyzer missing: $analyzer"
    }
    # Attach by register version and JTAG AXI. This also works in a new Tcl
    # console after the board was programmed, without programming it again.
    uplevel #0 [list source [file join $root scripts hardware session.tcl]]
    if {[catch {::vga_attach; ::vga_check} why]} {
        puts "FORMAL_RECONNECT=$why"
        catch {close_hw_target}
        catch {disconnect_hw_server}
        catch {close_hw_manager}
        ::vga_connect
        ::vga_check
    }
    uplevel #0 [list source [file join $root scripts hardware capture_frame.tcl]]
    ::vga_rfdc_start
    ::vga_set_event_mode 0
    ::vga_set_ddc_target 195.0 1
    ::vga_set_feature_mode magnitude
    ::vga_set_feature_gain 0.125

    set stamp [format "%s_%d" [clock format [clock seconds] -format %Y%m%d_%H%M%S] [clock milliseconds]]
    set capture_dir [file normalize [file join $capture_root formal_${mode}_$stamp frame_01]]
    set run_dir [file dirname $capture_dir]
    if {[file exists $run_dir]} {error "Run directory already exists: $run_dir"}
    file mkdir $run_dir
    puts "FORMAL_STAGE=CAPTURE_UNCHANGED_SCREEN dir=$capture_dir"
    ::capture_frame $capture_dir

    set analysis [file join $run_dir $analysis_dir]
    set success [file join $run_dir matlab_done.ok]
    set failure [file join $run_dir matlab_error.txt]
    set startup [file join $run_dir matlab_startup.m]
    set matlab_log [file join $run_dir matlab.log]
    set f [open $startup w]
    try {
        puts $f "try"
        puts $f [format "  addpath('%s');" [::vga_formal::matlab_string [file join $root formal_capture]]]
        puts $f [format "  %s('%s','%s',true);" $analyzer \
            [::vga_formal::matlab_string $capture_dir] [::vga_formal::matlab_string $analysis]]
        puts $f [format "  fid=fopen('%s','w'); fprintf(fid,'ok'); fclose(fid);" [::vga_formal::matlab_string $success]]
        puts $f "catch ME"
        puts $f "  report=getReport(ME,'extended','hyperlinks','off'); disp(report);"
        puts $f [format "  fid=fopen('%s','w'); fprintf(fid,'%%s',report); fclose(fid);" [::vga_formal::matlab_string $failure]]
        puts $f "end"
    } finally {close $f}
    set matlab_command [format "run('%s');" [::vga_formal::matlab_string $startup]]
    puts "FORMAL_STAGE=MATLAB_GUI_START log=$matlab_log"
    exec $matlab -nosplash -r $matlab_command -logfile $matlab_log &
    set deadline [expr {[clock milliseconds]+240000}]
    while {[clock milliseconds] < $deadline} {
        if {[file isfile $failure]} {
            set f [open $failure r]
            try {set report [read $f]} finally {close $f}
            error "MATLAB analysis failed: $report"
        }
        if {[file isfile $success]} {break}
        after 500
    }
    if {![file isfile $success]} {error "MATLAB did not finish within four minutes; see $matlab_log"}
    foreach name [list $png metrics.txt] {
        if {![file isfile [file join $analysis $name]]} {
            error "Missing MATLAB output $name; see $matlab_log"
        }
    }
    puts "FORMAL_CAPTURE_DONE=$analysis"
    puts FORMAL_IMAGE_MEANING=MEASURED_RF_RESPONSE_NOT_RGB_PIXELS
    return $analysis
}

if {![info exists ::vga_formal_defer_capture] || !$::vga_formal_defer_capture} {
    ::vga_formal::capture generic
}
