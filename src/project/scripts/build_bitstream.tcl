# Windows-safe single-process build. This avoids OOC launchers that may fail
# with CScript access-denied errors on managed hosts.
set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts synth_inprocess.tcl]
close_project
source [file join $root scripts implement_inprocess.tcl]
