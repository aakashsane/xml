!#/bin/csh
set -v
# Automatic Build and Run on Gaea using fre
XML_FILE=OMIP4_CORE2_warsaw_201803.xml  #The xml to test
RELEASE='xanadu'          #The FMS release to test
MOM6_DATE='ESM4_v1.0.3'                 #The MOM6 tag date to test
MOM6_GIT_TAG="ESM4\\\/v1.0.3"          #The MOM6 tag to test
FRESTEM="${RELEASE}_mom6_${MOM6_DATE}"  #The FRESTEM to use
GROUP="gfdl_f"
#List of the experiments in the xml to run regression for
EXPERIMENT_LIST="OM4p25_IAF_BLING_csf_rerun OM4p5_IAF_BLING_CFC_abio_csf_mle200 OM4p5_IAF_BLING_CFC_abio_csf_mle200_initCond1998"
#"OM4p25_IAF_BLING_csf_rerun OM4p5_IAF_BLING_CFC_abio_csf_mle200 OM4p5_IAF_BLING_CFC_abio_csf_mle200_initCond OM4p25_IAF_BLING_CFC_csf_hifreqdiag_2003-2008"

DEBUGLEVEL='_c3Slurm'
PLATFORM="ncrc3.intel16"
TARGET="prod"
REFERENCE_TAG='warsaw_201803_mom6_2018.04.11'
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

FRERTS_ARGS="--compile,--res_num,6,--fre_ops,-u;--no-transfer;--no-combine-history,--do_frecheck,--reference_tag,${REFERENCE_TAG}" 
#If you do not want to recompile
#FRERTS_ARGS="--res_num,6,--fre_ops,--cluster=t4;-u;--no-transfer;--no-combine-history,--do_frecheck,--reference_tag,${REFERENCE_TAG}" 
#If you want only a "basic" regression to run
#FRERTS_ARGS="--compile,--no_rts,--fre_ops,-r;basic;-u;--no-transfer;--no-combine-history,--do_frecheck,--reference_tag,${REFERENCE_TAG}" 

${MYBIN}/frerts_batch.csh -x ${XML_DIR}/${XML_FILE} ${FRERTS_BATCH_ARGS} --frerts_ops "${FRERTS_ARGS}" ${EXPERIMENT_LIST}

#To just check the status
#${MYBIN}/frerts_status.csh -x $HOME/frerts/${FRESTEM}/${DEBUGLEVEL}/${XML_FILE}.latest -p ${PLATFORM} -t ${TARGET}  ${EXPERIMENT_LIST} -n -r  --frecheck_ops '--ignore-files;icebergs.res.nc'

