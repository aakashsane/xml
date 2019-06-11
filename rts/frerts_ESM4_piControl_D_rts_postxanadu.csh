!#/bin/csh
set -v
# Automatic Build and Run on Gaea using fre
XML_FILE=ESM4_piControl_D_rts_postxanadu.xml  #The xml to test
RELEASE='testing_20190422'                 #The FMS release to test
MOM6_DATE='ESM4_v1.0.3'                #The MOM6 tag date to test
MOM6_GIT_TAG="ESM4\\\/v1.0.3"          #The MOM6 tag to test
FRESTEM="${RELEASE}_mom6_${MOM6_DATE}"  #The FRESTEM to use
GROUP="gfdl_f"
#List of the experiments in the xml to run regression for
EXPERIMENT_LIST="ESM4_piControl_D AM4p1_1850C_PIpcairco2_1850LU"

DEBUGLEVEL='_c3May1'
PLATFORM="ncrc3.intel16"
TARGET="prod-openmp"
REFERENCE_TAG='xanadu_esm4_20181119_mom6_ESM4_v1.0.2'
FRE_VERSION='bronx-15'

#########################################
#Users do not need to edit anything below
#########################################
#rootdir=`dirname $0`
XML_DIR=. #${rootdir}/../
#cd ${XML_DIR}
pwd
MYBIN=/ncrc/home2/Niki.Zadeh/nnz_tools/frerts_dev

FRERTS_BATCH_ARGS="-p ${PLATFORM} -t ${TARGET} --release ${RELEASE} --fre_stem ${FRESTEM} --fre_version ${FRE_VERSION}  --mom_git_tag ${MOM6_GIT_TAG} --mom_date_tag ${MOM6_DATE} --debuglevel ${DEBUGLEVEL} --project ${GROUP} --interactive" 

#FRERTS_ARGS="--compile,-l,esm4.1_libs_compile,--res_num,6,--fre_ops,-u;--no-transfer,--do_frecheck,--reference_tag,${REFERENCE_TAG}" 
#If you do not want to recompile
#FRERTS_ARGS="--res_num,6,--fre_ops,-u;--no-transfer,--do_frecheck,--reference_tag,${REFERENCE_TAG}" 
#If you want only a "basic" regression to run
FRERTS_ARGS="--compile,-l,esm4.1_libs_compile,--no_rts,--fre_ops,-r;debug;-u;--no-transfer,--do_frecheck,--reference_tag,${REFERENCE_TAG}" 

${MYBIN}/frerts_batch.csh -x ${XML_DIR}/${XML_FILE} ${FRERTS_BATCH_ARGS} --frerts_ops "${FRERTS_ARGS}" ${EXPERIMENT_LIST}

#To just check the status
#${MYBIN}/frerts_status.csh -x $HOME/frerts/${FRESTEM}/${DEBUGLEVEL}/${XML_FILE}.latest -p ${PLATFORM} -t ${TARGET}  ${EXPERIMENT_LIST} -n -r  --frecheck_ops '--ignore-files;icebergs.res.nc'

