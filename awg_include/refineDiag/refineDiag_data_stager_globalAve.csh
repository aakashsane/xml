#------------------------------------------------------------------------------
#  refineDiag_data_stager_globalAve.csh
#
#  DESCRIPTION:
#    This script serves two primary functions:
#
#    1.  It unpacks the history tar file to the /ptmp file system.  It allows
#        for more efficient post-processing when individual components are 
#        called by frepp.  (i.e. when the frepp "atmos_month" post-processing
#        script runs, frepp will copy only the unpacked "*atmos_month*" .nc 
#        files from /ptmp to the $work directory rather than the entire history
#        tar file.
#
#    2.  It performs a global annual average of all 3D variables (time, lat, lon)
#        and stores the values in a sqlite database that resides in a parallel
#        directory to the frepp scripts and stdout
#
#------------------------------------------------------------------------------

echo "  ---------- begin refineDiag_data_stager.csh ----------  "
date

cd $work/$hsmdate
pwd
 
#-- Create a directory to house the sqlite database (if it does not already exist)
set localRoot = `echo $scriptName | rev | cut -f 4-100 -d '/' | rev`
if (! -d ${localRoot}/db) then 
  mkdir -p ${localRoot}/db
endif

#-- Unload any previous versions of Python and load the system default
module unload python
module unload cdat
module load python

#-- CAT Python scriptis that performs the averages and create the sqlite files

cat > gmeantools.py <<EOF
import netCDF4 as nc
import numpy as np
import os
import pickle
import sqlite3

def getWebsiteVariablesDic():
    return pickle.load(open('/home/fms/local/opt/fre-analysis/test/eem/code/cm4_web_analysis/'+\
                            'etc/LM3_variable_dictionary.pkl', 'rb'))

def ncopen(file,action='exit'):
    if os.path.exists(file):
      return nc.Dataset(file)
    else:
      print('WARNING: Unable to open file '+file)
      if action == 'exit':
        exit(0)
      else:
        return None

def mask_latitude_bands(var,cellArea,geoLat,geoLon,region=None):
    if (region == 'tropics'):
      var = np.ma.masked_where(np.logical_or(geoLat < -30., geoLat > 30.),var)
      cellArea = np.ma.masked_where(np.logical_or(geoLat < -30., geoLat > 30.),cellArea)
    elif (region == 'nh'):
      var = np.ma.masked_where(np.less_equal(geoLat,30.),var)
      cellArea  = np.ma.masked_where(np.less_equal(geoLat,30.),cellArea)
    elif (region == 'sh'):
      var  = np.ma.masked_where(np.greater_equal(geoLat,-30.),var)
      cellArea  = np.ma.masked_where(np.greater_equal(geoLat,-30.),cellArea)
    elif (region == 'global'):
      var  = var
      cellArea = cellArea
    return var, cellArea

def area_mean(var,cellArea,geoLat,geoLon,cellFrac=None,soilFrac=None,region='global',varName=None,
              cellDepth=None, component=None):
    # Land-specific modifications
    if component == 'land':
        moduleDic = getWebsiteVariablesDic()
        # Read dictionary of keys
        if (varName in moduleDic.keys()):
          module = moduleDic[varName]
        elif (varName.lower() in moduleDic.keys()):
          module = moduleDic[varName.lower()]
        else:
          module = ''
        # Create a weighting factor
        if module == 'vegn':
          cellArea = cellArea*cellFrac*soilFrac
        else:
          cellArea = cellArea*cellFrac
        # Create a 3-D mask if needed
        if cellDepth is not None:
         if var.shape[0] == cellDepth.shape[0]:
           cellArea = np.tile(cellArea[None,:], (cellDepth.shape[0],1,1))
           geoLat = np.tile(geoLat[None,:], (cellDepth.shape[0],1,1))
           geoLon = np.tile(geoLon[None,:], (cellDepth.shape[0],1,1))
         else:
           print('Warning: inconsisent dimensions between varName and the cell depth axis.', \
                 var.shape[0], cellDepth.shape[0])
           null_result = np.ma.masked_where(True,0.)
           return null_result, null_result
        # Apply data mask to weighting mask
        cellArea.mask = var.mask
    var, cellArea = mask_latitude_bands(var,cellArea,geoLat,geoLon,region=region)
    #-- Land depth averaging and summation
    if cellDepth is not None:
      summed = np.ma.sum(var * cellArea * np.tile(cellDepth[:,None,None], (1,var.shape[1],var.shape[2])))
      var = np.ma.average(var,axis=0,weights=cellDepth)
      res = np.ma.sum(var*cellArea)/cellArea.sum()
      return res, summed
    else:
      res = np.ma.sum(var*cellArea)/cellArea.sum()
      return res, cellArea.sum()

def cube_sphere_aggregate(var,tiles):
    return np.ma.concatenate((tiles[0].variables[var][:], tiles[1].variables[var][:],\
                              tiles[2].variables[var][:], tiles[3].variables[var][:],\
                              tiles[4].variables[var][:], tiles[5].variables[var][:]),axis=-1)

def write_sqlite_data(sqlfile,varName,fYear,varmean=None,varsum=None,component=None):
    conn = sqlite3.connect(sqlfile)
    c = conn.cursor()
    if component == 'land':
      sql = 'create table if not exists '+varName+' (year integer primary key, sum float, avg float)'
    else:
      sql = 'create table if not exists '+varName+' (year integer primary key, value float)'
    sqlres = c.execute(sql)
    if component == 'land':
      sql = 'insert or replace into '+varName+' values('+fYear[:4]+','+str(varsum)+','+str(varmean)+')'
    else:
      sql = 'insert or replace into '+varName+' values('+fYear[:4]+','+str(varmean)+')'
    sqlres = c.execute(sql)
    conn.commit()
    c.close()
    conn.close()

EOF

cat > merge.py <<EOF
import sqlite3, sys
#
## usage python merge.py src dst
#
con = sqlite3.connect(sys.argv[2])
cur = con.cursor()
sql = "ATTACH '"+sys.argv[1]+"' as src"
cur.execute(sql)
cur.close()
cur = con.cursor()
sql = "SELECT * FROM main.sqlite_master WHERE type='table'"
cur.execute(sql)
main_tables = cur.fetchall()
cur.close()
cur = con.cursor()
sql = "SELECT * FROM src.sqlite_master WHERE type='table'"
cur.execute(sql)
src_tables = cur.fetchall()
cur.close()
for var in src_tables:
  varname = var[1]
  if varname not in [x[1] for x in src_tables]:
    cur = con.cursor()
    cur.execute(var[-1])
    cur.close()
  cur = con.cursor()
  sql = "INSERT OR REPLACE into "+varname+" SELECT * FROM src."+varname
  cur.execute(sql)
  cur.close()
con.commit()
con.close()
exit(0)

EOF

cat > global_average_cubesphere.py <<EOF
import gmeantools
import netCDF4 as nc
import numpy as np
import sqlite3
import sys

fYear = sys.argv[1]
outdir = sys.argv[2]
label = sys.argv[3]
history = sys.argv[4]

gs_tiles = []
for tx in range(1,7): gs_tiles.append(gmeantools.ncopen(fYear + '.grid_spec.tile'+str(tx)+'.nc'))

data_tiles = []
for tx in range(1,7): data_tiles.append(gmeantools.ncopen(fYear + '.'+history+'.tile'+str(tx)+'.nc'))

geoLat = gmeantools.cube_sphere_aggregate('grid_latt',gs_tiles)
geoLon = gmeantools.cube_sphere_aggregate('grid_lont',gs_tiles)
cellArea = gmeantools.cube_sphere_aggregate('area',gs_tiles)

for varName in data_tiles[0].variables.keys():
  if (len(data_tiles[0].variables[varName].shape) == 3):
    var = gmeantools.cube_sphere_aggregate(varName,data_tiles)
    var = np.ma.average(var,axis=0,weights=data_tiles[0].variables['average_DT'][:])
    for reg in ['global','tropics','nh','sh']:
      result, _null = gmeantools.area_mean(var,cellArea,geoLat,geoLon,region=reg)
      gmeantools.write_sqlite_data(outdir+'/'+fYear+'.'+reg+'Ave'+label+'.db',varName,fYear[:4],result)

EOF

cat > global_average_tripolar.py <<EOF
import gmeantools
import netCDF4 as nc
import numpy as np
import sqlite3
import sys
import glob

fYear = sys.argv[1]
outdir = sys.argv[2]
label = sys.argv[3]
history = str(sys.argv[4]).split(',')

fgs = gmeantools.ncopen(fYear + '.ocean_static.nc')

geoLat   = fgs.variables['geolat'][:]
geoLon   = fgs.variables['geolon'][:]
cellArea = fgs.variables['areacello'][:]

for oceanFile in history:
  fdata = gmeantools.ncopen(fYear + '.' + oceanFile + '.nc',action=None)
  if fdata is not None:
    for varName in fdata.variables.keys():
      if (len(fdata.variables[varName].shape) == 3):
        dims = fdata.variables[varName].dimensions
        if (dims[1] == 'yh' and dims[2] == 'xh'):
          var = fdata.variables[varName][:]
          var = np.ma.average(var,axis=0,weights=fdata.variables['average_DT'][:])
          for reg in ['global','tropics','nh','sh']:
            result, areaSum = gmeantools.area_mean(var,cellArea,geoLat,geoLon,region=reg)
            gmeantools.write_sqlite_data(outdir+'/'+fYear+'.'+reg+'Ave'+label+'.db',varName,fYear[:4],result)
            gmeantools.write_sqlite_data(outdir+'/'+fYear+'.'+reg+'Ave'+label+'.db','area',fYear[:4],areaSum)
  else:
    continue

EOF

cat > global_average_ice.py <<EOF
import gmeantools
import netCDF4 as nc
import numpy as np
import sqlite3
import sys

fYear = sys.argv[1]
outdir = sys.argv[2]
label = sys.argv[3]

fgs   = gmeantools.ncopen(fYear + '.ice_static.nc')
fdata = gmeantools.ncopen(fYear + '.ice_month.nc')

geoLon = fgs.variables['GEOLON'][:]
geoLat = fgs.variables['GEOLAT'][:]

average_DT = fdata.variables['average_DT'][:]

if 'CELL_AREA' in fgs.variables.keys():
  rE = 6371.0e3  # Radius of the Earth in 'm'
  cellArea = fgs.variables['CELL_AREA'][:] * (4.*np.pi*(rE**2))
elif 'area' in fgs.variables.keys():
  cellArea = fgs.variables['area'][:]
else:
  print('FATAL: unable to determine cell area used in ice model')

if 'siconc' in fdata.variables.keys():
  concentration = fdata.variables['siconc'][:]
elif 'CN' in fdata.variables.keys():
  concentration = np.ma.sum(fdata.variables['CN'][:],axis=-3)
else:
  print('FATAL: unable to determine ice concentration')

geoLat = np.tile(geoLat[None,:], (concentration.shape[0],1,1))
geoLon = np.tile(geoLon[None,:], (concentration.shape[0],1,1))
cellArea = np.tile(cellArea[None,:], (concentration.shape[0],1,1))

for reg in ['global','nh','sh']:
  sqlite_out = outdir+'/'+fYear+'.'+reg+'Ave'+label+'.db'

  vars = []
  # area and extent in million square km
  _conc, _area = gmeantools.mask_latitude_bands(concentration,cellArea,geoLat,geoLon,region=reg)
  vars.append(('area',(np.ma.sum((_conc * _area),axis=(-1,-2))*1.e-12)))
  vars.append(('extent',(np.ma.sum((np.ma.where(np.greater(_conc,0.15),_area,0.)),axis=(-1,-2))*1.e-12)))
  for v in vars:
    gmeantools.write_sqlite_data(sqlite_out,v[0]+'_mean',fYear[:4],np.ma.average(v[1],weights=average_DT))
    gmeantools.write_sqlite_data(sqlite_out,v[0]+'_max', fYear[:4],np.ma.max(v[1]))
    gmeantools.write_sqlite_data(sqlite_out,v[0]+'_min', fYear[:4],np.ma.min(v[1]))

for v in fdata.variables.keys():
  #if len(fdata.variables[v].shape) == 3:
  if fdata.variables[v].shape == cellArea.shape:
    data = fdata.variables[v][:]
    for reg in ['global','nh','sh']:
      sqlite_out = outdir+'/'+fYear+'.'+reg+'Ave'+label+'.db'
      _v, _area = gmeantools.mask_latitude_bands(data,cellArea,geoLat,geoLon,region=reg)
      _v = np.ma.sum((_v*_area),axis=(-1,-2))/np.ma.sum(_area,axis=(-1,-2))
      gmeantools.write_sqlite_data(sqlite_out,v+'_mean',fYear[:4],np.ma.average(_v,axis=0,weights=average_DT))
      gmeantools.write_sqlite_data(sqlite_out,v+'_max', fYear[:4],np.ma.max(_v))
      gmeantools.write_sqlite_data(sqlite_out,v+'_min', fYear[:4],np.ma.min(_v))

EOF

cat > extract_ocean_scalar.py <<EOF
import gmeantools
import netCDF4 as nc
import numpy as np
import sqlite3
import sys

fYear = sys.argv[1]
outdir = sys.argv[2]

fdata = gmeantools.ncopen(fYear + '.ocean_scalar_annual.nc')

ignoreList = ['time_bounds', 'time_bnds', 'average_T2', 'average_T1', 'average_DT']
varDict = fdata.variables.keys()
varDict = list(set(varDict) - set(ignoreList))

for varName in varDict:
  if len(fdata.variables[varName].shape) == 2:
    result = fdata.variables[varName][0,0]
    gmeantools.write_sqlite_data(outdir+'/'+fYear+'.globalAveOcean.db',varName,fYear[:4],result)

EOF

cat > amoc.py <<EOF
import gmeantools
import netCDF4 as nc
import numpy as np
from scipy.io import netcdf
import sqlite3
import sys
import tarfile

fYear = sys.argv[1]
outdir = sys.argv[2]
gsFile = sys.argv[3]

sys.path.append('/nbhome/ogrp/warsaw_201710_MOM6_2017.10.19/OM4p25_IAF_baseline/mom6/tools/analysis/')

import m6toolbox

#-- Read VMO from file
vhFile = gmeantools.ncopen(fYear+'.ocean_annual_z.nc')
if 'vmo' in vhFile.variables.keys():
    vh  = (vhFile.variables['vmo'][0].filled(0)) * 1.e-9
    zt  = vhFile.variables['z_l'][:]
    yq  = vhFile.variables['yq'][:]
else:
    print('amoc.py FATAL: vmo variable not present in ocean_annual_z.nc')
    exit(0)

#-- Get grid info from gridspec file
if gsFile.split('.')[-1] == 'tar':
    TF = tarfile.open(gsFile,'r')
    member = [m for m in TF.getmembers() if 'ocean_hgrid' in m.name][0]
    nc = netcdf.netcdf_file(TF.extractfile(member),'r')
    x = nc.variables['x'][1::2,1::2]
    y = nc.variables['y'][1::2,1::2]
    member = [m for m in TF.getmembers() if 'topog' in m.name][0]
    nc = netcdf.netcdf_file(TF.extractfile(member),'r')
    depth = nc.variables['depth'][:]
    code = m6toolbox.genBasinMasks(x, y, depth)
else:
    print('amoc.py FATAL: expecting grid_spec to be a tarfile')

#-- Define atlantic/arctic mask
atlmask = np.where(np.logical_or(code==2,code==4),1.,0.)

#-- Compute psi
psi = m6toolbox.MOCpsi(vh,vmsk=atlmask)
maxsfn = np.max(psi[np.logical_and(zt>500,zt<2500)][:,np.greater_equal(yq,20)])
print('AMOC vh = %s' % maxsfn)

gmeantools.write_sqlite_data(outdir+'/'+fYear+'.globalAveOcean.db','amoc_vh',fYear[:4],maxsfn)

EOF

cat > global_average_land.py <<EOF
import gmeantools
import numpy as np
import netCDF4 as nc
import pickle
import re
import sqlite3
import sys
import urllib2

fYear = sys.argv[1]
outdir = sys.argv[2]
label = sys.argv[3]
history = sys.argv[4]

gs_tiles = []
for tx in range(1,7): gs_tiles.append(gmeantools.ncopen(fYear + '.land_static.tile'+str(tx)+'.nc'))

data_tiles = []
for tx in range(1,7): data_tiles.append(gmeantools.ncopen(fYear + '.'+history+'.tile'+str(tx)+'.nc'))

geoLat = gmeantools.cube_sphere_aggregate('geolat_t',gs_tiles)
geoLon = gmeantools.cube_sphere_aggregate('geolon_t',gs_tiles)
cellArea = gmeantools.cube_sphere_aggregate('land_area',gs_tiles)
cellFrac = gmeantools.cube_sphere_aggregate('land_frac',gs_tiles)
soilArea = gmeantools.cube_sphere_aggregate('soil_area',gs_tiles)
soilFrac = np.ma.array(soilArea/(cellArea*cellFrac))

depth = data_tiles[0].variables['zhalf_soil'][:]
cellDepth = []
for i in range(1,len(depth)):
  thickness = round((depth[i] - depth[i-1]),2)
  cellDepth.append(thickness)
cellDepth = np.array(cellDepth)

for varName in data_tiles[0].variables.keys():
  varshape = data_tiles[0].variables[varName].shape
  if (len(varshape) >= 3):
    var = gmeantools.cube_sphere_aggregate(varName,data_tiles)
    var = np.ma.average(var,axis=0,weights=data_tiles[0].variables['average_DT'][:])

    if (len(varshape) == 3):
      for reg in ['global','tropics','nh','sh']:
        avg, wgt = gmeantools.area_mean(var,cellArea,geoLat,geoLon,cellFrac=cellFrac,soilFrac=soilFrac,\
                                       region=reg,varName=varName,component='land')
        if not hasattr(avg,'mask'):
          gmeantools.write_sqlite_data(outdir+'/'+fYear+'.'+reg+'Ave'+label+'.db',varName,fYear[:4],\
                                       varmean=avg,varsum=avg*wgt,component='land')

    elif (len(varshape) == 4):
      if varshape[1] == cellDepth.shape[0]:
        for reg in ['global','tropics','nh','sh']:
          avg, summed = gmeantools.area_mean(var,cellArea,geoLat,geoLon,cellFrac=cellFrac,soilFrac=soilFrac,\
                                             region=reg,varName=varName,cellDepth=cellDepth,component='land')
          gmeantools.write_sqlite_data(outdir+'/'+fYear+'.'+reg+'Ave'+label+'.db',varName,fYear[:4],\
                                       varmean=avg,varsum=summed,component='land')

EOF

#-- Run the averager script
python global_average_cubesphere.py ${oname} ${refineDiagDir} Atmos atmos_month
python global_average_cubesphere.py ${oname} ${refineDiagDir} AtmosAer atmos_month_aer
python global_average_land.py ${oname} ${refineDiagDir} Land land_month
python global_average_ice.py ${oname} ${refineDiagDir} Ice ice_month
python global_average_tripolar.py ${oname} ${refineDiagDir} COBALT ocean_cobalt_sfc,garbage,ocean_cobalt_misc
python extract_ocean_scalar.py ${oname} ${refineDiagDir}
python amoc.py ${oname} ${refineDiagDir} ${gridspec}

#-- Copy the database back to its original location
foreach reg (global nh sh tropics)
  foreach component (Atmos AtmosAer Land Ice COBALT Ocean)
    if ( ! -f ${localRoot}/db/${reg}Ave${component}.db ) then
      cp -fv ${refineDiagDir}/${oname}.${reg}Ave${component}.db ${localRoot}/db/${reg}Ave${component}.db
    else
      python merge.py ${refineDiagDir}/${oname}.${reg}Ave${component}.db ${localRoot}/db/${reg}Ave${component}.db
    endif
  end 
end

#-- Make an archive of the single-year sqlite files
set savepath = /archive/${USER}/`echo ${archive} | cut -f 4-100 -d '/'`
mkdir -p ${savepath}/ascii
pushd ${refineDiagDir}
foreach f (*.db)
  if ( ! -f ${savepath}/ascii/sqlite_files.tar ) then
    tar -cvf ${savepath}/ascii/sqlite_files.tar $f
  else
    tar -rvf ${savepath}/ascii/sqlite_files.tar $f
  endif
end
popd

date
echo "  ---------- end refineDiag_data_stager.csh ----------  "
