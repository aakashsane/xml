#!/bin/tcsh -f

#------------------------------------
#PBS -N dynvar_driver
#PBS -l size=1
#PBS -l walltime=18:00:00
#PBS -r y
#PBS -j oe
#PBS -o
#PBS -q batch
#------------------------------------

#dynvar analysis/refine diag wrapper

#This analysis wrapper runs the underlying "tem_diags.py" script written by Pu Lin. It takes 6 hourly instantaneous 
#ua, va, ta, wap fields on 26 pressure levels and outputs daily and monthly zonal averages for DynVarMIP diagnostics. 
#This script takes regridded post-process files from archive and outputs the daily and monthly average netcdf files alongside the 
#original 6hr files in the format /atmos_plev26_2deg_6hr/ts/{daily, monthly}/1yr/ .

#Fields set by frepp
set in_data_dir 
set yr1
set yr2
set frexml

set xml_dir = `echo ${frexml} | rev | cut -d '/' -f2- | rev` 
set diagnostic_script = "${xml_dir}/awg_include/analysis/stub/tem_diags.py"

#set environment
if (`gfdl_platform` == "hpcs-csc") then
    
    module purge
    source $MODULESHOME/init/csh
    module load python
    module load netcdf
    module load gcp

    module list

else
   echo "ERROR: invalid platform"
   exit 1
endif

#clean up $TMPDIR
`wipetmp`

#create workDir
set workDir = `mktemp -d -p $TMPDIR`

if ($? != 0) then
    echo "ERROR: cannot create $TMPDIR"
    exit 1
endif

echo ${workDir}
cd ${workDir}

#run diagnostic script
echo "Running ${diagnostic_script} ${in_data_dir} ${workDir} ${yr1} ${yr2}"

python ${diagnostic_script} ${in_data_dir} "${workDir}/" ${yr1} ${yr2}

if ($? != 0) then
    echo "ERROR: Error in ${diagnostic_script}"
    exit 1
endif

#transfer output from workDir to archive
echo "Transfer files from ${workDir}"
set dirs = `find . -mindepth 1 -type d`
foreach dir (${dirs})
    set dir = `echo ${dir} | cut -d '/' -f2-`
    echo ${dir} 
    set final_out = `echo ${in_data_dir} | sed -e 's|\(.*\)6hr|\1'${dir}'|'`
    echo gcp -v -cd ${dir}/* ${final_out}
    gcp -v -cd ${dir}/* ${final_out}

    if ($? != 0) then
        echo "ERROR: Error in gcp"
        exit 1
    endif
end

echo "Script completed"

exit 0 


