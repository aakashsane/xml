#!/bin/tcsh -f

#------------------------------------
#PBS -N seaice_units
#PBS -l size=1
#PBS -l walltime=18:00:00
#PBS -r y
#PBS -j oe
#PBS -o
#PBS -q batch
#------------------------------------
#Slurm batch directives
#SBATCH --job-name=toz_units
#SBATCH --time=18:00:00
#SBATCH --requeue
#SBATCH --output
#SBATCH -p batch
#------------------------------------

#Fields set by frepp
set in_data_dir
set yr1 
set yr2
set argu
set freq

#parse commandline options passed to frepp
set argv = (`getopt c: $* echo ${argu}`)
while ( "$argv[1]" != "--" )
    switch ($argv[1])
        case -c:
            set component = $argv[2]; shift argv; breaksw
    endsw
    shift argv
end
shift argv

#set environment
if (`gfdl_platform` == "hpcs-csc") then

    source $MODULESHOME/init/csh
    module purge
    module load netcdf
    module load nco/4.5.4
    module list

else
   echo "ERROR: invalid platform"
   exit 1
endif

#set date structure based on frequency
if (${freq} == "daily") then
    set date_range = "${yr1}0101-${yr2}1231"
else if (${freq} == "monthly") then
    set date_range = "${yr1}01-${yr2}12"
endif

set file_prefix = "${component}.${date_range}"

#cd to in_data_dir location
cd ${in_data_dir}

#multiply toz by 1.0e-5 and change unit from dobson unit (DB) to m
foreach var ( toz ) 

    set ifile = "${component}.${date_range}.${var}.nc"
    
    if (! -e ${ifile}) then
        echo "${ifile} not found, skipping ${var} unit conversion"
        continue
    endif

    #dmget file
    dmget ${ifile}

    #check units of variable
    ncdump -h ${ifile} | grep 'units = "m"'
    if $? == 0 then
        echo "Units are already in m for ${var}, skipping unit conversion"
        continue
    endif 
    
    echo "Converting ${var} units from DB to m"
    #copy original file to ${var}_old
    cp ${ifile} "${file_prefix}.${var}_old.nc"

    #copy original file to test file, perform nco operations
    ncap2 -s 'toz=toz*1.e-5' $ifile test1.nc
    ncatted -a units,$var,m,c,"m"  test1.nc
    mv -f test1.nc  $ifile
    rm -f test1.nc 
end


