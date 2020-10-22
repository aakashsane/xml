!#/bin/csh
set -v
# Automatic Build and Run on Gaea using fre
XML_FILE=CM4_piControl_C_MOM6devgfdl.xml               #The xml to test
RELEASE='2020.03'         #The FMS release to test
MOM6_DATE='20201016'                     #The MOM6 tag date to test
MOM6_GIT_TAG="dev\/gfdl"               #The MOM6 tag to test
FRESTEM="FMS${RELEASE}_mom6_${MOM6_DATE}_sym"  #The FRESTEM to use
GROUP="gfdl_f"
#List of the experiments in the xml to run regression for
EXPERIMENT_LIST="CM4_piControl_C_noBLING CM4_piControl_C_noBLING_EPBL_MLE500 CM4_piControl_C_noBLING_EPBL_MLE2000"
#CM4_piControl_C_noBLING_VERTEXSHEAR"
# CM4_piControl_C CM4_piControl_C_noBLING"

DEBUGLEVEL='_3'
PLATFORM="ncrc4.intel18"
TARGET="prod-openmp"
REFERENCE_TAG='xanadu_mom6_om4_v1.0.5'
FRE_VERSION='test'

#########################################
#Users do not need to edit anything below
#########################################
#rootdir=`dirname $0`
XML_DIR=. #${rootdir}/../
cd ${XML_DIR}
pwd
MYBIN=$HOME/nnz_tools/frerts

FRERTS_BATCH_ARGS="-p ${PLATFORM} -t ${TARGET} --release ${RELEASE} --fre_stem ${FRESTEM} --fre_version ${FRE_VERSION}  --mom_git_tag ${MOM6_GIT_TAG} --mom_date_tag ${MOM6_DATE} --debuglevel ${DEBUGLEVEL} --project ${GROUP} --interactive" 

#FRERTS_ARGS="--compile,--res_num,6,--fre_ops,-u;--no-transfer,--do_frecheck,--reference_tag,${REFERENCE_TAG}" 
#If you do not want to recompile
#FRERTS_ARGS="--res_num,6,--fre_ops,-u;--no-transfer,--do_frecheck,--reference_tag,${REFERENCE_TAG}" 
#If you want only a "basic" regression to run
FRERTS_ARGS="--compile,--no_rts,--res_num,4,--fre_ops,-r;debug;-u;--no-transfer,--do_frecheck,--reference_tag,${REFERENCE_TAG}" 

${MYBIN}/frerts_batch.csh -x ${XML_DIR}/${XML_FILE} ${FRERTS_BATCH_ARGS} --frerts_ops "${FRERTS_ARGS}" ${EXPERIMENT_LIST}

#To just check the status
#${MYBIN}/frerts_status.csh -x $HOME/frerts/${FRESTEM}/${DEBUGLEVEL}/${XML_FILE}.latest -p ${PLATFORM} -t ${TARGET}  ${EXPERIMENT_LIST} -n -r  --frecheck_ops '--ignore-files;icebergs.res.nc'

