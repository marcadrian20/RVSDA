#*****************************************************************************************
# register_ip_repo.tcl
#
# Run this from inside ANY other Vivado project to add the already-packaged RVSDA IP
# to that project's catalog. Assumes scripts/package_ip.tcl has already been run once
# (so build/ip_repo/RVSDA_1_0 exists). Path is resolved relative to this script, not cwd,
# so it works regardless of where the consuming project lives.
#
# Usage (from the Vivado Tcl console, with a project already open):
#   source /path/to/RVSDA/scripts/register_ip_repo.tcl
#*****************************************************************************************

set script_dir  [file dirname [file normalize [info script]]]
set repo_root   [file normalize "$script_dir/.."]
set ip_repo_dir "$repo_root/build/ip_repo/RVSDA_1_0"

if { ![file isdirectory $ip_repo_dir] } {
  puts "ERROR: $ip_repo_dir does not exist yet."
  puts "       Run 'vivado -mode batch -source $repo_root/scripts/package_ip.tcl' first."
  return
}
set existing [get_property ip_repo_paths [current_project]]
# set existing [get_property ip_repo_paths [current_fileset]]
if { [lsearch -exact $existing $ip_repo_dir] < 0 } {
  set_property ip_repo_paths [concat $existing $ip_repo_dir] [current_fileset]
}
if {![file exists "$ip_repo_dir/component.xml"]} {
    error "component.xml not found in $ip_repo_dir"
}
update_ip_catalog -rebuild

puts "INFO: RVSDA registered. Search for it in the IP Catalog under /UserIP, or:"
puts "INFO:   create_ip -name RVSDA -vendor marc.org -library marc -version 1.0 -module_name rvsda_0"
