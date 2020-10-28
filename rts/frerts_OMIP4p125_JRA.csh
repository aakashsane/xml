!#/bin/csh
set -v
# Automatic Build and Run on Gaea using fre
XML_FILE=OMIP4p125_JRA1.4.xml  #The xml to test
RELEASE='2019.01.03'   #The FMS release to test
MOM6_DATE='2019.08.08'                     #The MOM6 tag date to test
MOM6_GIT_TAG="dev\/gfdl\/2019.08.08" #The MOM6 tag to test
FRESTEM="FMS${RELEASE}_mom6_${MOM6_DATE}_min"         #The FRESTEM to use
GROUP="gfdl_f"
#List of the experiments in the xml to run regression for
EXPERIMENT_LIST="OM4p125_JRA55do1.4_r6_cycle1"

DEBUGLEVEL='_0'
PLATFORM="ncrc4.intel18"
TARGET="prod"
REFERENCE_TAG='xanadu_esm4_20190304_mom6_2019.08.08'
FRE_VERSION='bronx-18'

#########################################
#Users do not need to edit anything below
#########################################
#rootdir=`dirname $0`
XML_DIR=. #${rootdir}/../
#cd ${XML_DIR}
pwd
MYBIN=$HOME/nnz_tools/frerts

FRERTS_BATCH_ARGS="-p ${PLATFORM} -t ${TARGET} --release ${RELEASE} --fre_stem ${FRESTEM} --fre_version ${FRE_VERSION}  --mom_git_tag ${MOM6_GIT_TAG} --mom_date_tag ${MOM6_DATE} --debuglevel ${DEBUGLEVEL} --project ${GROUP} --interactive" 

#FRERTS_ARGS="--compile,--res_num,6,--fre_ops,-r;basic;-u;--no-transfer,--do_frecheck,--reference_tag,${REFERENCE_TAG}" 
#If you do not want to recompile
FRERTS_ARGS="--res_num,6,--fre_ops,-r;basic;-u;--no-transfer,--do_frecheck,--reference_tag,${REFERENCE_TAG}" 
#If you want only a "basic" regression to run
#FRERTS_ARGS="--res_num,3,--no_rts,--fre_ops,-r;debug;-u;--no-transfer,--do_frecheck,--reference_tag,${REFERENCE_TAG}" 

${MYBIN}/frerts_batch.csh -x ${XML_DIR}/${XML_FILE} ${FRERTS_BATCH_ARGS} --frerts_ops "${FRERTS_ARGS}" ${EXPERIMENT_LIST}

#To just check the status
#${MYBIN}/frerts_status.csh -x $HOME/frerts/${FRESTEM}/${DEBUGLEVEL}/${XML_FILE}.latest -p ${PLATFORM} -t ${TARGET}  ${EXPERIMENT_LIST} -r --frecheck_ops '--ignore-files;icebergs.res.nc'

