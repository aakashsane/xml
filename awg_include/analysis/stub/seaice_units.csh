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
#SBATCH --job-name=seaice_units
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

#multiply siconc and sisnconc by 100 and change units to percent
foreach var (siconc sisnconc) 

    set ifile = "${component}.${date_range}.${var}.nc"
    
    if (! -e ${ifile}) then
        echo "${ifile} not found, skipping ${var} unit conversion"
        continue
    endif

    #dmget file
    dmget ${ifile}

    #check units of variable
    ncdump -h ${ifile} | grep 'units = "%"'
    if $? == 0 then
        echo "Units are already in % for ${var}, skipping unit conversion"
        continue
    endif 
    
    echo "Converting ${var} units from fraction to percent"
    #copy original file to ${var}_old
    cp ${ifile} "${file_prefix}.${var}_old.nc"

    #copy original file to test file, perform nco operations
    cp ${ifile} test.nc
    ncrename -v ${var},"${var}_old" test.nc
    ncap2 -s "${var}=${var}_old*100" test.nc  test1.nc
    ncks -x -v $var"_old"  test1.nc    test2.nc
    ncatted -a units,$var,m,c,"%"  test2.nc
    
    if ${var} == siconc then 
        ncatted -a long_name,$var,m,c,"Sea Ice Area Fraction (Ocean Grid)" test2.nc
    else
        ncatted -a long_name,$var,m,c,"Snow area fraction"  test2.nc
    endif
    
    mv -f test2.nc $ifile
    rm -f test1.nc test.nc

end

#convert sitemptop from deg C to K
foreach var (sitemptop)

    set ifile = "${component}.${date_range}.${var}.nc"

    if (! -e ${ifile}) then
        echo "${ifile} not found, skipping ${var} unit conversion"
        continue
    endif

    #dmget file
    dmget ${ifile}

    #check units of variable
    ncdump -h ${ifile} | grep 'units = "K"'
    if $? == 0 then
        echo "Units are already in K for ${var}, skipping unit conversion"
        continue
    endif 

    echo "Converting sitemptop from degC to K"
    #copy original file to ${var}_old
    cp ${ifile} "${file_prefix}.${var}_old.nc"
    cp ${ifile}  test.nc
    ncrename   -v ${var},"${var}_old"  test.nc 
    ncap2 -s "${var}=(${var}_old*100+27315)/100" test.nc  test1.nc
    ncks -x -v "${var}_old"  test1.nc    test2.nc
    ncatted -a units,${var},m,c,"K"  test2.nc
    ncatted -a long_name,${var},m,c,"Surface temperature of sea ice"  test2.nc

    mv -f test2.nc ${ifile}
    rm -f test1.nc test.nc

end


