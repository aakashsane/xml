set -v
# Automatic Build and Run on Gaea using fre
XML_FILE=CM4_am4p0c96L33_OM4p25.xml            #The xml to test
RELEASE='warsaw_201707'                        #The FMS release to test
MOM6_DATE='2017.07.05'                         #The MOM6 tag date to test
MOM6_GIT_TAG="dev\\\/master\\\/$MOM6_DATE"     #The MOM6 tag to test
FRESTEM="warsaw_201707_mom6_$MOM6_DATE"       #The FRESTEM to use

#List of the experiments in the xml to run regression for
EXPERIMENT_LIST="c96L33_am4p0_2010climo c96L33_am4p0_2010climo_cmip6 c96L33_am4p0_1850climo_PotenVeg_KoK_False CM4_c96L33_am4p0_2010_30d15_tlt CM4_c96L33_am4p0_2010_30d15_tlt_initCond CM4_c96L33_am4p0_1850_30d15_tlt CM4_c96L33_am4p0_1850_30d15_tlt_4XCO2"

DEBUGLEVEL='_0'
PLATFORM="ncrc4.intel16"
TARGET="prod-openmp"
REFERENCE_TAG='dev_master_20170714_mom6_2017.07.05_answers'
FRE_VERSION='bronx-12'

#########################################
#Users do not need to edit anything below
#########################################
rootdir=`dirname $0`
XML_DIR=${rootdir}/../
cd ${XML_DIR}

MYBIN=/ncrc/home2/Niki.Zadeh/nnz_tools/frerts_test

FRERTS_BATCH_ARGS="-p ${PLATFORM} -t ${TARGET} --release ${RELEASE} --fre_stem ${FRESTEM} --fre_version ${FRE_VERSION}  --mom_git_tag ${MOM6_GIT_TAG} --mom_date_tag ${MOM6_DATE} --debuglevel ${DEBUGLEVEL} --project gfdl_f  --interactive" 

FRERTS_ARGS="--compile,-l,cm4_libs_compile,--res_num,6,--fre_ops,-u;--no-transfer;--no-combine-history,--do_frecheck,--reference_tag,${REFERENCE_TAG}" 
#If you do not want to recompile
#FRERTS_ARGS="--res_num,6,--fre_ops,-q;urgent;-u;--no-transfer;--no-combine-history,--do_frecheck,--reference_tag,${REFERENCE_TAG}" 
#If you want only a "basic" regression to run
#FRERTS_ARGS="--compile,-l,cm4_libs_compile,--no_rts,--fre_ops,-u;--no-transfer;--no-combine-history,--do_frecheck,--reference_tag,${REFERENCE_TAG}" 

${MYBIN}/frerts_batch.csh -x ${XML_DIR}/${XML_FILE} ${FRERTS_BATCH_ARGS} --frerts_ops "${FRERTS_ARGS}" ${EXPERIMENT_LIST}

#To just check the status
#${MYBIN}/frerts_status.csh -x $HOME/frerts/${FRESTEM}/${DEBUGLEVEL}/${XML_FILE}.latest -p ${PLATFORM} -t ${TARGET}  ${EXPERIMENT_LIST}


