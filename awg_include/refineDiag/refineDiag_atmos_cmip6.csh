###################################################################
#
#        Refine Atmospheric Diagnostics for CMIP6
#
###################################################################
#  required files -> output file
#  -----------------------------
#  *.atmos_month_cmip.tile?.nc  -> *.atmos_month_refined.tile?.nc
#  *.atmos_daily_cmip.tile?.nc  -> *.atmos_month_refined.tile?.nc
#  *.atmos_daily_cmip.tile?.nc  -> *.atmos_daily_refined.tile?.nc
#  *.atmos_tracer_cmip.tile?.nc -> *.atmos_tracer_refined.tile?.nc
#
#  require variables (set outside this script)
#  -----------------
#  set refineDiagDir = ???   # output directory
#                            # input directory = `cwd`
###################################################################

# git clone the refine diag scripts

set GIT_REPOSITORY = file:///home/bw/git-repository/FMS
set FRE_CODE_TAG = testing_20170329
set PACKAGE_NAME = atmos_refine
set CODE_DIRECTORY = atmos_refine_scripts
git clone -b $FRE_CODE_TAG $GIT_REPOSITORY/$PACKAGE_NAME.git $CODE_DIRECTORY

set source_dir = $CODE_DIRECTORY

# mask pressure levels below the surface (pressure)
# atmos_month -> atmos_month_refined
# atmos_daily -> atmos_daily_refined
# atmos_4xdaily -> atmos_4xdaily_refined

foreach FILENAME ( atmos_month_cmip atmos_daily_cmip atmos_4xdaily_cmip )
  set OFILENAME = `echo $FILENAME | sed -e 's/_cmip$//'`"_refined"
  foreach INFILE ( `ls *.$FILENAME.*` )
    set OUTFILE = "$refineDiagDir/"`echo $INFILE:t | sed -e "s/\.$FILENAME\./.$OFILENAME./"`
    $source_dir/refine_fields.pl plevel_mask $INFILE $OUTFILE
  end
end
    
# compute monthly average of daily min/max near-surface temperature
# atmos_daily -> atmos_month_refined

foreach INFILE ( `ls *.atmos_daily_cmip.*` )
  set TMPFILE = $INFILE:t:s/.atmos_daily_cmip./.atmos_month_tmp./
  set OUTFILE = $refineDiagDir/$INFILE:t:s/.atmos_daily_cmip./.atmos_month_refined./
  $source_dir/refine_fields.pl tasminmax $INFILE $TMPFILE
  ncks -h -A $TMPFILE $OUTFILE
  rm -f $TMPFILE
end

# combining two aerosol/tracer variables into a single variable
# aerosol_month_cmip -> aerosol_month_refined

set tracer_files = `find  -name \*.aerosol_month_cmip.\* | sed -e "s/^\.\///"`
if ($#tracer_files == 6) then
  foreach INFILE ( $tracer_files )
    set OUTFILE = $refineDiagDir/$INFILE:t:s/.aerosol_month_cmip./.aerosol_month_refined./
    $source_dir/refine_fields.pl tracer_refine $INFILE $OUTFILE
  end
endif

