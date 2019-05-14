!#/bin/csh
set -v
# Automatic Build and Run on Gaea using fre
XML_FILE=CM4_piControl_A.xml               #The xml to test
RELEASE='xanadu'                 #The FMS release to test
MOM6_DATE='om4_v1.0.5'                     #The MOM6 tag date to test
MOM6_GIT_TAG="om4\\\/v1.0.5"               #The MOM6 tag to test
FRESTEM="${RELEASE}_${MOM6_DATE}_c4slurm"       #The FRESTEM to use
GROUP="gfdl_f"
#List of the experiments in the xml to run regression for
EXPERIMENT_LIST="CM4_piControl"

DEBUGLEVEL='_c4Slurm'
PLATFORM="ncrc4.intel16"
TARGET="prod-openmp"
REFERENCE_TAG='warsaw_201710_mom6_2017.10.19_answers'
FRE_VERSION='bronx-15'

#########################################
#Users do not need to edit anything below
#########################################
#rootdir=`dirname $0`
XML_DIR=. #${rootdir}/../
cd ${XML_DIR}
pwd
MYBIN=/ncrc/home2/Niki.Zadeh/nnz_tools/frerts_dev

FRERTS_BATCH_ARGS="-p ${PLATFORM} -t ${TARGET} --release ${RELEASE} --fre_stem ${FRESTEM} --fre_version ${FRE_VERSION}  --mom_git_tag ${MOM6_GIT_TAG} --mom_date_tag ${MOM6_DATE} --debuglevel ${DEBUGLEVEL} --project ${GROUP} --interactive" 

#FRERTS_ARGS="--compile,-l,cm4_libs_compile,--res_num,6,--fre_ops,-u;--no-transfer;--no-combine-history,--do_frecheck,--reference_tag,${REFERENCE_TAG}" 
#If you do not want to recompile
#FRERTS_ARGS="--res_num,6,--fre_ops,-u;--no-transfer;--no-combine-history,--do_frecheck,--reference_tag,${REFERENCE_TAG}" 
#If you want only a "basic" regression to run
FRERTS_ARGS="--compile,-l,cm4_libs_compile,--no_rts,--res_num,4,--fre_ops,-r;debug;-u;--no-transfer;--no-combine-history,--do_frecheck,--reference_tag,${REFERENCE_TAG}" 

${MYBIN}/frerts_batch.csh -x ${XML_DIR}/${XML_FILE} ${FRERTS_BATCH_ARGS} --frerts_ops "${FRERTS_ARGS}" ${EXPERIMENT_LIST}

#To just check the status
#${MYBIN}/frerts_status.csh -x $HOME/frerts/${FRESTEM}/${DEBUGLEVEL}/${XML_FILE}.latest -p ${PLATFORM} -t ${TARGET}  ${EXPERIMENT_LIST} -n -r  --frecheck_ops '--ignore-files;icebergs.res.nc'

