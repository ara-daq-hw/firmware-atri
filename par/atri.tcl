proc get_base_path {} {

    # Determine the base path.
    set atri_core_path [ xfile get atri_core.v name ]
    set atri_core_path_length [ string length $atri_core_path ]
    set base_path_length [ expr $atri_core_path_length - [ string length "/rtl/atri_core.v" ] ]
    set base_path [ string range $atri_core_path 0 [ expr $base_path_length - 1 ] ]

    return $base_path
}

proc get_base_include {} {
    set base_path [ get_base_path ]
    set rtl_path ${base_path}/rtl
    set i2c_path ${rtl_path}/i2c
    set vlib_path ${rtl_path}/Verilog_Library
    set sim_path ${base_path}/sim
    set src_path ${base_path}/src

    set base_include ${rtl_path}|${vlib_path}|${i2c_path}|${sim_path}|${src_path}
    return $base_include
}

proc atri_core {} {

    # Determine the base path.
    set base_path [ get_base_path ]
    
    # Remove ATRI modules
    puts "Removing ATRI modules..."
    # First RTL files...
    set atri_rtl_file_path ${base_path}/rtl/ATRI
    set atri_rtl_file_path_match ${atri_rtl_file_path}/*
    set atri_rtl_files [ search $atri_rtl_file_path_match -type file ]
    collection foreach itr $atri_rtl_files { xfile remove $itr }
    # Then SIM files..
    set atri_sim_file_path ${base_path}/sim/ATRI
    set atri_sim_file_path_match ${atri_sim_file_path}/*
    set atri_sim_files [ search $atri_sim_file_path_match -type file ]
    collection foreach itr $atri_sim_files { xfile remove $itr }
    # Then src files...
    set atri_src_file_path ${base_path}/src/ATRI
    set atri_src_file_path_match ${atri_src_file_path}/*
    set atri_src_files [ search $atri_src_file_path_match -type file ]
    collection foreach itr $atri_src_files { xfile remove $itr }
    # Then ipcore files...
    set atri_ipc_file_path ${base_path}/par/ipcore_dir_ATRI
    set atri_ipc_file_path_match ${atri_ipc_file_path}/*
    set atri_ipc_files [ search $atri_ipc_file_path_match -type file ]
    collection foreach itr $atri_ipc_files { xfile remove $itr }
    
    puts "Removing miniATRI modules..."
    # Remove miniATRI modules
    set miniatri_rtl_file_path ${base_path}/rtl/miniATRI
    set miniatri_rtl_file_path_match ${miniatri_rtl_file_path}/*
    set miniatri_rtl_files [ search $miniatri_rtl_file_path_match -type file ]
    collection foreach itr $miniatri_rtl_files { xfile remove $itr }
    # Then SIM files..
    set miniatri_sim_file_path ${base_path}/sim/miniATRI
    set miniatri_sim_file_path_match ${miniatri_sim_file_path}/*
    set miniatri_sim_files [ search $miniatri_sim_file_path_match -type file ]
    collection foreach itr $miniatri_sim_files { xfile remove $itr }
    # Then src files..
    set miniatri_src_file_path ${base_path}/src/miniATRI
    set miniatri_src_file_path_match ${miniatri_src_file_path}/*
    set miniatri_src_files [ search $miniatri_src_file_path_match -type file ]
    collection foreach itr $miniatri_src_files { xfile remove $itr }
    # Then ipcore files...
    set miniatri_ipc_file_path ${base_path}/par/ipcore_dir_miniATRI
    set miniatri_ipc_file_path_match ${miniatri_ipc_file_path}/*
    set miniatri_ipc_files [ search $miniatri_ipc_file_path_match -type file ]
    collection foreach itr $miniatri_ipc_files { xfile remove $itr }
    
    puts "Removing DDA_EVAL modules..."
    # Remove DDA_EVAL modules
    set ddaeval_rtl_file_path ${base_path}/rtl/DDA_EVAL
    set ddaeval_rtl_file_path_match ${ddaeval_rtl_file_path}/*
    set ddaeval_rtl_files [ search $ddaeval_rtl_file_path_match -type file ]
    collection foreach itr $ddaeval_rtl_files { xfile remove $itr }
    # Then SIM files..
    set ddaeval_sim_file_path ${base_path}/sim/DDA_EVAL
    set ddaeval_sim_file_path_match ${ddaeval_sim_file_path}/*
    set ddaeval_sim_files [ search $ddaeval_sim_file_path_match -type file ]
    collection foreach itr $ddaeval_sim_files { xfile remove $itr }
    # Then src files..
    set ddaeval_src_file_path ${base_path}/src/DDA_EVAL
    set ddaeval_src_file_path_match ${ddaeval_src_file_path}/*
    set ddaeval_src_files [ search $ddaeval_src_file_path_match -type file ]
    collection foreach itr $ddaeval_src_files { xfile remove $itr }
    # Then ipcore files...
    set ddaeval_ipc_file_path ${base_path}/par/ipcore_dir_DDA_EVAL
    set ddaeval_ipc_file_path_match ${ddaeval_ipc_file_path}/*
    set ddaeval_ipc_files [ search $ddaeval_ipc_file_path_match -type file ]
    collection foreach itr $ddaeval_ipc_files { xfile remove $itr }

    # Now UCF files...
    set ucf_files [ search *.ucf -type file ]
    collection foreach itr $ucf_files { xfile remove $itr }

    # Base-ify the Verilog includes...
    set base_include [ get_base_include ]
    project set "Verilog Include Directories" $base_include

    # And now we're done.
    return 0
}

proc ddaeval {} {
    set proj_name [ project get name ]
    puts "This is project $proj_name"
    
    project set family spartan3a
    project set device xc3s700a
    project set package fg484
    project set speed -4

    set base_path [ get_base_path ]
    atri_core
    set prev_dir [ pwd ]
    
    puts "Adding RTL files in rtl/DDA_EVAL..."
    set ddaeval_rtl_path ${base_path}/rtl/DDA_EVAL
    set ddaeval_match_v ${ddaeval_rtl_path}/*.v
    set ddaeval_match_vhd ${ddaeval_rtl_path}/*.vh
    foreach i [ glob -nocomplain $ddaeval_match_v $ddaeval_match_vhd ] { 
	puts "Adding $i"
	xfile add $i -view "All"
    }

    # now add all the files in sim/ATRI...
    set ddaeval_sim_path ${base_path}/sim/DDA_EVAL
    set ddaeval_sim_match_v ${ddaeval_sim_path}/*.v
    set ddaeval_sim_match_vhd ${ddaeval_sim_path}/*.vhd
    foreach i [ glob -nocomplain ${ddaeval_sim_match_v} ${ddaeval_sim_match_vhd} ] {
	puts "Adding $i"
	xfile add $i -view "Simulation"
    }
    

    # now add all the XCOs in par/ipcore_dir_miniATRI...
    set ddaeval_xco_path ${base_path}/par/ipcore_dir_DDA_EVAL
    cd $ddaeval_xco_path
    puts "Adding XCOs in ${ddaeval_xco_path}"
    # For some reason we have to add the XISEs, not the XCOs
    foreach i [ glob -nocomplain *.xise ] { 
	puts "Adding $i"
	xfile add $i 
    }
    project set "Cores Search Directories" $ddaeval_xco_path

    cd ${base_path}/par

    set base_include [ get_base_include ]
    set ddaeval_include ${base_include}|${base_path}/rtl/DDA_EVAL|${base_path}/src/DDA_EVAL|${base_path}/sim/DDA_EVAL
    project set "Verilog Include Directories" $ddaeval_include    

    # Clean the project files...
    project clean
    project save
    project close

    cd $prev_dir
    project open "ATRI.xise"
    project set top DDA_EVAL_ATRI

    # now add the UCF file
    set ddaeval_ucf_path ${base_path}/par/DDA_EVAL_revB.ucf
    xfile add $ddaeval_ucf_path

    return 0
}



proc miniatri {} {
    set proj_name [ project get name ]
    puts "This is project $proj_name"

    project set family spartan6
    project set device xc6slx25
    project set package ftg256
    project set speed -3

    set base_path [ get_base_path ]
    atri_core
    set prev_dir [ pwd ]

    puts "Adding RTL files in rtl/ATRI..."

    # now add all the files in rtl/ATRI...
    set atri_rtl_path ${base_path}/rtl/ATRI
    set atri_match_v ${atri_rtl_path}/*.v
    set atri_match_vhd ${atri_rtl_path}/*.vhd
    foreach i [ glob -nocomplain $atri_match_v $atri_match_vhd ] { 
	puts "Adding $i"
	xfile add $i -view "All"
    }
    puts "Adding RTL files in rtl/miniATRI..."
    # now add all the files in rtl/ATRI...
    set matri_rtl_path ${base_path}/rtl/miniATRI
    set matri_match_v ${matri_rtl_path}/*.v
    set matri_match_vhd ${matri_rtl_path}/*.vhd
    foreach i [ glob -nocomplain $matri_match_v $matri_match_vhd ] { 
	puts "Adding $i"
	xfile add $i -view "All"
    }

    # now add all the files in sim/ATRI...
    set atri_sim_path ${base_path}/sim/ATRI
    cd $atri_sim_path
    foreach i [ glob -nocomplain *.v *.vhd ] { xfile add $i -view "Simulation" }
    # now add all the files in sim/miniATRI
    set matri_sim_path ${base_path}/sim/miniATRI
    cd $matri_sim_path
    foreach i [ glob -nocomplain *.v *.vhd ] { xfile add $i -view "Simulation" }

    # now add all the XCOs in par/ipcore_dir_miniATRI...
    set matri_xco_path ${base_path}/par/ipcore_dir_miniATRI
    cd $matri_xco_path
    # For some reason we have to add the XISEs, not the XCOs
    foreach i [ glob -nocomplain *.xise ] { xfile add $i }
    project set "Cores Search Directories" $matri_xco_path

    set base_include [ get_base_include ]
    set matri_include ${base_include}|${base_path}/rtl/ATRI|${base_path}/src/ATRI|${base_path}/sim/ATRI|${base_path}/rtl/miniATRI|${base_path}/src/miniATRI|${base_path}/sim/miniATRI
    project set "Verilog Include Directories" $matri_include    

    # Clean the project files...
    project clean
    project save
    project close

    cd $prev_dir
    project open "ATRI.xise"
    project set top miniATRI

    # now add the UCF file
    set matri_ucf_path ${base_path}/par/miniATRI.ucf
    xfile add $matri_ucf_path

    return 0
}

proc atri {} {

    set proj_name [ project get name ]
    puts "This is project $proj_name"

    project set family spartan6
    project set device xc6slx150t
    project set package fgg676
    project set speed -2
    
    set base_path [ get_base_path ]

    # OK, now we have the base path. 
    # Now we execute atri_core, which removes all implementation-specific
    # modules.
    atri_core

    # boom, now we're in a raw atri_core state
    set prev_dir [ pwd ]
    
    puts "Adding RTL files in rtl/ATRI..."

    # now add all the files in rtl/ATRI...
    set atri_rtl_path ${base_path}/rtl/ATRI
    set atri_match_v ${atri_rtl_path}/*.v
    set atri_match_vhd ${atri_rtl_path}/*.vhd
    foreach i [ glob -nocomplain $atri_match_v $atri_match_vhd ] { 
	puts "Adding $i"
	xfile add $i -view "All"
    }
    
    # now add all the files in sim/ATRI...
    set atri_sim_path ${base_path}/sim/ATRI
    cd $atri_sim_path
    foreach i [ glob -nocomplain *.v *.vhd ] { xfile add $i -view "Simulation" }
    
    # now add all the XCOs in par/ipcore_dir_ATRI...
    set atri_xco_path ${base_path}/par/ipcore_dir_ATRI
    cd $atri_xco_path
    # For some reason we have to add the XISEs, not the XCOs
    foreach i [ glob -nocomplain *.xise ] { xfile add $i }
    project set "Cores Search Directories" $atri_xco_path

    # and Verilog include directory...
    set base_include [ get_base_include ]
    set atri_include ${base_include}|${base_path}/rtl/ATRI|${base_path}/src/ATRI|${base_path}/sim/ATRI
    project set "Verilog Include Directories" $atri_include

    # Clean the project files...
    project clean
    project save
    project close

    cd $prev_dir
    project open "ATRI.xise"
    project set top ATRI_revB

    # now add the UCF file
    set atri_ucf_path ${base_path}/par/ATRI_revB.ucf
    xfile add $atri_ucf_path

    return 0
}

proc update_base_ipcore { arg1 } {

    # Get the argument passed to us
    set ipcore_path $arg1
    
    if { [ file exists $ipcore_path ] == 0 } {
	puts $ipcore_path "does not exist or is not readable."
	return 1
    }
    
    set ipcore_name [ file tail $ipcore_path ]
    
    # Determine the base path.
    set atri_core_path [ xfile get atri_core.v name ]
    set atri_core_path_length [ string length $atri_core_path ]
    set base_path_length [ expr $atri_core_path_length - [ string length "/rtl/atri_core.v" ] ]
    set base_path [ string range $atri_core_path 0 [ expr $base_path_length - 1 ] ]
    
    set baseify ${base_path}/par/baseify_core.pl
    
    set base_ipcore_dir ${base_path}/par/ipcore_dir
    set atri_ipcore_dir ${base_path}/par/ipcore_dir_ATRI
    set miniatri_ipcore_dir ${base_path}/par/ipcore_dir_miniATRI
    set ddaeval_ipcore_dir ${base_path}/par/ipcore_dir_DDA_EVAL
    
    puts "Generating ATRI core..."
    
    # OK, now we copy the XCO over, *without* any of the device identifiers
    set atri_core_name ${atri_ipcore_dir}/${ipcore_name}
    set atri_proj_name ${atri_ipcore_dir}/coregen.cgp
    exec xilperl $baseify $ipcore_path $atri_core_name
    if { [catch { exec coregen -b $atri_core_name -p $atri_proj_name } msg] } {
	puts "coregen for ATRI exited with $::errorInfo"
    }
    
    
    
    puts "Generating miniATRI core..."
    
    # OK, now we copy the XCO over, *without* any of the device identifiers
    set miniatri_core_name ${miniatri_ipcore_dir}/${ipcore_name}
    set miniatri_proj_name ${miniatri_ipcore_dir}/coregen.cgp
    exec xilperl $baseify $ipcore_path $miniatri_core_name
    if { [catch { exec coregen -b $miniatri_core_name -p $miniatri_proj_name } msg] } {
	puts "coregen for miniATRI exited with $::errorInfo"
    }
    
    
    puts "Generating DDA_EVAL core..."
    
    # OK, now we copy the XCO over, *without* any of the device identifiers
    set ddaeval_core_name ${ddaeval_ipcore_dir}/${ipcore_name}
    set ddaeval_proj_name ${ddaeval_ipcore_dir}/coregen.cgp
    exec xilperl $baseify $ipcore_path $ddaeval_core_name
    if { [catch { exec coregen -b $ddaeval_core_name -p $ddaeval_proj_name } msg] } {
	puts "coregen for DDA_EVAL exited with $::errorInfo"
    }

}