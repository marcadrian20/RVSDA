
set script_dir [file dirname [file normalize [info script]]]
set repo_root  [file normalize "$script_dir/.."]


set ::ARRAY_SIZE       8
set ::DATA_WIDTH       8
set ::IMEM_ADDR_WIDTH  11
set ::BRAM_ADDR_WIDTH  12
set ::ACC_WIDTH        24
set skip_package       0

proc is_batch_mode {} {
    return [expr {[info exists ::rdi::mode] && $::rdi::mode == "batch"}]
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
                exit 0
            }
            "--skip-package" {
                set skip_package 1
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
puts "INFO: Starting RVSDA sim flow with parameters:"
puts "  ARRAY_SIZE       = $::ARRAY_SIZE"
puts "  DATA_WIDTH       = $::DATA_WIDTH"
puts "  IMEM_ADDR_WIDTH  = $::IMEM_ADDR_WIDTH"
puts "  BRAM_ADDR_WIDTH  = $::BRAM_ADDR_WIDTH"
puts "  ACC_WIDTH        = $::ACC_WIDTH"

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
source "$script_dir/create_sim.tcl"
puts "INFO: Launching simulation..."
launch_simulation -simset sim_1 -mode behavioral
run all
if {[is_batch_mode]} {    
    exit
}