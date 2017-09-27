#!/bin/tcsh -f
#---------------------------
#PBS -N fremetar_wrapper
#PBS -l size=1
#PBS -l walltime=02:00:00
#PBS -r y
#PBS -j oe
#PBS -o
#PBS -q batch
#---------------------------

# Fields that are set by frepp
set argu 
set descriptor 
set in_data_dir
#set out_dir for testing purposes
#set out_dir = /archive/Colleen.McHugh/warsaw_201707_mom6_2017.07.05/CM4B_1850_Control_am4p0c96L33_OM4p25_30d15_tlt_bling8_F_201To500_cmip6Diag/cmor1 
set WORKDIR 
set mode 
set yr1 
set yr2 
set databegyr 
set dataendyr 
set datachunk 
set staticfile 
set experID
set realizID
set runID
set host = cobweb
set dbname = curator
set data_version = 20170913
set tripleID
set fremetar_dir = /work/$USER/warsaw_201707_mom6_2017.07.05/CM4B_1850_Control_am4p0c96L33_OM4p25_30d15_tlt_bling8_F_201To500_cmip6Diag/gfdl.ncrc4-intel16-prod-openmp/
# TODO: What about that static files for the fremetarization??
# Hmm: maybe this static flag can be set and tell the workflow when
# to process the contents of the static file.
set argv = ( `getopt s $*` )

while ("$argv[1]" != "--")
    switch ($argv[1])
        case -s:
            set static; breaksw
    endsw
    shift argv
end
shift argv

# Load the environment for the split utility
if ( `gfdl_platform` == "hpcs-csc" ) then
    source $MODULESHOME/init/tcsh
    module load fre/bronx-12
else
    echo "ERROR: Please run on GFDL PPAN."
    exit 1
endif

# Let's split out the static variables
if ( $?static ) then
    echo "Doing static cmorization now..."
    foreach static_var ( `list_ncvars.csh -s012 ${staticfile}`)
        set component = `basename ${staticfile} | cut -d. -f1`
        split_ncvars.pl -v ${static_var} --cmor -o ${in_data_dir} ${static_file}
        mv ${in_data_dir}${static_var}.nc ${in_data_dir}/${component}.static.${static_var}.nc
    end
endif

# Get a list of the files that will be 'cmorized'
echo "Doing temporal cmorization now..."
foreach file ( `dir -1 ${in_data_dir}/*.${yr1}*-${yr2}*`)
    set filename = `basename ${file}`
    set varname = `echo ${filename} | cut -d. -f3`
    set year1 = `echo ${filename} | cut -d. -f2 | cut -c 1-4`
    set year2 = `echo ${filename} | cut -d. -f2 | cut -d- -f2 | cut -c 1-4`
#check to see if files were previously 'cmorized', skip to fremetar if they were
   if ( `grep -c 'split_ncvars' ${in_data_dir}/${filename}`>1 && ${yr1} == ${year1} && ${yr2} == ${year2}) then
        echo "Already cmorized. Skipping file..."
   else     
        split_ncvars.pl -v ${varname} --cmip -o ${in_data_dir} ${file}
        mv ${in_data_dir}/${varname}.nc ${in_data_dir}/${filename}
#add global att split_ncvars = True flag to prevent running split_ncvars again on same file 
        ncatted -O -a split_ncvars,global,a,c,"True" ${in_data_dir}/${filename} 
   endif
end
        
                     
#fremetar
echo "Running fremetar..."
/home/san/ws_ecl/FREMetar_CMIP6/fremetar -d ${in_data_dir} -e ${experID} -z ${realizID} -r ${runID} -o ${fremetar_dir} -t ${yr1} -s ${host} -n ${dbname} -b ${data_version}

