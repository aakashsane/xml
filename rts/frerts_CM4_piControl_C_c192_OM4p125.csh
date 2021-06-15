!#/bin/csh
set -v
# Automatic Build and Run on Gaea using fre
XML_FILE=CM4_piControl_c192_OM4p125.xml  #The xml to test
RELEASE='2019.01.03'
MOM6_DATE='devgfdl_20210308' #'devgfdl_20201120'            #The MOM6 tag date to test
MOM6_GIT_TAG='b3321c68'      #'dev\/gfdl'      #The MOM6 tag to test
FRESTEM="FMS${RELEASE}_${MOM6_DATE}"  #The FRESTEM to use
GROUP="gfdl_o"
#List of the experiments in the xml to run regression for
EXPERIMENT_LIST="CM4_piControl_c192_OM4p125_v4_hydrography20210614 CM4_piControl_c192_OM4p125_v4_hydrography20210614_recycleICE"

DEBUGLEVEL='_0'
PLATFORM="ncrc4.intel18"
TARGET="prod-openmp"
REFERENCE_TAG='FMS2019.01.03_gfdl_20210308' 
FRE_VERSION='bronx-18'

#########################################
#Users do not need to edit anything below
#########################################
#rootdir=`dirname $0`
XML_DIR=. #${rootdir}/../
#cd ${XML_DIR}
pwd
MYBIN=$HOME/nnz_tools/frerts

#FRERTS_BATCH_ARGS="-p ${PLATFORM} -t ${TARGET} --release ${RELEASE} --fre_stem ${FRESTEM} --fre_version ${FRE_VERSION}  --mom_git_tag ${MOM6_GIT_TAG} --mom_date_tag ${MOM6_DATE} --debuglevel ${DEBUGLEVEL} --project ${GROUP} --interactive" 
FRERTS_BATCH_ARGS="-p ${PLATFORM} -t ${TARGET} --release ${RELEASE} --fre_stem ${FRESTEM} --fre_version ${FRE_VERSION}  --debuglevel ${DEBUGLEVEL} --project ${GROUP} --interactive" 

#FRERTS_ARGS="--compile,--res_num,6,--fre_ops,-u;--no-transfer,--do_frecheck,--reference_tag,${REFERENCE_TAG}" 
#If you do not want to recompile
#FRERTS_ARGS="--res_num,6,--fre_ops,-u;--no-transfer,--do_frecheck,--reference_tag,${REFERENCE_TAG}" 
#If you want only a "basic" regression to run
FRERTS_ARGS="--compile,--no_rts,--res_num,3,--fre_ops,-Z;-r;basic;-u;--no-transfer;-q;urgent,--do_frecheck,--reference_tag,${REFERENCE_TAG}" 

${MYBIN}/frerts_batch.csh -x ${XML_DIR}/${XML_FILE} ${FRERTS_BATCH_ARGS} --frerts_ops "${FRERTS_ARGS}" ${EXPERIMENT_LIST}

#To just check the status
#${MYBIN}/frerts_status.csh -x $HOME/frerts/${FRESTEM}/${DEBUGLEVEL}/${XML_FILE}.latest -p ${PLATFORM} -t ${TARGET}  ${EXPERIMENT_LIST} -n -r  --frecheck_ops '--ignore-files;icebergs.res.nc'

