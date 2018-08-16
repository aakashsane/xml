#!/bin/csh -f
#------------------------------------
#PBS -N cmip6_combine
#PBS -l size=1
#PBS -l walltime=6:00:00
#PBS -r y
#PBS -j oe
#PBS -o
#PBS -q batch
#------------------------------------
# Source data: pp/COMP/ts/FREQ/XXyr

# variables set by frepp
 set in_data_dir
 set databegyr
 set dataendyr
 set datachunk
 set fremodule
 set freanalysismodule

# output data directory must be writeable by user
 set out_data_dir = $in_data_dir

# make sure valid platform and required modules are loaded
if (`gfdl_platform` == "hpcs-csc") then
   source $MODULESHOME/init/csh
   module purge
   module use -a /home/fms/local/modulefiles
   module load $fremodule
   module load $freanalysismodule
   module load ncarg/6.2.1
   module load git
else
   echo "ERROR: invalid platform"
   exit 1
endif

# check again?
if (! $?FRE_ANALYSIS_HOME) then
   echo "ERROR: environment variable FRE_ANALYSIS_HOME not set."
   exit 1
endif

# clone the source code from the repository if it does not exist

set GIT_REPOSITORY = "file:///home/bw/git-repository/FMS"
set FRE_CODE_TAG = testing_20180409
set PACKAGE_NAME = cmip6_combine
set FRE_CODE_BASE = $TMPDIR/fre-analysis

if (! -e $FRE_CODE_BASE/$PACKAGE_NAME) then
   if (! -e $FRE_CODE_BASE) mkdir $FRE_CODE_BASE
   cd $FRE_CODE_BASE
   git clone -b $FRE_CODE_TAG --recursive $GIT_REPOSITORY/$PACKAGE_NAME.git
endif

##################
# run the script
##################

set options = "-i $in_data_dir -o $out_data_dir -y $databegyr,$dataendyr -c $datachunk"

$FRE_CODE_BASE/$PACKAGE_NAME/cmip6_combine.pl -V $options

