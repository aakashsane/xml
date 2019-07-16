#!/bin/tcsh -f

#------------------------------------
#PBS -N albisccp-units
#PBS -l size=1
#PBS -l walltime=18:00:00
#PBS -r y
#PBS -j oe
#PBS -o
#PBS -q batch
#------------------------------------
#Slurm batch directives
#SBATCH --job-name=albisccp-units
#SBATCH --time=18:00:00
#SBATCH --requeue
#SBATCH --output
#SBATCH -p batch
#------------------------------------

#Fields set by frepp
set in_data_dir
set yr1
set yr2
set freq

#set environment
if ( `gfdl_platform` == "hpcs-csc" ) then

    source $MODULESHOME/init/csh
    module purge
    module load netcdf
    module load nco/4.5.4
    module list
else
    echo "ERROR: Invalid platform"
    exit 1
endif

#get component from in_data_dir
set component=`echo $in_data_dir | rev | cut -d '/' -f5 | rev`

set var="albisccp"

#input filename
if ( ${freq} == "daily" )then
    set range="${yr1}0101-${yr2}1231"
else    
    set range="${yr1}01-${yr2}12"
endif

set ifile="${component}.${range}.${var}.nc"

cd ${in_data_dir}

if ( ! -e ${ifile} ) then
    echo " ${ifile} not found, skipping analysis"
    exit 1
endif
    
dmget ${ifile}

#check to see if the file has already been modified by checking history attribute
ncdump -h ${ifile} | grep "ncap2 --overwrite -s"
if $? == 0 then
    echo "${ifile} has already been modified, exiting"
    exit 0
else
    echo "Modifying values of ${ifile}"
endif

#make a copy
cp ${ifile} "${component}.${range}.${var}_old.nc"

#Divide $var by 100
cp ${ifile} test.nc
ncap2 --overwrite -s "${var}=${var}*0.01" ${ifile} test.nc
if $? == 0 then
    mv test.nc ${ifile}
else
    echo "Error when modifying values from percent to fraction of ${ifile}"
    rm test.nc
    exit 1
endif


