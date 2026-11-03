# Resolve a relative source beside the calling script when a Windows launcher
# changes Vivado's working directory.
if {[llength [info commands vga_original_source]] == 0} {
  rename source vga_original_source
  proc source {args} {
    set target [lindex $args end]
    if {[file pathtype $target] eq "relative" && ![file exists $target]} {
      set parent [uplevel 1 {info script}]
      set sibling [file join [file dirname $parent] $target]
      if {[file exists $sibling]} {set args [lreplace $args end end $sibling]}
    }
    uplevel 1 [list vga_original_source {*}$args]
  }
}
