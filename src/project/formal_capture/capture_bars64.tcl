# Optional known-pattern diagnostic. No new programming, no screen control.
set ::vga_formal_defer_capture 1
source [file join [file dirname [info script]] capture_current.tcl]
unset ::vga_formal_defer_capture
::vga_formal::capture bars64
