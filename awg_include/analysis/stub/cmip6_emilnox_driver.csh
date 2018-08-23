#!/bin/csh 
#----------------------------------
#PBS -l size=1
#PBS -l walltime=01:00:00
#PBS -r y
#PBS -j oe


#####################################################################
# Script to postprocess emilnox (AERmon) variable
set echo
# set fremodule
if ($?fremodule) then
   source $MODULESHOME/init/csh
   module use -a /home/fms/local/modulefiles
   module load $fremodule
endif

# make sure fre is loaded
if (`echo '$M="fre";@M=grep/^$M\/.*/,split/:/,$ENV{"LOADEDMODULES"};if($M[0]=~/^$M\/(.*)$/){print $1}'|perl` == "") then
   echo "ERROR: FRE not loaded"
   exit 1
endif

module load ncarg/6.2.1
module load gcp

set argv = (`getopt i:o:y: $*`)
 
while ("$argv[1]" != "--")
    switch ($argv[1])
        case -i:
            set in_dir = $argv[2]; shift argv; breaksw 
        case -o:
            set out_dir = $argv[2]; shift argv; breaksw
        case -y:
            set years = $argv[2]; shift argv; breaksw
    endsw
    shift argv
end
shift argv

# argument error checking

if (! $?in_dir) then
   echo "ERROR: no argument given for input directory."
   set help
endif

if (! $?out_dir) then
   echo "ERROR: no argument given for output directory."
   set help
endif

if ($?help) then
   echo
   echo "USAGE:  $0:t -i idir -o odir -p pdir -d desc -y yrs files...."
   echo
   exit 1
endif

if ($?years) then
   set yrs = `echo $years | sed -e "s/,/ /"`
   if ($#yrs != 2) then
      echo "ERROR: invalid entry for years."
      exit 1
   endif
endif


#####################################################################
set echo 

# make sure temp directory is defined
if ($?FTMPDIR) then
   set workdir = $FTMPDIR/pp_emilnox/$in_dir
   if (! -e $workdir) then
      mkdir -p $workdir
   endif
   cd $workdir
else
   echo 'ERROR: $FTMPDIR not defined - you may be on the incorrect platform'
   exit 1
endif

set varlist = (emilnox_area)
set cmorvarlist = (emilnox)

foreach var ($varlist)
  if (-e $in_dir/aerosol_cmip.$yrs[1]01-$yrs[2]12.$var.nc) then
      set infile = `/bin/ls $in_dir/*.$yrs[1]01-$yrs[2]12.$var.nc`
      dmget $infile
      gcp $infile $workdir
  endif 
end

set variable = 
set go_ncl = `which ncl`

set qq = '"'

# Run script to process emilnox
cat << EOF > gofile.ncl

begin

exptime       = $qq$yrs[1]01-$yrs[2]12$qq
work_dir      = $qq$workdir$qq

   varname = ${qq}emilnox_area$qq
   cmorname = ${qq}emilnox$qq
   
   filename_in = work_dir+$qq/aerosol_cmip.$qq+exptime+$qq.$qq+varname+$qq.nc$qq
   fin = addfile(filename_in,${qq}r${qq})
   lat = fin->lat
   nlat = dimsizes(lat)
   lat_bnds = fin->lat_bnds
   lon = fin->lon
   nlon = dimsizes(lon)
   lon_bnds = fin->lon_bnds
   lev = fin->lev
   nlev = dimsizes(lev)
   lev_bnds = fin->lev_bnds
   
   area = new(nlat,float)
   rearth = 6.3712e6 ; m
   pi = 4.*atan(1.)
   d2r = pi/180.
   area = tofloat(sin(lat_bnds(:,1)*d2r) - sin(lat_bnds(:,0)*d2r))*2*pi*rearth^2/nlon

   xvar = fin->\$varname\$
   xvar = (/ xvar * conform(xvar,area,2) /)
   xvar@units = ${qq}mol s-1$qq

   filename_out = work_dir+$qq/aerosol_cmip.$qq+exptime+$qq.$qq+cmorname+$qq.nc$qq
   system(${qq}rm -f $qq+filename_out)
   fout = addfile(filename_out,${qq}c$qq)

; Define dimensions
   dimNames = (/ ${qq}lon$qq, ${qq}lat$qq, ${qq}lev$qq,${qq}bnds$qq,${qq}time$qq /)
   dimSizes = (/ nlon,  nlat,  nlev, 2, -1 /)
   dimUnlim = (/ False, False, False, False, True/)
   filedimdef( fout, dimNames, dimSizes, dimUnlim )

   fout->lat = lat
   fout->lat_bnds = lat_bnds
   fout->lon = lon
   fout->lon_bnds = lon_bnds
   fout->lev = lev
   fout->lev_bnds = lev_bnds
   fout->time = fin->time  
   fout->time_bnds = fin->time_bnds
   fout->average_T1 = fin->average_T1
   fout->average_T2 = fin->average_T2
   fout->average_DT = fin->average_DT
   fout->\$cmorname\$ = xvar

end
EOF

date
$go_ncl gofile.ncl
date

# output directory
set out_data_dir = $in_dir
if (! -e $out_data_dir ) then
   mkdir -p $out_data_dir
endif

# move files to the output directory
foreach cmorvar ($cmorvarlist) 
   if (-e $workdir/aerosol_cmip.$yrs[1]01-$yrs[2]12.$cmorvar.nc) then
      gcp $workdir/aerosol_cmip.$yrs[1]01-$yrs[2]12.$cmorvar.nc $out_data_dir
   else
      echo "ERROR: file not found in $workdir"
#     exit 1
   endif 
end   # var loop

