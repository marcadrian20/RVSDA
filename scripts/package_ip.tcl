#*****************************************************************************************
# RVSDA — portable Vivado IP packaging script (v2)
#
# Usage:
#   vivado -mode batch -source scripts/package_ip.tcl
#   vivado -mode batch -source scripts/package_ip.tcl -tclargs --keep-project
#   vivado -mode batch -source scripts/package_ip.tcl -tclargs --part xc7z020clg484-1
#
# No header (.vh/.svh) handling — none exist in this design.
#*****************************************************************************************

set script_dir [file dirname [file normalize [info script]]]
set repo_root  [file normalize "$script_dir/.."]
set rtl_dir    "$repo_root/rtl"
set build_dir  "$repo_root/build"

set part        "xc7z020clg484-1"
set ip_vendor    "marc.org"
set ip_library   "marc"
set ip_name      "RVSDA"
set ip_version   "1.0"
set keep_project 0

if { $::argc > 0 } {
  for {set i 0} {$i < $::argc} {incr i} {
    switch -- [lindex $::argv $i] {
      "--part"          { incr i; set part [lindex $::argv $i] }
      "--vendor"        { incr i; set ip_vendor [lindex $::argv $i] }
      "--library"       { incr i; set ip_library [lindex $::argv $i] }
      "--name"          { incr i; set ip_name [lindex $::argv $i] }
      "--version"       { incr i; set ip_version [lindex $::argv $i] }
      "--keep-project"  { set keep_project 1 }
    }
  }
}

set proj_name   "package_ip"
set proj_dir    "$build_dir/$proj_name"
set ip_repo_dir "$build_dir/ip_repo/${ip_name}_1_0"

puts "INFO: Packaging $ip_name v$ip_version for part $part"
puts "INFO: repo_root = $repo_root"

# ----------------------------------------------------------------------------------------
# 1. Fresh scratch project. -set_current false keeps this from disturbing any project
#    that might already be open (matters when this is sourced as part of a CI batch
#    that packages several IPs, or from inside an interactive Vivado session).
# ----------------------------------------------------------------------------------------
file delete -force $proj_dir
file mkdir $build_dir

# create_project $proj_name $proj_dir -part $part -force -set_current false
create_project \
    $proj_name \
    $proj_dir \
    -part $part \
    -force
set proj [get_projects $proj_name]
current_project $proj

set fileset [current_fileset]

# ----------------------------------------------------------------------------------------
# 2. Recursive source discovery — no per-file path list to maintain. Anything under
#    rtl/ with a Verilog/SystemVerilog extension gets pulled in automatically, so
#    reorganizing rtl/ subfolders (as in the current tree) needs no script changes.
# ----------------------------------------------------------------------------------------
proc add_recursive {dir fileset} {
  set found 0
  foreach f [glob -nocomplain -types f -directory $dir *] {
    if {[regexp {\.(v|sv)$} $f]} {
      add_files -norecurse -fileset $fileset $f
      incr found
    }
  }
  foreach d [glob -nocomplain -types d -directory $dir *] {
    incr found [add_recursive $d $fileset]
  }
  return $found
}

set n_added [add_recursive $rtl_dir $fileset]
puts "INFO: added $n_added source file(s) from $rtl_dir"
if { $n_added == 0 } {
  puts "ERROR: no .v/.sv files found under $rtl_dir"
  exit 1
}

# Anything ending in .sv needs the file_type set explicitly so Vivado treats it as
# SystemVerilog rather than guessing from content.
foreach fobj [get_files -of_objects $fileset -filter {FILE_TYPE == Verilog}] {
  if { [string match "*.sv" [get_property NAME $fobj]] } {
    set_property file_type SystemVerilog $fobj
  }
}

set_property top RVSDA $fileset
set_property top_auto_set 0 $fileset
update_compile_order -fileset $fileset

# ----------------------------------------------------------------------------------------
# 3. Package as IP
# ----------------------------------------------------------------------------------------
ipx::package_project \
  -root_dir $ip_repo_dir \
  -vendor $ip_vendor \
  -library $ip_library \
  -taxonomy "/UserIP" \
  -import_files \
  -set_current true

set core [ipx::current_core]
set_property name        $ip_name    $core
set_property version     $ip_version $core
set_property display_name $ip_name   $core

# Interfaces are inferred by package_project already, but doing it again explicitly
# makes the intent visible in the script and is a safe no-op if nothing changed.
ipx::infer_bus_interfaces $core

# ----------------------------------------------------------------------------------------
# 4. Custom GUI parameters
# ----------------------------------------------------------------------------------------
set hdl_params {
  ARRAY_SIZE       {}
  DATA_WIDTH       {}
  IMEM_ADDR_WIDTH  {}
  BRAM_ADDR_WIDTH  12
  ACC_WIDTH        24
}

foreach {pname pval} $hdl_params {
  if { $pval ne "" } {
    catch { set_property value $pval [ipx::get_user_parameters $pname -of_objects $core] }
    catch { set_property value $pval [ipx::get_hdl_parameters  $pname -of_objects $core] }
  }
  set disp [string totitle [string map {_ " "} $pname]]
  catch {
    ipgui::add_param -name $pname -component $core \
      -display_name $disp -show_label true -show_range true
  }
}

# ----------------------------------------------------------------------------------------
# 5. AXI-Lite register map (S_AXI / reg0)
# ----------------------------------------------------------------------------------------
set mmap   [ipx::get_memory_maps S_AXI -of_objects $core]
set ablock [ipx::get_address_blocks reg0 -of_objects $mmap]

set regs {
  CTRL     NPU_CTRL_REG     0
  STATUS   NPU_STATUS_REG   4
  DDR_BASE NPU_DDR_BASE_REG 8
}

foreach {rname disp offset} $regs {
  if { [ipx::get_registers $rname -of_objects $ablock] eq "" } {
    ipx::add_register $rname $ablock
  }
  set reg [ipx::get_registers $rname -of_objects $ablock]
  set_property display_name   $disp   $reg
  set_property address_offset $offset $reg
  set_property size           32      $reg
}

# M00_AXI maps directly into the system address space rather than exposing its own
# private address window.
catch { ipx::remove_address_space M00_AXI $core }

# ----------------------------------------------------------------------------------------
# 6. Finalize, validate, and save — fail loudly instead of silently warning
# ----------------------------------------------------------------------------------------
set_property core_revision 1 $core
ipx::create_xgui_files $core
ipx::update_checksums  $core

if {[catch {ipx::check_integrity $core} err]} {
    puts stderr "ERROR: $err"
    exit 1
}

ipx::save_core $core

puts "INFO: RVSDA packaged successfully."
puts "INFO: IP repo location: $ip_repo_dir"

# ----------------------------------------------------------------------------------------
# 7. Register with the IP catalog
#    - If a real project (not this scratch one) is already current in this Vivado
#      session, register the repo path against it directly.
#    - Otherwise (standalone batch run) print the snippet to add it to a future project.
# ----------------------------------------------------------------------------------------
close_project
if { !$keep_project } {
  file delete -force $proj_dir
} else {
  puts "INFO: --keep-project set, scratch project left at $proj_dir"
}

set other_projects [get_projects -quiet]
set registered 0
foreach p $other_projects {
  if { $p ne $proj_name } {
    current_project $p
    set existing [get_property ip_repo_paths [current_fileset]]
    if { [lsearch -exact $existing $ip_repo_dir] < 0 } {
      set_property ip_repo_paths [concat $existing $ip_repo_dir] [current_fileset]
      update_ip_catalog -rebuild
    }
    puts "INFO: registered $ip_repo_dir with open project '$p'"
    set registered 1
  }
}

if { !$registered } {
  puts "INFO: no other open project found in this session — to use RVSDA elsewhere,"
  puts "INFO: either run scripts/register_ip_repo.tcl from that project, or run:"
  puts ""
  puts "  set_property ip_repo_paths \[concat \[get_property ip_repo_paths \[current_fileset\]\] {$ip_repo_dir}\] \[current_fileset\]"
  puts "  update_ip_catalog -rebuild"
}