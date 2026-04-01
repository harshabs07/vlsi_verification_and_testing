set log file lec_run.log -replace
read library -verilog2k /opt/eda/cadence/FOUNDRY/digital/45nm/NangateOpenCellLibrary_v1.00_20080225/verilog/FreePDK45_lib_v1.0_typical.v -both
read design counter_4bit.sv -systemverilog -golden
read design counter_4bit_scan.v -verilog2k -revised
add pin constraint 0 SE -revised
add ignore inputs DFT_sdi_1 -revised
add ignore outputs DFT_sdo_1 -revised
set system mode lec
add compare points -all
compare
report verification -compare_result
exit -force
