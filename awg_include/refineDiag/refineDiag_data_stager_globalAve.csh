#------------------------------------------------------------------------------
#  refineDiag_data_stager_globalAve.csh
#
#  2014/05/07 JPK
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
echo ""
echo ""
echo ""
echo "  ---------- begin refineDiag_data_stager.csh ----------  "
cd $work/$hsmdate
pwd
#-- This block is to run the refactored diagnostics and ingest them 
#-- into the mySQL database det_analysis currently running on Cobweb.
if ( $?tripleID  ) then
    if ( ${tripleID} != "" ) then
        python /home/fms/local/opt/fre-analysis/test/eem/code/detVitals/atmos_analysis.py -t ${tripleID} -y ${oname}
        python /home/fms/local/opt/fre-analysis/test/eem/code/detVitals/ocean_analysis.py -t ${tripleID} -y ${oname}
        python /home/fms/local/opt/fre-analysis/test/eem/code/detVitals/land_analysis.py -t ${tripleID} -y ${oname}
        python /home/fms/local/opt/fre-analysis/test/eem/code/detVitals/cobalt_analysis.py -t ${tripleID} -y ${oname}
        python /home/fms/local/opt/fre-analysis/test/eem/code/detVitals/detVitalsAverager.py -t ${tripleID} 
    else
        echo "tripleID for the experiment ${name} is not properly set... skipping detVitals diagnostics."
    endif
else
    echo "tripleID for the experiment ${name} is not properly set... skipping detVitals diagnostics."
endif
#-- Unload any previous versions of Python and load the system default
module unload python
module unload cdat
module load python
#-- Unpack gridSpec file.  Right now this hardcoded and this is bad practice.  
#   It would be much better to have the refineDiag script know about the gridSpec location
#   through an already populated FRE variable.  Will talk to Amy L. about alternatives.
#set gridSpecFile = "/archive/cjg/mdt/awg/input/grid/c96_GIS_025_grid_v20140327.tar"
#set gsArchRoot = `echo ${gridSpecFile} | rev | cut -f 2-100 -d '/' | rev`
#set gsBaseName = `basename ${gridSpecFile} | cut -f 1 -d '.'`
#hsmget -v -a ${gsArchRoot} -p /ptmp/$USER/${gsArchRoot} -w `pwd` ${gsBaseName}/\*
#-- Create a directory to house the sqlite database (if it does not already exist)
set localRoot = `echo $scriptName | rev | cut -f 4-100 -d '/' | rev`
if (! -d ${localRoot}/db) then 
  mkdir -p ${localRoot}/db
endif
set user = `whoami`
#-- Create the website entry for the experiment (if it does not already exist).
if ( ! -d /home/mdteam/internal_html/cm4/${user}/${name} ) then
  mkdir -p /home/mdteam/internal_html/cm4/${user}/${name}/
  gcp -v /home/mdteam/internal_html/cm4/.webTemplates/* /home/mdteam/internal_html/cm4/${user}/${name}
  ln -s /home/mdteam/internal_html/cm4/${user}/${name}/global.php /home/mdteam/internal_html/cm4/${user}/${name}/index.php
  mv -f /home/mdteam/internal_html/cm4/${user}/${name}/setup.php /home/mdteam/internal_html/cm4/${user}/${name}/setup.php.bak
  cat /home/mdteam/internal_html/cm4/${user}/${name}/setup.php.bak | sed "s|output_dir|${localRoot}|g" >> /home/mdteam/internal_html/cm4/${user}/${name}/setup.php
  sleep 2
  mv -f /home/mdteam/internal_html/cm4/${user}/${name}/setup.php /home/mdteam/internal_html/cm4/${user}/${name}/setup.php.bak
  cat /home/mdteam/internal_html/cm4/${user}/${name}/setup.php.bak | sed "s|experiment_name|${name}|g" >> /home/mdteam/internal_html/cm4/${user}/${name}/setup.php
  sqlite3 /home/Oar.Gfdl.Mdteam/internal_html/cm4/experiments.db "INSERT INTO experiments (user, experiment) VALUES ('${user}','${name}')"
endif
#-- If db exists, copy it for safe keeping and prevent file locks in the 
foreach reg (global nh sh tropics)
  cp -f ${localRoot}/db/${reg}AveAtmos.db ${localRoot}/db/.${reg}AveAtmos.db
  cp -f ${localRoot}/db/${reg}AveAtmosAer.db ${localRoot}/db/.${reg}AveAtmosAer.db
  cp -f ${localRoot}/db/${reg}AveOcean.db ${localRoot}/db/.${reg}AveOcean.db
  cp -f ${localRoot}/db/${reg}AveLand.db ${localRoot}/db/.${reg}AveLand.db  
  cp -f ${localRoot}/db/${reg}AveCOBALT.db ${localRoot}/db/.${reg}AveCOBALT.db  
end
#-- Cat a Python script that performs the averages and writes to a copy of the DB
#   in case it is locked by another user
cat > global_atmos_ave.py <<EOF
import sqlite3, cdms2, cdutil, MV2, numpy, cdtime
import sys
# Set current year
fYear = "${oname}"
fgs1 = cdms2.open(fYear + '.grid_spec.tile1.nc')
fgs2 = cdms2.open(fYear + '.grid_spec.tile2.nc')
fgs3 = cdms2.open(fYear + '.grid_spec.tile3.nc')
fgs4 = cdms2.open(fYear + '.grid_spec.tile4.nc')
fgs5 = cdms2.open(fYear + '.grid_spec.tile5.nc')
fgs6 = cdms2.open(fYear + '.grid_spec.tile6.nc')
geoLat   = MV2.concatenate((MV2.array(fgs1('grid_latt')), MV2.array(fgs2('grid_latt')), MV2.array(fgs3('grid_latt')), MV2.array(fgs4('grid_latt')), MV2.array(fgs5('grid_latt')), MV2.array(fgs6('grid_latt'))),axis=0)
geoLon   = MV2.concatenate((MV2.array(fgs1('grid_lont')), MV2.array(fgs2('grid_lont')), MV2.array(fgs3('grid_lont')), MV2.array(fgs4('grid_lont')), MV2.array(fgs5('grid_lont')), MV2.array(fgs6('grid_lont'))),axis=0)
cellArea = MV2.concatenate((MV2.array(fgs1('area')), MV2.array(fgs2('area')), MV2.array(fgs3('area')), MV2.array(fgs4('area')), MV2.array(fgs5('area')), MV2.array(fgs6('area'))),axis=0)
#Read in 6 nc files
fdata1 = cdms2.open(fYear + '.atmos_month.tile1.nc')
fdata2 = cdms2.open(fYear + '.atmos_month.tile2.nc')
fdata3 = cdms2.open(fYear + '.atmos_month.tile3.nc')
fdata4 = cdms2.open(fYear + '.atmos_month.tile4.nc')
fdata5 = cdms2.open(fYear + '.atmos_month.tile5.nc')
fdata6 = cdms2.open(fYear + '.atmos_month.tile6.nc')
def areaMean(varName,cellArea,geoLat,geoLon,region='global'):
  var = MV2.concatenate((MV2.array(fdata1(varName)), MV2.array(fdata2(varName)), MV2.array(fdata3(varName)), MV2.array(fdata4(varName)), MV2.array(fdata5(varName)), MV2.array(fdata6(varName))),axis=1)
  var = cdutil.YEAR(var).squeeze()
  if (region == 'tropics'):
    var = MV2.masked_where(MV2.logical_or(geoLat < -30., geoLat > 30.),var)
    cellArea = MV2.masked_where(MV2.logical_or(geoLat < -30., geoLat > 30.),cellArea)
  elif (region == 'nh'):
    var  = MV2.masked_where(MV2.less_equal(geoLat,30.),var)
    cellArea  = MV2.masked_where(MV2.less_equal(geoLat,30.),cellArea)
  elif (region == 'sh'):
    var  = MV2.masked_where(MV2.greater_equal(geoLat,-30.),var)
    cellArea  = MV2.masked_where(MV2.greater_equal(geoLat,-30.),cellArea)
  elif (region == 'global'):
    var  = var
    cellArea = cellArea
  res = MV2.array(var*cellArea).sum()/cellArea.sum()
  return res
varDict = fdata1.variables
globalMeanDic={}
tropicsMeanDic={}
nhMeanDic={}
shMeanDic={}
for varName in varDict:
  if (len(varDict[varName].shape) == 3):
    
    conn = sqlite3.connect("${localRoot}/db/.globalAveAtmos.db")
    c = conn.cursor()
    globalMeanDic[varName] = areaMean(varName,cellArea,geoLat,geoLon,region='global')
    sql = 'create table if not exists ' + varName + ' (year integer primary key, value float)'
    sqlres = c.execute(sql)
    sql = 'insert or replace into ' + varName + ' values(' + fYear[:4] + ',' + str(globalMeanDic[varName]) + ')'
    try:
      sqlres = c.execute(sql)
      conn.commit()
    except:
      pass
    c.close()
    conn.close()
    
    conn = sqlite3.connect("${localRoot}/db/.tropicsAveAtmos.db")
    c = conn.cursor()
    globalMeanDic[varName] = areaMean(varName,cellArea,geoLat,geoLon,region='tropics')
    sql = 'create table if not exists ' + varName + ' (year integer primary key, value float)'
    sqlres = c.execute(sql)
    sql = 'insert or replace into ' + varName + ' values(' + fYear[:4] + ',' + str(globalMeanDic[varName]) + ')'
    try:
      sqlres = c.execute(sql)
      conn.commit()
    except:
      pass
    c.close()
    conn.close()
    
    conn = sqlite3.connect("${localRoot}/db/.nhAveAtmos.db")
    c = conn.cursor()
    globalMeanDic[varName] = areaMean(varName,cellArea,geoLat,geoLon,region='nh')
    sql = 'create table if not exists ' + varName + ' (year integer primary key, value float)'
    sqlres = c.execute(sql)
    sql = 'insert or replace into ' + varName + ' values(' + fYear[:4] + ',' + str(globalMeanDic[varName]) + ')'
    try:
      sqlres = c.execute(sql)
      conn.commit()
    except:
      pass
    c.close()
    conn.close()
    
    conn = sqlite3.connect("${localRoot}/db/.shAveAtmos.db")
    c = conn.cursor()
    globalMeanDic[varName] = areaMean(varName,cellArea,geoLat,geoLon,region='sh')
    sql = 'create table if not exists ' + varName + ' (year integer primary key, value float)'
    sqlres = c.execute(sql)
    sql = 'insert or replace into ' + varName + ' values(' + fYear[:4] + ',' + str(globalMeanDic[varName]) + ')'
    try:
      sqlres = c.execute(sql)
      conn.commit()
    except:
      pass
    c.close()
    conn.close()
EOF
cat > global_atmos_aer_ave.py <<EOF
import sqlite3, cdms2, cdutil, MV2, numpy, cdtime
import sys
# Set current year
fYear = "${oname}"
fgs1 = cdms2.open(fYear + '.grid_spec.tile1.nc')
fgs2 = cdms2.open(fYear + '.grid_spec.tile2.nc')
fgs3 = cdms2.open(fYear + '.grid_spec.tile3.nc')
fgs4 = cdms2.open(fYear + '.grid_spec.tile4.nc')
fgs5 = cdms2.open(fYear + '.grid_spec.tile5.nc')
fgs6 = cdms2.open(fYear + '.grid_spec.tile6.nc')
geoLat   = MV2.concatenate((MV2.array(fgs1('grid_latt')), MV2.array(fgs2('grid_latt')), MV2.array(fgs3('grid_latt')), MV2.array(fgs4('grid_latt')), MV2.array(fgs5('grid_latt')), MV2.array(fgs6('grid_latt'))),axis=0)
geoLon   = MV2.concatenate((MV2.array(fgs1('grid_lont')), MV2.array(fgs2('grid_lont')), MV2.array(fgs3('grid_lont')), MV2.array(fgs4('grid_lont')), MV2.array(fgs5('grid_lont')), MV2.array(fgs6('grid_lont'))),axis=0)
cellArea = MV2.concatenate((MV2.array(fgs1('area')), MV2.array(fgs2('area')), MV2.array(fgs3('area')), MV2.array(fgs4('area')), MV2.array(fgs5('area')), MV2.array(fgs6('area'))),axis=0)
#Read in 6 nc files
fdata1 = cdms2.open(fYear + '.atmos_month_aer.tile1.nc')
fdata2 = cdms2.open(fYear + '.atmos_month_aer.tile2.nc')
fdata3 = cdms2.open(fYear + '.atmos_month_aer.tile3.nc')
fdata4 = cdms2.open(fYear + '.atmos_month_aer.tile4.nc')
fdata5 = cdms2.open(fYear + '.atmos_month_aer.tile5.nc')
fdata6 = cdms2.open(fYear + '.atmos_month_aer.tile6.nc')
def areaMean(varName,cellArea,geoLat,geoLon,region='global'):
  var = MV2.concatenate((MV2.array(fdata1(varName)), MV2.array(fdata2(varName)), MV2.array(fdata3(varName)), MV2.array(fdata4(varName)), MV2.array(fdata5(varName)), MV2.array(fdata6(varName))),axis=1)
  var = cdutil.YEAR(var).squeeze()
  if (region == 'tropics'):
    var = MV2.masked_where(MV2.logical_or(geoLat < -30., geoLat > 30.),var)
    cellArea = MV2.masked_where(MV2.logical_or(geoLat < -30., geoLat > 30.),cellArea)
  elif (region == 'nh'):
    var  = MV2.masked_where(MV2.less_equal(geoLat,30.),var)
    cellArea  = MV2.masked_where(MV2.less_equal(geoLat,30.),cellArea)
  elif (region == 'sh'):
    var  = MV2.masked_where(MV2.greater_equal(geoLat,-30.),var)
    cellArea  = MV2.masked_where(MV2.greater_equal(geoLat,-30.),cellArea)
  elif (region == 'global'):
    var  = var
    cellArea = cellArea
  res = MV2.array(var*cellArea).sum()/cellArea.sum()
  return res
varDict = fdata1.variables
globalMeanDic={}
tropicsMeanDic={}
nhMeanDic={}
shMeanDic={}
for varName in varDict:
  if (len(varDict[varName].shape) == 3):
    
    conn = sqlite3.connect("${localRoot}/db/.globalAveAtmosAer.db")
    c = conn.cursor()
    globalMeanDic[varName] = areaMean(varName,cellArea,geoLat,geoLon,region='global')
    sql = 'create table if not exists ' + varName + ' (year integer primary key, value float)'
    sqlres = c.execute(sql)
    sql = 'insert or replace into ' + varName + ' values(' + fYear[:4] + ',' + str(globalMeanDic[varName]) + ')'
    try:
      sqlres = c.execute(sql)
      conn.commit()
    except:
      pass
    c.close()
    conn.close()
    
    conn = sqlite3.connect("${localRoot}/db/.tropicsAveAtmosAer.db")
    c = conn.cursor()
    globalMeanDic[varName] = areaMean(varName,cellArea,geoLat,geoLon,region='tropics')
    sql = 'create table if not exists ' + varName + ' (year integer primary key, value float)'
    sqlres = c.execute(sql)
    sql = 'insert or replace into ' + varName + ' values(' + fYear[:4] + ',' + str(globalMeanDic[varName]) + ')'
    try:
      sqlres = c.execute(sql)
      conn.commit()
    except:
      pass
    c.close()
    conn.close()
    
    conn = sqlite3.connect("${localRoot}/db/.nhAveAtmosAer.db")
    c = conn.cursor()
    globalMeanDic[varName] = areaMean(varName,cellArea,geoLat,geoLon,region='nh')
    sql = 'create table if not exists ' + varName + ' (year integer primary key, value float)'
    sqlres = c.execute(sql)
    sql = 'insert or replace into ' + varName + ' values(' + fYear[:4] + ',' + str(globalMeanDic[varName]) + ')'
    try:
      sqlres = c.execute(sql)
      conn.commit()
    except:
      pass
    c.close()
    conn.close()
    
    conn = sqlite3.connect("${localRoot}/db/.shAveAtmosAer.db")
    c = conn.cursor()
    globalMeanDic[varName] = areaMean(varName,cellArea,geoLat,geoLon,region='sh')
    sql = 'create table if not exists ' + varName + ' (year integer primary key, value float)'
    sqlres = c.execute(sql)
    sql = 'insert or replace into ' + varName + ' values(' + fYear[:4] + ',' + str(globalMeanDic[varName]) + ')'
    try:
      sqlres = c.execute(sql)
      conn.commit()
    except:
      pass
    c.close()
    conn.close()
EOF
cat > global_land_ave.py <<EOF
import sqlite3, cdms2, cdutil, MV2, numpy, cdtime
import sys, re
import urllib2
import pickle
# Set current year
fYear = "${oname}"
# Test to see if sqlite database existsm if notm then create it
dbFile = "${localRoot}/db/.globalAveLand.db"
# Read in gridSpec files
fgs1 = cdms2.open(fYear + '.land_static.tile1.nc')
fgs2 = cdms2.open(fYear + '.land_static.tile2.nc')
fgs3 = cdms2.open(fYear + '.land_static.tile3.nc')
fgs4 = cdms2.open(fYear + '.land_static.tile4.nc')
fgs5 = cdms2.open(fYear + '.land_static.tile5.nc')
fgs6 = cdms2.open(fYear + '.land_static.tile6.nc')
geoLat   = MV2.concatenate((MV2.array(fgs1('geolat_t')), MV2.array(fgs2('geolat_t')), MV2.array(fgs3('geolat_t')), MV2.array(fgs4('geolat_t')), MV2.array(fgs5('geolat_t')), MV2.array(fgs6('geolat_t'))),axis=0)
geoLon   = MV2.concatenate((MV2.array(fgs1('geolon_t')), MV2.array(fgs2('geolon_t')), MV2.array(fgs3('geolon_t')), MV2.array(fgs4('geolon_t')), MV2.array(fgs5('geolon_t')), MV2.array(fgs6('geolon_t'))),axis=0)
cellArea = MV2.concatenate((MV2.array(fgs1('land_area')), MV2.array(fgs2('land_area')), MV2.array(fgs3('land_area')), MV2.array(fgs4('land_area')), MV2.array(fgs5('land_area')), MV2.array(fgs6('land_area'))),axis=0)
cellFrac = MV2.concatenate((MV2.array(fgs1('land_frac')), MV2.array(fgs2('land_frac')), MV2.array(fgs3('land_frac')), MV2.array(fgs4('land_frac')), MV2.array(fgs5('land_frac')), MV2.array(fgs6('land_frac'))),axis=0)
soilArea = MV2.concatenate((MV2.array(fgs1('soil_area')), MV2.array(fgs2('soil_area')), MV2.array(fgs3('soil_area')), MV2.array(fgs4('soil_area')), MV2.array(fgs5('soil_area')), MV2.array(fgs6('soil_area'))),axis=0)
fdata1 = cdms2.open(fYear + '.land_month.tile1.nc')
fdata2 = cdms2.open(fYear + '.land_month.tile2.nc')
fdata3 = cdms2.open(fYear + '.land_month.tile3.nc')
fdata4 = cdms2.open(fYear + '.land_month.tile4.nc')
fdata5 = cdms2.open(fYear + '.land_month.tile5.nc')
fdata6 = cdms2.open(fYear + '.land_month.tile6.nc')
depth = fdata1.axes['zhalf_soil'][:]
cellDepth = []
for i in range(1,len(depth)):
  thickness = round((depth[i] - depth[i-1]),2)
  cellDepth.append(thickness)
soilFrac = MV2.array(soilArea/(cellArea*cellFrac))
def getWebsiteVariablesDic():
  varDic = pickle.load(open("/home/fms/local/opt/fre-analysis/test/eem/code/cm4_web_analysis/etc/LM3_variable_dictionary.pkl", 'rb'))
  return varDic
def dbEntry(db,varName,varSum,varAvg,fYear):
  conn = sqlite3.connect(db)
  c = conn.cursor()
  sql = 'create table if not exists ' + varName + ' (year integer primary key, sum float, avg float)'
  sqlres = c.execute(sql)
  sql = 'insert or replace into ' + varName + ' values(' + fYear[:4] + ',' + str(varSum) + ',' + str(varAvg) + ')'
  try:
    sqlres = c.execute(sql)
    conn.commit()
  except:
    pass
  c.close()
  conn.close()
  return
def areaMean(varName,cellArea,cellFrac,soilFrac,geoLat,geoLon,region='global'):
  moduleDic = getWebsiteVariablesDic()
  var = MV2.concatenate((MV2.array(fdata1(varName)), MV2.array(fdata2(varName)), MV2.array(fdata3(varName)), MV2.array(fdata4(varName)), MV2.array(fdata5(varName)), MV2.array(fdata6(varName))),axis=1)
  var = MV2.masked_where(MV2.equal(var,fdata1(varName)._FillValue), var)
  var = cdutil.YEAR(var).squeeze()
  cellArea = MV2.masked_where(MV2.equal(var,fdata1(varName)._FillValue), cellArea)
  cellFrac = MV2.masked_where(MV2.equal(var,fdata1(varName)._FillValue), cellFrac)
  soilFrac = MV2.masked_where(MV2.equal(var,fdata1(varName)._FillValue), soilFrac)
  try:
    module = moduleDic[varName]
  except:
    try:
      module = moduleDic[varName.lower()]
    except:
      return None
  if (region == 'tropics'):
    var = MV2.masked_where(MV2.logical_or(geoLat < -30., geoLat > 30.),var)
    cellArea = MV2.masked_where(MV2.logical_or(geoLat < -30., geoLat > 30.),cellArea)
    cellFrac = MV2.masked_where(MV2.logical_or(geoLat < -30., geoLat > 30.),cellFrac)
    soilFrac = MV2.masked_where(MV2.logical_or(geoLat < -30., geoLat > 30.),soilFrac)
  elif (region == 'nh'):
    var = MV2.masked_where(MV2.less_equal(geoLat,30.),var)
    cellArea = MV2.masked_where(MV2.less_equal(geoLat,30.),cellArea)
    cellFrac = MV2.masked_where(MV2.less_equal(geoLat,30.),cellFrac)
    soilFrac = MV2.masked_where(MV2.less_equal(geoLat,30.),soilFrac)
  elif ( region == 'sh'):
    var = MV2.masked_where(MV2.greater_equal(geoLat,-30.),var)
    cellArea = MV2.masked_where(MV2.greater_equal(geoLat,-30.),cellArea)
    cellFrac = MV2.masked_where(MV2.greater_equal(geoLat,-30.),cellFrac)
    soilFrac = MV2.masked_where(MV2.greater_equal(geoLat,-30.),soilFrac)
  elif (region == 'global'):
    var = var
    cellArea = cellArea
    cellFrac = cellFrac
    soilFrac = soilFrac
  if module != 'vegn':  
    varSum = MV2.array(var*cellArea*cellFrac).sum()
    varAvg = varSum/(cellArea*cellFrac).sum()
  elif module == 'vegn':
    varSum = MV2.array(var*cellArea*cellFrac*soilFrac).sum()
    varAvg = varSum/(cellArea*cellFrac*soilFrac).sum()
  return varSum, varAvg
def areaMean3D(varName,cellArea,cellFrac,cellDepth,soilFrac,geoLat,geoLon,region='global'):
  var = MV2.concatenate((MV2.array(fdata1(varName)), MV2.array(fdata2(varName)), MV2.array(fdata3(varName)), MV2.array(fdata4(varName)), MV2.array(fdata5(varName)), MV2.array(fdata6(varName))),axis=2)
  var = MV2.masked_where(MV2.equal(var,fdata1(varName)._FillValue),var)
  cellArea = MV2.masked_where(MV2.equal(var[0,0,:],fdata1(varName)._FillValue), cellArea)
  cellFrac = MV2.masked_where(MV2.equal(var[0,0,:],fdata1(varName)._FillValue), cellFrac)
  soilFrac = MV2.masked_where(MV2.equal(var[0,0,:],fdata1(varName)._FillValue), soilFrac)
  moduleDic = getWebsiteVariablesDic()
  try:
    module = moduleDic[varName]
  except:
    try:
      module = moduleDic[varName.lower()]
    except:
      return None
  if (var.getAxis(1).id == 'zfull_soil'):
    var = cdutil.YEAR(var).squeeze()
    sums = []
    avgs = []
    for i in range(0,len(cellDepth)):
      if (region == 'tropics'):
        cellArea = MV2.masked_where(MV2.logical_or(geoLat < -30., geoLat > 30.),cellArea)
        cellFrac = MV2.masked_where(MV2.logical_or(geoLat < -30., geoLat > 30.),cellFrac)
        soilFrac = MV2.masked_where(MV2.logical_or(geoLat < -30., geoLat > 30.),soilFrac)
        varSlice = MV2.masked_where(MV2.logical_or(geoLat < -30., geoLat > 30.),var[i,:,:])
      elif (region == 'nh'):
        cellArea = MV2.masked_where(MV2.less_equal(geoLat,30.),cellArea)
        cellFrac = MV2.masked_where(MV2.less_equal(geoLat,30.),cellFrac)
        soiLFrac = MV2.masked_where(MV2.less_equal(geoLat,30.),soilFrac)
        varSlice = MV2.masked_where(MV2.less_equal(geoLat,30.),var[i,:,:])
      elif (region == 'sh'):
        cellArea = MV2.masked_where(MV2.greater_equal(geoLat,-30.),cellArea)
        cellFrac = MV2.masked_where(MV2.greater_equal(geoLat,-30.),cellFrac)
        soilFrac = MV2.masked_where(MV2.greater_equal(geoLat,-30.),soilFrac)
        varSlice = MV2.masked_where(MV2.greater_equal(geoLat,-30.),var[i,:,:])
      elif (region == 'global'):
        cellArea = cellArea
        cellFrac = cellFrac
        soilFrac = soilFrac
        varSlice = var[i,:,:]
      if ('m3' in fdata1(varName).units):
        varSum = MV2.array(varSlice*cellArea*cellFrac*cellDepth[i]).sum()
        varAvg = varSum/(cellArea*cellFrac*cellDepth[i]).sum()
      else:
        varSum = MV2.array(varSlice*cellArea*cellFrac).sum()
        varAvg = varSum/(cellArea*cellFrac).sum()
      sums.append(varSum)
      avgs.append(varAvg)
      return numpy.sum(sums), numpy.average(avgs)
  elif (var.getAxis(1).id == 'band'):
    var = cdutil.YEAR(var).squeeze()
    for i in range(0,1):
      if (region == 'tropics'):
        cellArea = MV2.masked_where(MV2.logical_or(geoLat < -30., geoLat > 30.),cellArea)
        cellFrac = MV2.masked_where(MV2.logical_or(geoLat < -30., geoLat > 30.),cellFrac)
        soilFrac = MV2.masked_where(MV2.logical_or(geoLat < -30., geoLat > 30.),soilFrac)
        var[i,:,:] = MV2.masked_where(MV2.logical_or(geoLat < -30., geoLat > 30.),var[i,:,:])
      elif (region == 'nh'):
        cellArea = MV2.masked_where(MV2.less_equal(geoLat,30.),cellArea)
        cellFrac = MV2.masked_where(MV2.less_equal(geoLat,30.),cellFrac)
        soilFrac = MV2.masked_where(MV2.less_equal(geoLat,30.),soilFrac)
        var[i,:,:] = MV2.masked_where(MV2.less_equal(geoLat,30.),var[i,:,:])
      elif (region == 'sh'):
        cellArea = MV2.masked_where(MV2.greater_equal(geoLat,-30.),cellArea)
        cellFrac = MV2.masked_where(MV2.greater_equal(geoLat,-30.),cellFrac)
        soilFrac = MV2.masked_where(MV2.greater_equal(geoLat,-30.),soilFrac)
        var[i,:,:] = MV2.masked_where(MV2.greater_equal(geoLat,-30.),var[i,:,:])
      elif (region == 'global'):
        cellArea = cellArea
        cellFrac = cellFrac
        soilFrac = soilFrac
        var[i,:,:] = var[i,:,:]
    if (module != 'vegn'):
      topSum = MV2.array(var[0,:,:]*cellArea*cellFrac).sum()
      topAvg = topSum/(cellArea*cellFrac).sum()
      botSum = MV2.array(var[1,:,:]*cellArea*cellFrac).sum()
      botAvg = botSum/(cellArea*cellFrac).sum()
    elif (module == 'vegn'):
      topSum = MV2.array(var[0,:,:]*cellArea*cellFrac*soilFrac).sum()
      topAvg = topSum/(cellArea*cellFrac*soilFrac).sum()
      botSum = MV2.array(var[1,:,:]*cellArea*cellFrac*soilFrac).sum()
      botAvg = botSum/(cellarea*cellFrac*soilFrac).sum()
    return topSum, topAvg, botSum, botAvg
  else:
    return None
  
varDict = fdata1.variables
globalMeanDic={}
tropicsMeanDic={}
nhMeanDic={}
shMeanDic={}
for varName in varDict:
  if (len(varDict[varName].shape) == 3):
    globalMeanDic[varName] = areaMean(varName,cellArea,cellFrac,soilFrac,geoLat,geoLon,region='global')
    if globalMeanDic[varName] != None:
      dbEntry("${localRoot}/db/.globalAveLand.db",varName,globalMeanDic[varName][0], globalMeanDic[varName][1],fYear)
    globalMeanDic[varName] = areaMean(varName,cellArea,cellFrac,soilFrac,geoLat,geoLon,region='tropics')
    if globalMeanDic[varName] != None:
      dbEntry("${localRoot}/db/.tropicsAveLand.db",varName,globalMeanDic[varName][0], globalMeanDic[varName][1],fYear)
    globalMeanDic[varName] = areaMean(varName,cellArea,cellFrac,soilFrac,geoLat,geoLon,region='nh')
    if globalMeanDic[varName] != None:
      dbEntry("${localRoot}/db/.nhAveLand.db",varName,globalMeanDic[varName][0], globalMeanDic[varName][1],fYear)
    globalMeanDic[varName] = areaMean(varName,cellArea,cellFrac,soilFrac,geoLat,geoLon,region='sh')
    if globalMeanDic[varName] != None:
      dbEntry("${localRoot}/db/.shAveLand.db",varName,globalMeanDic[varName][0], globalMeanDic[varName][1],fYear)
  if (len(varDict[varName].shape) == 4):
    globalMeanDic[varName] = areaMean3D(varName,cellArea,cellFrac,cellDepth,soilFrac,geoLat,geoLon,region='global')
    if globalMeanDic[varName] != None:
      if len(globalMeanDic[varName]) == 2:
        dbEntry("${localRoot}/db/.globalAveLand.db",varName, globalMeanDic[varName][0], globalMeanDic[varName][1], fYear)
      elif len(globalMeanDic[varName]) == 4:
        dbEntry("${localRoot}/db/.globalAveLand.db","%s0" % varName, globalMeanDic[varName][0], globalMeanDic[varName][1], fYear)
        dbEntry("${localRoot}/db/.globalAveLand.db","%s1" % varName, globalMeanDic[varName][2], globalMeanDic[varName][3], fYear)
    globalMeanDic[varName] = areaMean3D(varName,cellArea,cellFrac,cellDepth,soilFrac,geoLat,geoLon,region='tropics')
    if globalMeanDic[varName] != None:
      if len(globalMeanDic[varName]) == 2:
        dbEntry("${localRoot}/db/.tropicsAveLand.db",varName, globalMeanDic[varName][0], globalMeanDic[varName][1], fYear)
      elif len(globalMeanDic[varName]) == 4:
        dbEntry("${localRoot}/db/.tropicsAveLand.db", "%s0" % varName, globalMeanDic[varName][0], globalMeanDic[varName][1], fYear)
        dbEntry("${localRoot}/db/.tropicsAveLand.db", "%s1" % varName, globalMeanDic[varName][2], globalMeanDic[varName][3], fYear)
    globalMeanDic[varName] = areaMean3D(varName,cellArea,cellFrac,cellDepth,soilFrac,geoLat,geoLon,region='nh')
    if globalMeanDic[varName] != None:
      if len(globalMeanDic[varName]) == 2:
        dbEntry("${localRoot}/db/.nhAveLand.db",varName, globalMeanDic[varName][0], globalMeanDic[varName][1], fYear)
      elif len(globalMeanDic[varName]) == 4:
        dbEntry("${localRoot}/db/.nhAveLand.db", "%s0" % varName, globalMeanDic[varName][0], globalMeanDic[varName][1], fYear)
        dbEntry("${localRoot}/db/.nhAveLand.db", "%s1" % varName, globalMeanDic[varName][2], globalMeanDic[varName][3], fYear)
    globalMeanDic[varName] = areaMean3D(varName,cellArea,cellFrac,cellDepth,soilFrac,geoLat,geoLon,region='sh')
    if globalMeanDic[varName] != None:
      if len(globalMeanDic[varName]) == 2:
        dbEntry("${localRoot}/db/.shAveLand.db",varName,globalMeanDic[varName][0], globalMeanDic[varName][1],fYear)
      elif len(globalMeanDic[varName]) == 4:
        dbEntry("${localRoot}/db/.shAveLand.db", "%s0" % varName, globalMeanDic[varName][0], globalMeanDic[varName][1], fYear)
        dbEntry("${localRoot}/db/.shAveLand.db", "%s1" % varName, globalMeanDic[varName][2], globalMeanDic[varName][3], fYear)
EOF
cat > global_ocean_ave.py <<EOF
import sqlite3, cdms2, cdutil, MV2, numpy, cdtime
import sys
# Set current year
fYear = "${oname}"
# Test to see if sqlite databse exits, if not, then create it
dbFile = "${localRoot}/db/.globalAveOcean.db"
# Read in ocean scalar annual file
fdata = cdms2.open(fYear + '.ocean_scalar_annual.nc')
def extractScalarField(varName):
  return fdata(varName)[0]
ignoreList = ['time_bounds', 'time_bnds', 'average_T2', 'average_T1', 'average_DT']
varDict = fdata.variables
varDict = list(set(varDict) - set(ignoreList))
globalMeanDic={}
for varName in varDict:
  conn = sqlite3.connect("${localRoot}/db/.globalAveOcean.db")
  c = conn.cursor()
  globalMeanDic[varName] = extractScalarField(varName)
  sql = 'create table if not exists ' + varName + ' (year integer primary key, value float)'
  sqlres = c.execute(sql)
  sql = 'insert or replace into ' + varName + ' values(' + fYear[:4] + ',' + str(globalMeanDic[varName]) + ')'
  sqlres = c.execute(sql)
  conn.commit()
  c.close()
  conn.close()
EOF
cat > amoc.py <<EOF
import cdms2, netCDF4, tarfile, numpy, sqlite3
from scipy.io import netcdf
fYear = "${oname}"
#-- Attempt to read vmo and/or vh
try:
  vmoFile = fYear+'.ocean_annual.nc'
  vmo = netCDF4.Dataset(vmoFile).variables['vmo'][0]
  vmo = vmo.filled(0)*1e-9
  zl  = netCDF4.Dataset(vmoFile).variables['zl'][:]
  yq_vmo  = netCDF4.Dataset(vmoFile).variables['yq'][:]
  doVmo = True
except: doVmo = False
try:
  vhFile = fYear+'.ocean_annual_z.nc'
  if 'vmo' in netCDF4.Dataset(vhFile).variables:
    vh  = netCDF4.Dataset(vhFile).variables['vmo'][0]
    vh  = vh.filled(0)*1e-9
    zt  = netCDF4.Dataset(vhFile).variables['z_l'][:]
  else:
    vh  = netCDF4.Dataset(vhFile).variables['vh'][0]
    vh  = vh.filled(0)*1e-9
    zt  = netCDF4.Dataset(vhFile).variables['zt'][:]
  yq_vh  = netCDF4.Dataset(vhFile).variables['yq'][:]
  doVh = True
except: doVh = False
#-- Get grid info from gridspec file
gsFile = "${gridspec}"
TF = tarfile.open(gsFile,'r')
member = [m for m in TF.getmembers() if 'ocean_hgrid' in m.name][0]
nc = netcdf.netcdf_file(TF.extractfile(member),'r')
x = nc.variables['x'][1::2,1::2]
y = nc.variables['y'][1::2,1::2]
member = [m for m in TF.getmembers() if 'topog' in m.name][0]
nc = netcdf.netcdf_file(TF.extractfile(member),'r')
depth = nc.variables['depth'][:]
def ice9it(i, j, depth, minD=0.):
  wetMask = 0*depth      
  (nj,ni) = wetMask.shape
  stack = set()
  stack.add( (j,i) )
  while stack:
    (j,i) = stack.pop()
    if wetMask[j,i] or depth[j,i] <= minD: continue
    wetMask[j,i] = 1
  
    if i>0: stack.add( (j,i-1) )
    else: stack.add( (j,ni-1) ) # Periodic beyond i=0
    if i<ni-1: stack.add( (j,i+1) )
    else: stack.add( (j,0) ) # Periodic beyond i=ni-1
    
    if j>0: stack.add((j-1,i))
        
    if j<nj-1: stack.add( (j+1,i) )
    else: stack.add( (j,ni-1-i) ) # Tri-polar fold beyond j=nj-1
  return wetMask
    
def ice9(x, y, depth, xy0):
  ji = nearestJI(x, y, xy0)
  return ice9it(ji[1], ji[0], depth)
def nearestJI(x, y, (x0, y0)):
  return numpy.unravel_index( ((x-x0)**2 + (y-y0)**2).argmin() , x.shape)
def southOf(x, y, xy0, xy1):
  x0 = xy0[0]; y0 = xy0[1]; x1 = xy1[0]; y1 = xy1[1]
  dx = x1 - x0; dy = y1 - y0
  Y = (x-x0)*dy - (y-y0)*dx
  Y[Y>=0] = 1; Y[Y<=0] = 0
  return Y
#print 'Generating global wet mask ...',
wet = ice9(x, y, depth, (0,-35)) # All ocean points seeded from South Atlantic
#print 'done.'
code = 0*wet
#print 'Finding Cape of Good Hope ...',
tmp = 1 - wet; tmp[x<-30] = 0
tmp = ice9(x, y, tmp, (20,-30.))
yCGH = (tmp*y).min()
#print 'done.', yCGH
#print 'Finding Melbourne ...',
tmp = 1 - wet; tmp[x>-180] = 0
tmp = ice9(x, y, tmp, (-220,-25.))
yMel = (tmp*y).min()
#print 'done.', yMel
#print 'Processing Persian Gulf ...'
tmp = wet*( 1-southOf(x, y, (55.,23.), (56.5,27.)) )
tmp = ice9(x, y, tmp, (53.,25.))
code[tmp>0] = 11
wet = wet - tmp # Removed named points
#print 'Processing Red Sea ...'
tmp = wet*( 1-southOf(x, y, (40.,11.), (45.,13.)) )
tmp = ice9(x, y, tmp, (40.,18.))
code[tmp>0] = 10
wet = wet - tmp # Removed named points
#print 'Processing Black Sea ...'
tmp = wet*( 1-southOf(x, y, (26.,42.), (32.,40.)) )
tmp = ice9(x, y, tmp, (32.,43.))
code[tmp>0] = 7
wet = wet - tmp # Removed named points
#print 'Processing Mediterranean ...'
tmp = wet*( southOf(x, y, (-5.7,35.5), (-5.7,36.5)) )
tmp = ice9(x, y, tmp, (4.,38.))
code[tmp>0] = 6
wet = wet - tmp # Removed named points
#print 'Processing Baltic ...'
tmp = wet*( southOf(x, y, (8.6,56.), (8.6,60.)) )
tmp = ice9(x, y, tmp, (10.,58.))
code[tmp>0] = 9
wet = wet - tmp # Removed named points
#print 'Processing Hudson Bay ...'
tmp = wet*( 
           ( 1-(1-southOf(x, y, (-95.,66.), (-83.5,67.5)))
              *(1-southOf(x, y, (-83.5,67.5), (-84.,71.))) 
           )*( 1-southOf(x, y, (-70.,58.), (-70.,65.)) ) )
tmp = ice9(x, y, tmp, (-85.,60.))
code[tmp>0] = 8
wet = wet - tmp # Removed named points
#print 'Processing Arctic ...'
tmp = wet*( 
          (1-southOf(x, y, (-171.,66.), (-166.,65.5))) * (1-southOf(x, y, (-64.,66.4), (-50.,68.5))) # Lab Sea
     +    southOf(x, y, (-50.,0.), (-50.,90.)) * (1- southOf(x, y, (0.,65.5), (360.,65.5))  ) # Denmark Strait
     +    southOf(x, y, (-18.,0.), (-18.,65.)) * (1- southOf(x, y, (0.,64.9), (360.,64.9))  ) # Iceland-Sweden
     +    southOf(x, y, (20.,0.), (20.,90.)) # Barents Sea
     +    (1-southOf(x, y, (-280.,55.), (-200.,65.)))
          )
tmp = ice9(x, y, tmp, (0.,85.))
code[tmp>0] = 4
wet = wet - tmp # Removed named points
#print 'Processing Pacific ...'
tmp = wet*( (1-southOf(x, y, (0.,yMel), (360.,yMel)))
           -southOf(x, y, (-257,1), (-257,0))*southOf(x, y, (0,3), (1,3))
           -southOf(x, y, (-254.25,1), (-254.25,0))*southOf(x, y, (0,-5), (1,-5)) 
           -southOf(x, y, (-243.7,1), (-243.7,0))*southOf(x, y, (0,-8.4), (1,-8.4)) 
           -southOf(x, y, (-234.5,1), (-234.5,0))*southOf(x, y, (0,-8.9), (1,-8.9)) 
          )
tmp = ice9(x, y, tmp, (-150.,0.))
code[tmp>0] = 3
wet = wet - tmp # Removed named points
#print 'Processing Atlantic ...'
tmp = wet*(1-southOf(x, y, (0.,yCGH), (360.,yCGH)))
tmp = ice9(x, y, tmp, (-20.,0.))
code[tmp>0] = 2
wet = wet - tmp # Removed named points
#print 'Processing Indian ...'
tmp = wet*(1-southOf(x, y, (0.,yCGH), (360.,yCGH)))
tmp = ice9(x, y, tmp, (55.,0.))
code[tmp>0] = 5
wet = wet - tmp # Removed named points
#print 'Processing Southern Ocean ...'
tmp = ice9(x, y, wet, (0.,-55.))
code[tmp>0] = 1
wet = wet - tmp # Removed named points
code[wet>0] = -9
(j,i) = numpy.unravel_index( wet.argmax(), x.shape)
if j:
  print 'There are leftover points unassigned to a basin code'
  while j:
    print x[j,i],y[j,i],[j,i]
    wet[j,i]=0
    (j,i) = numpy.unravel_index( wet.argmax(), x.shape)
else: print 'All points assigned a basin code'
def MOCpsi(vh, vmsk=None):
  shape = list(vh.shape); shape[-3] += 1
  psi = numpy.zeros(shape[:-1])
  if len(shape)==3:
    for k in range(shape[-3]-1,0,-1):
      if vmsk==None: psi[k-1,:] = psi[k,:] - vh[k-1].sum(axis=-1)
      else: psi[k-1,:] = psi[k,:] - (vmsk*vh[k-1]).sum(axis=-1)
  else:
    for n in range(shape[0]):
      for k in range(shape[-3]-1,0,-1):
        if vmsk==None: psi[n,k-1,:] = psi[n,k,:] - vh[n,k-1].sum(axis=-1)
        else: psi[n,k-1,:] = psi[n,k,:] - (vmsk*vh[n,k-1]).sum(axis=-1)
  return psi
#-- Define atlantic/arctic mask
atlmask = numpy.where(numpy.logical_or(code==2,code==4),1.,0.)
varDict = {}
if doVmo == True:
  psi = MOCpsi(vmo,vmsk=atlmask)
  maxsfn = numpy.max(psi[numpy.logical_and(zl>500,zl<2500)][:,numpy.greater_equal(yq_vmo,20)])
  print('AMOC vmo = %s' % maxsfn)
  varDict['amoc_vmo'] = maxsfn
if doVh == True:
  psi = MOCpsi(vh,vmsk=atlmask)
  maxsfn = numpy.max(psi[numpy.logical_and(zt>500,zt<2500)][:,numpy.greater_equal(yq_vh,20)])
  print('AMOC vh = %s' % maxsfn)
  varDict['amoc_vh'] = maxsfn
for varName in varDict:
  conn = sqlite3.connect("${localRoot}/db/.globalAveOcean.db")
  c = conn.cursor()
  sql = 'create table if not exists ' + varName + ' (year integer primary key, value float)'
  sqlres = c.execute(sql)
  sql = 'insert or replace into ' + varName + ' values(' + fYear[:4] + ',' + str(varDict[varName]) + ')'
  sqlres = c.execute(sql)
  conn.commit()
  c.close()
  conn.close()
EOF
cat > global_COBALT_ave.py <<EOF
import sqlite3, cdms2, cdutil, MV2, numpy, cdtime
import sys
import glob
# Set current year
fYear = "${oname}"
# Test to see if sqlite databse exits, if not, then create it
dbFile = "${localRoot}/db/.globalAveCOBALT.db"
#Read in gridSpec files
fgs = cdms2.open(fYear + '.ocean_static.nc')
cellArea = fgs('areacello')
geoLat   = fgs('geolat')
geoLon   = fgs('geolon')
def areaMean(varName,cellArea,geoLat,geoLon,region='global'):
  var = fdata(varName)
  var = cdutil.YEAR(var).squeeze()
  if (region == 'tropics'):
    var = MV2.masked_where(MV2.logical_or(geoLat < -30., geoLat > 30.),var)
    cellArea = MV2.masked_where(MV2.logical_or(geoLat < -30., geoLat > 30.),cellArea)
  elif (region == 'nh'):
    var  = MV2.masked_where(MV2.less_equal(geoLat,30.),var)
    cellArea  = MV2.masked_where(MV2.less_equal(geoLat,30.),cellArea)
  elif (region == 'sh'):
    var  = MV2.masked_where(MV2.greater_equal(geoLat,-30.),var)
    cellArea  = MV2.masked_where(MV2.greater_equal(geoLat,-30.),cellArea)
  elif (region == 'global'):
    var  = var
    cellArea = cellArea
  cellArea.mask[:] = var.mask[:]
  res = MV2.array(var*cellArea).sum()/cellArea.sum()
  return res, cellArea.sum()
#Get a list of all COBALT files
#cobaltFiles = glob.glob('*cobalt*')
#cobaltFiles = [x for x in cobaltFiles if 'day' not in x]
cobaltFiles = ['ocean_cobalt_sfc', 'ocean_cobalt_misc']
for cobaltFile in cobaltFiles:
  #Read in data nc files
  fdata = cdms2.open(fYear + '.' + cobaltFile + '.nc')
  varDict = fdata.variables
  globalMeanDic={}
  tropicsMeanDic={}
  nhMeanDic={}
  shMeanDic={}
  for varName in varDict:
    if (len(varDict[varName].shape) == 3):
      if (fdata(varName).getAxis(1).id == 'yh' and fdata(varName).getAxis(2).id == 'xh'):
        conn = sqlite3.connect("${localRoot}/db/.globalAveCOBALT.db")
        c = conn.cursor()
        globalMeanDic[varName], areaSum = areaMean(varName,cellArea,geoLat,geoLon,region='global')
        sql = 'create table if not exists ' + varName + ' (year integer primary key, value float)'
        sqlres = c.execute(sql)
        sql = 'insert or replace into ' + varName + ' values(' + fYear[:4] + ',' + str(globalMeanDic[varName]) + ')'
        try:
          sqlres = c.execute(sql)
          conn.commit()
        except: pass
        c.close()
        conn.close()
  fdata.close()
conn = sqlite3.connect("${localRoot}/db/.globalAveCOBALT.db")
c = conn.cursor()
sql = 'create table if not exists ' + 'area' + ' (year integer primary key, value float)'
sqlres = c.execute(sql)
sql = 'insert or replace into ' + 'area' + ' values(' + fYear[:4] + ',' + str(areaSum) + ')'
try:
  sqlres = c.execute(sql)
  conn.commit()
except: pass
c.close()
conn.close()
EOF
#-- Run the averager script
python global_atmos_ave.py
python global_atmos_aer_ave.py
python global_ocean_ave.py
python global_land_ave.py
python amoc.py
python global_COBALT_ave.py
#-- Copy the database back to its original location
foreach reg (global nh sh tropics)
  cp -f ${localRoot}/db/.${reg}AveAtmos.db ${localRoot}/db/${reg}AveAtmos.db
  cp -f ${localRoot}/db/.${reg}AveAtmosAer.db ${localRoot}/db/${reg}AveAtmosAer.db
  cp -f ${localRoot}/db/.${reg}AveOcean.db ${localRoot}/db/${reg}AveOcean.db
  cp -f ${localRoot}/db/.${reg}AveLand.db ${localRoot}/db/${reg}AveLand.db  
  cp -f ${localRoot}/db/.${reg}AveCOBALT.db ${localRoot}/db/${reg}AveCOBALT.db  
end
echo "  ---------- end refineDiag_data_stager.csh ----------  "
echo ""
echo ""
echo ""
exit

