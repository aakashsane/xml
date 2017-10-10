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

set source_dir = /home/bw/sources/FMS/atmos_refine

# atmos_month -> atmos_month_refined
# mask pressure levels below the surface (pressure)

foreach INFILE ( `ls *.atmos_month_cmip.*` )
   set OUTFILE = $refineDiagDir/$INFILE:t:s/.atmos_month_cmip./.atmos_month_refined./
   $source_dir/refine_fields.pl plevel_mask $INFILE $OUTFILE
end

# atmos_daily -> atmos_month_refined
# compute monthly average of daily min/max near-surface temperature

foreach INFILE ( `ls *.atmos_daily_cmip.*` )
  set TMPFILE = $INFILE:t:s/.atmos_daily_cmip./.atmos_month_tmp./
  set OUTFILE = $refineDiagDir/$INFILE:t:s/.atmos_daily_cmip./.atmos_month_refined./
  $source_dir/refine_fields.pl tasminmax $INFILE $TMPFILE
  ncks -h -A $TMPFILE $OUTFILE
  rm -f $TMPFILE
end

# atmos_daily -> atmos_daily_refined
# mask pressure levels below the surface (pressure)

foreach INFILE ( `ls *.atmos_daily_cmip.*` )
   set OUTFILE = $refineDiagDir/$INFILE:t:s/.atmos_daily_cmip./.atmos_daily_refined./
   $source_dir/refine_fields.pl plevel_mask $INFILE $OUTFILE
end

# atmos_tracer_cmip -> atmos_tracer_refined
# combining two variables into single variable

foreach INFILE ( `ls *.atmos_tracer_cmip.*` )
   set OUTFILE = $refineDiagDir/$INFILE:t:s/.atmos_tracer_cmip./.atmos_tracer_refined./
   $source_dir/refine_fields.pl tracer_refine $INFILE $OUTFILE
end

