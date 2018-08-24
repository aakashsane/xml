#!/bin/csh -f
#------------------------------------
#PBS -N Plev19ToPlev8
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


set out_data_dir = $in_data_dir:h:h:h:h:h
set component    = {$in_data_dir:h:h:h:h:t}_Plev8
set out_data_dir = $out_data_dir/$component/ts/daily/5yr/

# split input arguments string  
set vars = ($argu:as/,/ /)
echo $vars

foreach var ($vars) 
  echo $var
  set ifile = `ls  ${in_data_dir}/*.{$databegyr}????-${dataendyr}????.{$var}.nc`
  set ifile = $ifile:t
  echo $ifile

  set file_prefix = $ifile:r:r:r
  set file_prefix2 = $ifile:r:r:e

  set ofile = ${file_prefix}_Plev8.{$file_prefix2}.{$var}.nc
  echo $ofile
  cd $TMPDIR/
  gcp ${in_data_dir}{$ifile}  ./

  ncks -F -d plev19,1,1 -v $var,average_DT,average_T1,average_T2,lat_bnds,lon_bnds,time_bnds  $ifile   test1.nc
  ncks -F -d plev19,3,3 -v $var,average_DT,average_T1,average_T2,lat_bnds,lon_bnds,time_bnds  $ifile   test3.nc
  ncks -F -d plev19,4,4 -v $var,average_DT,average_T1,average_T2,lat_bnds,lon_bnds,time_bnds  $ifile   test4.nc
  ncks -F -d plev19,6,6 -v $var,average_DT,average_T1,average_T2,lat_bnds,lon_bnds,time_bnds  $ifile   test6.nc
  ncks -F -d plev19,9,9 -v $var,average_DT,average_T1,average_T2,lat_bnds,lon_bnds,time_bnds  $ifile   test9.nc

  ncks -F -d plev19,12,12 -v $var,average_DT,average_T1,average_T2,lat_bnds,lon_bnds,time_bnds  $ifile   test12.nc
  ncks -F -d plev19,14,14 -v $var,average_DT,average_T1,average_T2,lat_bnds,lon_bnds,time_bnds  $ifile   test14.nc
  ncks -F -d plev19,17,17 -v $var,average_DT,average_T1,average_T2,lat_bnds,lon_bnds,time_bnds  $ifile   test17.nc
 
  ncpdq -a plev19,time test1.nc test1_perb.nc
  ncpdq -a plev19,time test3.nc test3_perb.nc
  ncpdq -a plev19,time test4.nc test4_perb.nc
  ncpdq -a plev19,time test6.nc test6_perb.nc
  ncpdq -a plev19,time test9.nc test9_perb.nc

  ncpdq -a plev19,time test12.nc test12_perb.nc
  ncpdq -a plev19,time test14.nc test14_perb.nc
  ncpdq -a plev19,time test17.nc test17_perb.nc

  ncrcat test1_perb.nc test3_perb.nc  test4_perb.nc test6_perb.nc test9_perb.nc test12_perb.nc  test14_perb.nc test17_perb.nc   test_perb_combine.nc
  ncpdq -a time,plev19  test_perb_combine.nc $ofile
  ncrename -h -d plev19,plev8  -v plev19,plev8  $ofile

  gcp $ofile  {$out_data_dir}{$ofile}
  rm -f *
end

exit

