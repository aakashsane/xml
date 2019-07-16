#!/bin/tcsh -f

#------------------------------------
#PBS -N correct-snc-norm
#PBS -l size=1
#PBS -l walltime=18:00:00
#PBS -r y
#PBS -j oe
#PBS -o
#PBS -q batch
#------------------------------------
#Slurm batch directives
#SBATCH --job-name=correct-snc-norm
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
set frexml

#set environment
if (`gfdl_platform` == "hpcs-csc") then

    source $MODULESHOME/init/csh
    module purge
    module load python 
    module list

else
   echo "ERROR: invalid platform"
   exit 1
endif

#get component and static file
set static_dir=`echo ${in_data_dir} | rev | cut -d '/' -f5- | rev`
set component=`echo ${static_dir} | rev | cut -d '/' -f1 | rev`

set static="${static_dir}/${component}.static.nc"

#get analysis script location
set xml_dir = `echo ${frexml} | rev | cut -d '/' -f2- | rev`
set analysis_script = "${xml_dir}/awg_include/analysis/stub/correct-snc-norm.py"

#set date structure based on frequency
if (${freq} == "daily") then
    set date_range = "${yr1}0101-${yr2}1231"
else if (${freq} == "monthly") then
    set date_range = "${yr1}01-${yr2}12"
endif

set input_file = "${in_data_dir}${component}.${date_range}.snc.nc"

#make a copy of the old file if it doesn't already exist
if (! -e "${in_data_dir}${component}.${date_range}.snc_old.nc") then
    cp ${input_file} "${in_data_dir}${component}.${date_range}.snc_old.nc"
else
    echo "Not copying ${input_file},"${component}.${date_range}.snc_old.nc" already exists"
endif 

echo "Running ${analysis_script}"

chmod +x ${analysis_script}
${analysis_script} -v -l ${static} ${input_file}

