## =========================
## Z7-Lite
## =========================

## 50 MHz PL clock
set_property PACKAGE_PIN N18 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -name sys_clk -period 20.000 [get_ports clk]

## Reset button from PL
set_property PACKAGE_PIN P16 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports rst]
set_property PULLUP true [get_ports rst]

## UART RX in PL
set_property PACKAGE_PIN F17 [get_ports rx_i]
set_property IOSTANDARD LVCMOS33 [get_ports rx_i]

## UART TX out PL
set_property PACKAGE_PIN F16 [get_ports tx_o]
set_property IOSTANDARD LVCMOS33 [get_ports tx_o]

## Debug LED
set_property PACKAGE_PIN P15 [get_ports dbg_led]
set_property IOSTANDARD LVCMOS33 [get_ports dbg_led]