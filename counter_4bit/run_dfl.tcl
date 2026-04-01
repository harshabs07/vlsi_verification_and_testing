# genus -f run_dft.tcl
# lec -nogui -dofile run_lec.do
set_db / .init_lib_search_path ./
set_db / .library { /opt/eda/cadence/FOUNDRY/digital/45nm/NangateOpenCellLibrary_v1.00_20080225/liberty/FreePDK45_lib_v1.0_typical_scan.lib }
read_hdl -sv counter_4bit.sv
elaborate counter_4bit
syn_generic
syn_map
define_dft test_clock -name scan_clk -period 1000 clk
define_dft shift_enable -name SE -active high -create_port SE
check_dft_rules
convert_to_scan
connect_scan_chains -auto_create_chains -preview
connect_scan_chains -auto_create_chains
report dft_chains > scan_chains.rpt
write_hdl > counter_4bit_scan.v
write_do_lec -revised_design counter_4bit_scan.v > rtl2scan.do
exit
