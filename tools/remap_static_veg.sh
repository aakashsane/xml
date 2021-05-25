#!/bin/bash

set -e # stop on any uncaught error
set -u # stop on undefined variables

source $MODULESHOME/init/bash
module load fre/test
  today="20210513"
srcgrid="/lustre/f2/pdata/gfdl/gfdl_W/Ming.Zhao/hiresmip/gridSpec/c192_OM4_025_grid_No_mg_drag_v20160808.tar"
    src="/lustre/f2/pdata/gfdl/gfdl_W/Ming.Zhao/hiresmip/ic/c192L33_new/CM4_c192L33_OM4_025_initCond_1950cntl_new.tar"
#
dstgrid="/lustre/f2/dev/Raphael.Dussin/input/mosaic_c192_bedmachine_v20210310.tar"
dstcold="/lustre/f2/dev/Niki.Zadeh/archive/input/xanadu/CM4_piControl_c192_OM4p125_res01010101.combined.tar"
    dst="/lustre/f2/dev/Niki.Zadeh/archive/input/xanadu/19810101.static_veg_LM3p2sosn_HWSD5min_C192_OM4_025.v20160304.remapLND.v${today}.tar"
staticveg="/lustre/f2/pdata/gfdl/gfdl_W/Ming.Zhao/hiresmip/land_data/c192/19810101.static_veg_LM3p2sosn_HWSD5min_C192_OM4_025.v20160304.tar"

# create temporary directory and structure in it
tmp=`mktemp -d  -p $FRE_SYSTEM_TMP`
echo Created $tmp
mkdir $tmp/{src_restart,dst_restart,dst_cold_restart,src_grid,dst_grid}
# unpack grid specs
echo unpacking $srcgrid ...
(cd $tmp/src_grid ; tar xf -) < $srcgrid
echo unpacking $dstgrid ...
(cd $tmp/dst_grid ; tar xf -) < $dstgrid

# unpack land cold start
echo unpacking $dstcold ...
(cd $tmp/dst_cold_restart ; tar xf -) < $dstcold

# unpack src restart
echo unpacking $src ...
(cd $tmp/src_restart ; tar xf -) < $src

echo unpacking $staticveg ...
(cd $tmp/src_restart ; tar xf -) < $staticveg

# copy this script for future reference
cp $0 $tmp/dst_restart
# generate remap file
cd $tmp
echo remapping land and creating remap files ...
remap_land --file_type land \
    --src_mosaic src_grid/C192_mosaic.nc --dst_mosaic dst_grid/C192_mosaic.nc \
    --src_restart src_restart/land.res --dst_restart dst_restart/land.res \
    --dst_cold_restart dst_cold_restart/land.res \
    --remap_file remap_file \
    --print_memory
# remap static veg files from src to dst
remap_land --file_type vegn \
    --src_mosaic src_grid/C192_mosaic.nc --dst_mosaic dst_grid/C192_mosaic.nc \
    --src_restart src_restart/19810101.static_veg_out --dst_restart dst_restart/19810101.static_veg_out \
    --dst_cold_restart dst_cold_restart/vegn1.res \
    --land_src_restart src_restart/land.res --land_cold_restart dst_cold_restart/land.res \
    --remap_file remap_file --print_memory

cd dst_restart
# remove unnecessary files
rm land.res.*
echo `date` >>README
cat <<EOF >>README
Remapped $staticveg 
to the grid $dstgrid

See $0 for details
EOF

tar cvf $dst *

# Excerpt from Zhi's documentation:
# 1. Run model with C384 grid using cold restart for land. This generates
#    dst_cold_restart files.
# 2. Create remapping file and remap land.res file.
#    aprun -n 64 remap_land_parallel --file_type land --src_mosaic C192_mosaic.nc
#          --dst_mosaic c384_mosaic.nc --src_restart src_restart/land.res
#          --dst_restart dst_restart/land.res --dst_cold_restart dst_cold_restart/land.res
#          --remap_file remap_file_C192_to_C384 --print_memory
# 3. Remap soil, snow, cana, glac, lake, vegn1, vegn2
#      foreach type ( soil snow cana glac lake vegn1 vegn2 )
#         if( $type == 'vegn1' || $type == 'vegn2' ) then
#             set filetype = 'vegn'
#         else
#             set filetype = $type
#         endif
#         remap_land --file_type $filetype --src_mosaic C192_mosaic.nc
#             --dst_mosaic c384_mosaic.nc --src_restart src_restart/$type.res
#             --dst_restart dst_restart/$type.res --dst_cold_restart dst_cold_restart/$type.res
#             --land_src_restart src_restart/land.res --land_cold_restart dst_cold_restart/land.res
#             --remap_file remap_file_C192_to_C384 --print_memory
#      end
# 4. Remap static_vegn if needed
#    remap_land --file_type vegn --src_mosaic C192_mosaic.nc
#       --dst_mosaic c384_mosaic.nc --src_restart src_restart/static_vegn
#       --dst_restart dst_restart/static_vegn --dst_cold_restart dst_cold_restart/vegn1.res
#       --land_src_restart src_restart/land.res --land_cold_restart dst_cold_restart/land.res
#       --remap_file remap_file_C192_to_C384 --print_memory
