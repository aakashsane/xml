#!/bin/csh -f
#------------------------------------
#PBS -N csatindxToalt40
#PBS -l size=1
#PBS -l walltime=6:00:00
#PBS -r y
#PBS -j oe
#PBS -o
#PBS -q batch
#------------------------------------
# Source data: pp/COMP/ts/FREQ/XXyr

# variables set by frepp
 set argu
 set in_data_dir
 set databegyr
 set dataendyr
 set datachunk
 set fremodule
 set freanalysismodule

# output data directory must be writeable by user
 set out_data_dir = $in_data_dir

# make sure valid platform and required modules are loaded
if (`gfdl_platform` == "hpcs-csc") then
   source $MODULESHOME/init/csh
   module purge
   module use -a /home/fms/local/modulefiles
   module load $fremodule
   module load $freanalysismodule
   module load nco/4.3.1
   module load gcp
else
   echo "ERROR: invalid platform"
   exit 1
endif


set out_data_dir = $in_data_dir

if ( -e ${out_data_dir} ) then
  echo "${out_data_dir} already exists"
else
  mkdir -p  ${out_data_dir}
endif

# split input arguments string  
set vars = ("clcalipso")
echo $vars


cd $TMPDIR/
## create alt40_bnds nc file  ##
cat << EOF > alt40_bnds_info.cdl
netcdf alt40_bnds_info {
dimensions:
   alt40= 40;
   bnds = 2;
variables:
   double alt40_bnds(alt40, bnds);
         alt40_bnds:long_name="altitude";
         alt40_bnds:units="m";         
 data:
   alt40_bnds=  "0.0", 
                "480.0", 
                "480.0", 
                "960.0", 
                "960.0", 
                "1440.0", 
                "1440.0", 
                "1920.0", 
                "1920.0", 
                "2400.0", 
                "2400.0", 
                "2880.0", 
                "2880.0", 
                "3360.0", 
                "3360.0", 
                "3840.0", 
                "3840.0", 
                "4320.0", 
                "4320.0", 
                "4800.0", 
                "4800.0", 
                "5280.0", 
                "5280.0", 
                "5760.0", 
                "5760.0", 
                "6240.0", 
                "6240.0", 
                "6720.0", 
                "6720.0", 
                "7200.0", 
                "7200.0", 
                "7680.0", 
                "7680.0", 
                "8160.0", 
                "8160.0", 
                "8640.0", 
                "8640.0", 
                "9120.0", 
                "9120.0", 
                "9600.0", 
                "9600.0", 
                "10080.0", 
                "10080.0", 
                "10560.0", 
                "10560.0", 
                "11040.0", 
                "11040.0", 
                "11520.0", 
                "11520.0", 
                "12000.0", 
                "12000.0", 
                "12480.0", 
                "12480.0", 
                "12960.0", 
                "12960.0", 
                "13440.0", 
                "13440.0", 
                "13920.0", 
                "13920.0", 
                "14400.0", 
                "14400.0", 
                "14880.0", 
                "14880.0", 
                "15360.0", 
                "15360.0", 
                "15840.0", 
                "15840.0", 
                "16320.0", 
                "16320.0", 
                "16800.0", 
                "16800.0", 
                "17280.0", 
                "17280.0", 
                "17760.0", 
                "17760.0", 
                "18240.0", 
                "18240.0", 
                "18720.0", 
                "18720.0", 
                "19200.0"
;
}
EOF

ncgen -b -o alt40_bnds_info.nc alt40_bnds_info.cdl


foreach var ($vars) 
  echo $var
  set ifile = `ls  ${in_data_dir}/*.{$databegyr}??-${dataendyr}??.{$var}.nc`
  set ifile = $ifile:t
  echo $ifile

  set file_prefix = $ifile:r:r:r
  set file_prefix2 = $ifile:r:r:e

  set ofile = $ifile 
  echo $ofile
  gcp ${in_data_dir}{$ifile}  ./

  ncrename -h -d csatindx,alt40 -v csatindx,alt40 $ifile
  ncatted -a long_name,alt40,o,c,"altitude"       $ifile
  ncatted -a units,alt40,o,c,"m"                  $ifile

  ncatted -a standard_name,alt40,c,c,"altitude"   $ifile
  ncatted -a positive,alt40,c,c,"up"              $ifile
  ncatted -a bounds,alt40,c,c,"alt40_bnds"        $ifile
  ncks -a -A alt40_bnds_info.nc                   $ifile

  gcp $ifile  {$out_data_dir}{$ofile}
  rm -f *
end

exit

