# V2.4 V2.1-complete adaptive scan/raw-IQ hardware smoke test.
# The FPGA must already be programmed and PS_INIT_FOR_JTAG_PASS must have run.
set opt_test_root [file normalize [file join [file dirname [info script]] ../..]]
source [file join $opt_test_root scripts hardware session.tcl]
source [file join $opt_test_root scripts hardware capture_spectrum.tcl]

proc vga_opt_link_test {directory} {
  vga_attach
  vga_check
  vga_rfdc_start
  vga_rfdc_diag
  capture_spectrum $directory
  puts "OPT_LINK_TEST_PASS"
  puts "NEXT: analyze $directory/spectrum.csv"
}
