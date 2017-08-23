###################################################################
#
#        Refine Atmospheric Diagnostics for CMIP6
#
###################################################################
#  required files -> output file
#  -----------------------------
#  *.atmos_month_cmip.tile?.nc  -> *.atmos_month_refined.tile?.nc
#  *.atmos_daily_cmip.tile?.nc  -> *.atmos_month_refined.tile?.nc
#  *.atmos_daily_cmip.tile?.nc  -> *.atmos_daily_refined.tile?.nc
#  *.atmos_tracer_cmip.tile?.nc -> *.atmos_tracer_refined.tile?.nc
#
#  require variables (set outside this script)
#  -----------------
#  set refineDiagDir = ???   # output directory
#                            # input directory = `cwd`
###################################################################

# git clone the refine diag scripts

set GIT_REPOSITORY = file:///home/bw/git-repository/FMS
set FRE_CODE_TAG = testing_20170720
set PACKAGE_NAME = atmos_refine
set CODE_DIRECTORY = atmos_refine_scripts
git clone -b $FRE_CODE_TAG $GIT_REPOSITORY/$PACKAGE_NAME.git $CODE_DIRECTORY

# check that output directory is defined

if ($?refineDiagDir) then

# run script to create refined fields

   $CODE_DIRECTORY/refineDiag_atmos.csh $CODE_DIRECTORY $refineDiagDir

else
   echo "ERROR: refineDiagDir is not defined - can run refineDiag scripts"
endif

