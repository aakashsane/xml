#!/bin/tcsh -f

#------------------------------------
#PBS -N recreate_sivol
#PBS -l size=1
#PBS -l walltime=18:00:00
#PBS -r y
#PBS -j oe
#PBS -o
#PBS -q batch
#------------------------------------
#Slurm batch directives
#SBATCH --job-name=recreate_sivol
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

#recreate sivol
set var = sivol

set ifile = "${file_prefix}.${var}.nc"

set ifile_simass = "${file_prefix}.simass.nc"

if (! -e ${ifile}) then
    echo "${ifile} not found, not re-creating ${var}"
    exit 0
endif

#dmget files
dmget ${ifile} ${ifile_simass}

#units of original file are "m-ice"
ncdump -h ${ifile} | grep 'units = "m"'
if $? == 0 then
    echo "Correct ${var} in place, not re-creating ${var}"
    exit
endif

echo "Re-creating sivol"

cp ${ifile} "${file_prefix}.${var}_old.nc"
cp ${ifile_simass} test.nc
ncap2 -s 'sivol=simass/905' test.nc  test1.nc
ncks -x -v simass  test1.nc    test2.nc
ncatted -a units,$var,m,c,"m"  test2.nc
ncatted -a long_name,$var,m,c,"Sea-ice volume per area"  test2.nc

mv -f test2.nc $ifile
rm -f test.nc test1.nc


