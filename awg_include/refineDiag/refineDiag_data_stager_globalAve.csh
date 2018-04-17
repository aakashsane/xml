#------------------------------------------------------------------------------
#  refineDiag_data_stager_globalAve.csh
#------------------------------------------------------------------------------

echo "  ---------- begin refineDiag_data_stager.csh ----------  "
date

#-- Change into the working directory
cd $work/$hsmdate
pwd

#-- Get a version-controlled copy of the analysis scripts
git clone file:///home/mdteam/DET/analysis/vitals
git checkout dev/master/2018.04.17
pushd vitals ; echo `git log | head -n 3` ; popd

#-- Source the refineDiag version of the vitals script
source vitals/vitals_refineDiag.csh

date
echo "  ---------- end refineDiag_data_stager.csh ----------  "
