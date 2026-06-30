#*****************************************************************************************
# run_proj.tcl – Master script for RVSDA full flow
#
# Usage:
#   vivado -mode batch -source scripts/run_proj.tcl -tclargs [options]
#
# Options:
#   --help                    Show this help.
#   --skip-package            Skip IP packaging (assumes IP already built).
#   --ARRAY_SIZE <n>          Default 8.
#   --DATA_WIDTH <n>          Default 32.
#   --IMEM_ADDR_WIDTH <n>     Default 10.
#   --BRAM_ADDR_WIDTH <n>     Default 12.
#   --ACC_WIDTH <n>           Default 24 (160 MHz), 32 (140 MHz).
#   --jobs <n>                Number of parallel jobs (default 4).
#
# Example:
#   vivado -mode batch -source scripts/run_proj.tcl -tclargs --ARRAY_SIZE 16 --ACC_WIDTH 32
#*****************************************************************************************

set script_dir [file dirname [file normalize [info script]]]
set repo_root  [file normalize "$script_dir/.."]

# Default parameter values
set ::ARRAY_SIZE       8
set ::DATA_WIDTH       8
set ::IMEM_ADDR_WIDTH  11
set ::BRAM_ADDR_WIDTH  12
set ::ACC_WIDTH        24
set skip_package       0
set jobs               16
proc is_gui_mode {} {
    return [expr {[info exists ::rdi::mode] && $::rdi::mode == "gui"}]
}
if {$::argc > 0} {
    for {set i 0} {$i < $::argc} {incr i} {
        set opt [lindex $::argv $i]
        switch -- $opt {
            "--help" {
                puts "Usage: vivado -mode batch -source scripts/run_proj.tcl -tclargs \[options\]"
                puts "Options:"
                puts "  --help                    Show this help."
                puts "  --skip-package            Skip IP packaging."
                puts "  --ARRAY_SIZE <n>          Default 8."
                puts "  --DATA_WIDTH <n>          Default 8."
                puts "  --IMEM_ADDR_WIDTH <n>     Default 11."
                puts "  --BRAM_ADDR_WIDTH <n>     Default 12."
                puts "  --ACC_WIDTH <n>           Default 24 (160 MHz), 32 (140 MHz)."
                puts "  --jobs <n>                Number of parallel jobs (default 4)."
                exit 0
            }
            "--skip-package" {
                set skip_package 1
            }
            "--jobs" {
                incr i; set jobs [lindex $::argv $i]
            }
            "--ARRAY_SIZE" {
                incr i; set ::ARRAY_SIZE [lindex $::argv $i]
            }
            "--DATA_WIDTH" {
                incr i; set ::DATA_WIDTH [lindex $::argv $i]
            }
            "--IMEM_ADDR_WIDTH" {
                incr i; set ::IMEM_ADDR_WIDTH [lindex $::argv $i]
            }
            "--BRAM_ADDR_WIDTH" {
                incr i; set ::BRAM_ADDR_WIDTH [lindex $::argv $i]
            }
            "--ACC_WIDTH" {
                incr i; set ::ACC_WIDTH [lindex $::argv $i]
            }
            default {
                puts "ERROR: Unknown option '$opt'."
                puts "Use --help for usage."
                exit 1
            }
        }
    }
}

puts "INFO: Starting RVSDA flow with parameters:"
puts "  ARRAY_SIZE       = $::ARRAY_SIZE"
puts "  DATA_WIDTH       = $::DATA_WIDTH"
puts "  IMEM_ADDR_WIDTH  = $::IMEM_ADDR_WIDTH"
puts "  BRAM_ADDR_WIDTH  = $::BRAM_ADDR_WIDTH"
puts "  ACC_WIDTH        = $::ACC_WIDTH"
puts "  Parallel jobs    = $jobs"

set ip_repo_dir "$repo_root/build/ip_repo/RVSDA_1_0"
if {!$skip_package} {
    puts "INFO: Packaging IP..."
    source "$script_dir/package_ip.tcl"
    # package_ip.tcl builds the IP in build/ip_repo/RVSDA_1_0
} else {
    if {![file exists "$ip_repo_dir/component.xml"]} {
        puts "ERROR: --skip-package specified but IP not found at $ip_repo_dir."
        puts "Please run without --skip-package first."
        exit 1
    }
    puts "INFO: Skipping packaging (using existing IP)."
}


puts "INFO: Creating project..."
source "$script_dir/create_project.tcl"

puts "INFO: Launching synthesis..."
launch_runs synth_1 -jobs $jobs
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed."
    exit 1
}

puts "INFO: Launching implementation..."
launch_runs impl_1 -jobs $jobs
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed."
    exit 1
}

puts "INFO: Generating bitstream..."
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1

set proj_dir [get_property directory [current_project]]
set bitfile "$proj_dir/${::_xil_proj_name_}.runs/impl_1/npu_bd_wrapper.bit"
if {[file exists $bitfile]} {
    puts "INFO: Bitstream generated successfully: $bitfile"
    puts "INFO: RVSDA flow completed."
    if {![is_gui_mode]} {
        exit 0
    }
} else {
    puts "ERROR: Bitstream not found at expected location: $bitfile"
    exit 1
}