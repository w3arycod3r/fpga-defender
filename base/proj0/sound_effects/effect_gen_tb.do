onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /effect_gen_tb/reset_n
add wave -noupdate /effect_gen_tb/test_clk
add wave -noupdate /effect_gen_tb/effect_cmd
add wave -noupdate /effect_gen_tb/buzz_out
add wave -noupdate /effect_gen_tb/UUT/r_state
add wave -noupdate -radix hexadecimal /effect_gen_tb/UUT/r_romAddr
add wave -noupdate -radix unsigned /effect_gen_tb/UUT/w_romData
add wave -noupdate /effect_gen_tb/UUT/r_buzzDisable
add wave -noupdate -radix hexadecimal /effect_gen_tb/UUT/r_buzzDivisor
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 236
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {194325 ps}
run 4000 ns