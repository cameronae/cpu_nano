create_clock -name clk -period 37.037 [get_ports {clk}]
# reset_n is asynchronous; synchronize before using in the core.
set_false_path -from [get_ports {reset_n}]
