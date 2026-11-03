# PS pl_clk0 is generated internally by the Zynq UltraScale+ MPSoC block.
# RFDC ADC, reference-clock and SYSREF dedicated pins are owned by the RFDC IP.

# Only the asynchronous input of the first loss synchronizer stage is exempt.
# Later synchronizer stages remain timed in the PL clock domain.
set_false_path -to [get_pins -hier -quiet -regexp {.*loss_cdc.*ff_reg\[0\]/D}]

# CDC data buses are carried exclusively by the asynchronous AXIS FIFO IP.
# Do not add broad clock-group or false-path constraints here.
