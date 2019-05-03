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

#-- Find out which commit is currently in use; if this is 
#   a new experiment, checkout the master branch and log
#   the commit hash

set localRoot = `echo $scriptName | rev | cut -f 4-100 -d '/' | rev`

if ( -f ${localRoot}/db/.version ) then
  pushd vitals
  git checkout `cat ${localRoot}/db/.version | cut -f 2 -d ' '`
  popd
else
  mkdir -p ${localRoot}/db/
  pushd vitals
  git checkout master
  echo `git log | head -n 1` > ${localRoot}/db/.version
  popd
endif
  
#-- Source the refineDiag version of the vitals script
source vitals/vitals_refineDiag.csh

date
echo "  ---------- end refineDiag_data_stager.csh ----------  "
