!#/bin/csh
set -v
# Automatic Build and Run on Gaea using fre
XML_FILE=CM4_2010Control_C_c192_OM4p125.xml  #The xml to test
RELEASE='2019.01.03'
MOM6_DATE='devgfdl_20200921'            #The MOM6 tag date to test
MOM6_GIT_TAG='dev\/gfdl'      #The MOM6 tag to test
FRESTEM="FMS${RELEASE}_${MOM6_DATE}"  #The FRESTEM to use
GROUP="gfdl_f"
#List of the experiments in the xml to run regression for
EXPERIMENT_LIST="CM4_2010Control_C_noBLING_c192_OM4p125_gridEdits_spunLand2_R_ice2"
#"CM4_2010Control_C_noBLING_c192_OM4p125_interspersedIce"
#"c192L33_am4p0_2010climo CM4_2010Control_C_noBLING_c192_OM4p125"

DEBUGLEVEL='_2'
PLATFORM="ncrc4.intel18"
TARGET="prod-openmp"
REFERENCE_TAG='xanadu_esm4_20190304_mom6_devgfdl_20200330' 
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

#FRERTS_ARGS="--compile,-l,esm4.1_libs_compile,--res_num,6,--fre_ops,-u;--no-transfer,--do_frecheck,--reference_tag,${REFERENCE_TAG}" 
#If you do not want to recompile
#FRERTS_ARGS="--res_num,6,--fre_ops,-u;--no-transfer,--do_frecheck,--reference_tag,${REFERENCE_TAG}" 
#If you want only a "basic" regression to run
FRERTS_ARGS="--compile,-l,cm4_libs_compile,--no_rts,--res_num,3,--fre_ops,-r;basic;-u;--no-transfer,--do_frecheck,--reference_tag,${REFERENCE_TAG}" 

${MYBIN}/frerts_batch.csh -x ${XML_DIR}/${XML_FILE} ${FRERTS_BATCH_ARGS} --frerts_ops "${FRERTS_ARGS}" ${EXPERIMENT_LIST}

#To just check the status
#${MYBIN}/frerts_status.csh -x $HOME/frerts/${FRESTEM}/${DEBUGLEVEL}/${XML_FILE}.latest -p ${PLATFORM} -t ${TARGET}  ${EXPERIMENT_LIST} --nocapture -r  --frecheck_ops '--ignore-files;icebergs.res.nc'
