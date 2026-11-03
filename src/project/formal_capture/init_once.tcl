# Run once in Vivado Hardware Manager's Tcl Console after opening the project.
# This programs the released BIT, initializes PS/PL clocks, and attaches JTAG.
# Re-sourcing in the same Tcl session is harmless: it does not program again.
namespace eval ::vga_formal {
    variable root [file normalize [file join [file dirname [info script]] ..]]
    variable initialized
    if {![info exists initialized]} {set initialized 0}
    variable xsdb {D:/AMDDesignTools/2026.1/Vivado/bin/xsdb.bat}
    if {[info exists ::env(VGA_XSDB_EXE)]} {set xsdb $::env(VGA_XSDB_EXE)}
}

proc ::vga_formal::initialize {} {
    variable root
    variable initialized
    variable xsdb
    if {$initialized} {
        puts FORMAL_ALREADY_INITIALIZED_NO_REPROGRAM
        return
    }
    foreach p [list $xsdb \
        [file join $root output bitstream full_v24.bit] \
        [file join $root output bitstream full_v24.ltx] \
        [file join $root scripts hardware init_ps_for_jtag.tcl] \
        [file join $root build vivado_full_v1 full_v24.gen sources_1 bd vga_em_bd ip vga_em_bd_ps_0 psu_init.tcl]] {
        if {![file isfile $p]} {error "Required initialization file missing: $p"}
    }
    set log_dir [file join $root formal_capture runs]
    file mkdir $log_dir
    set clock_log [file join $log_dir [format "clock_%d.log" [clock milliseconds]]]
    puts FORMAL_STAGE=PROGRAM_BIT_ONCE
    catch {close_hw_target}
    catch {disconnect_hw_server}
    catch {close_hw_manager}
    uplevel #0 [list source [file join $root scripts hardware program_v24.tcl]]
    puts FORMAL_STAGE=INITIALIZE_CLOCKS
    if {[catch {exec $xsdb [file join $root scripts hardware init_ps_for_jtag.tcl] >$clock_log 2>@1} why]} {
        error "XSDB clock initialization failed: $why; see $clock_log"
    }
    set f [open $clock_log r]
    try {set log [read $f]} finally {close $f}
    foreach marker {PS_INIT_FOR_JTAG_PASS IOPLL_LOCK=1 PL0_CLOCK_ACTIVE=1} {
        if {[string first $marker $log] < 0} {
            error "Missing clock check $marker; see $clock_log"
        }
    }
    uplevel #0 [list source [file join $root scripts hardware session.tcl]]
    ::vga_connect
    ::vga_check
    ::vga_rfdc_start
    set initialized 1
    puts FORMAL_READY_REUSE_BIT_AND_CLOCKS
}

::vga_formal::initialize
