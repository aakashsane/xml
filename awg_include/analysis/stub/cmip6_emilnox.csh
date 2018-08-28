#!/bin/csh -f
#------------------------------------
#PBS -N cmip6_emilnox
#PBS -l size=1
#PBS -l walltime=1:00:00
#PBS -r y
#PBS -j oe
#PBS -o
#PBS -q batch
#------------------------------------
# Source data: pp/aerosol_cmip/ts/monthly/5yr

# variables set by frepp
 set in_data_dir
 set databegyr
 set dataendyr
 set datachunk
 set fremodule
 set freanalysismodule
 set frexml

# output data directory must be writeable by user
 set out_data_dir = $in_data_dir

set xml_dir = `echo ${frexml} | rev | cut -d '/' -f2- | rev` 
set diagnostic_script = "${xml_dir}/awg_include/analysis/stub/cmip6_emilnox_driver.csh"

# make sure valid platform and required modules are loaded
if (`gfdl_platform` == "hpcs-csc") then
   source $MODULESHOME/init/csh
   module purge
   module use -a /home/fms/local/modulefiles
   module load $fremodule
   module load $freanalysismodule
   module load ncarg/6.2.1
else
   echo "ERROR: invalid platform"
   exit 1
endif

# check again?
if (! $?FRE_ANALYSIS_HOME) then
   echo "ERROR: environment variable FRE_ANALYSIS_HOME not set."
   exit 1
endif

##################
# run the script
##################

set options = "-i $in_data_dir -o $out_data_dir -y $databegyr,$dataendyr"

echo Calling $diagnostic_script $options
csh $diagnostic_script $options

