# -*- coding: iso-8859-1 -*-
import os,sys,fnmatch
import numpy as np
from scipy import integrate
from netCDF4 import Dataset, MFDataset
from netcdftime import utime
from datetime import datetime
from distutils.version import LooseVersion

def middif1(y,x,naxis):
    # sanity check
    x=np.reshape(x,(x.size,),order='F')
    if np.ma.is_masked(x):
	print("x contains invalid number")
	return
    if (x.size != y.shape[naxis]):
	print("size mismatch, cannot calculate differential! ")
	print(x.size)
	print(y.shape)
	print(y.shape[naxis])
	return
	
    def middifue(yy,dx):
	dyydxx=np.empty_like(yy)
	for ii in range(0,dx.size+1):
	    if (ii==0):
		dx1=dx[0]
		dx2=dx[1]
		dyydxx[ii]=-dx1**2*yy[ii+2]+(dx1+dx2)**2*yy[ii+1]-(dx2**2+2*dx1*dx2)*yy[ii]
	    elif (ii==dx.size):
		dx1=dx[ii-2]
		dx2=dx[ii-1]
		dyydxx[ii]=(dx1**2+2*dx1*dx2)*yy[ii]-(dx1+dx2)**2*yy[ii-1]+dx2**2*yy[ii-2]
	    else:
		dx1=dx[ii-1]
		dx2=dx[ii]
		dyydxx[ii]=dx1**2*yy[ii+1]+(dx2**2-dx1**2)*yy[ii]-dx2**2*yy[ii-1]
	    dyydxx[ii]=dyydxx[ii]/dx1/dx2/(dx1+dx2)
	    del(dx1,dx2)
	return dyydxx
	
    nx=x.size
    ns=y.size/nx
    yrr=np.rollaxis(y,naxis)
    yr=np.reshape(yrr,(nx,ns),order='F')
    
    dydx=np.ma.asarray(yr)
    
    dx=np.ediff1d(x) 
    for ii in range(0,ns):
	ind_list=[]
	nchunck=0
	if np.ma.is_masked(yr[:,ii]):
	    vaind=np.where(~yr[:,ii].mask)[0]
	    if len(vaind)==0:
		continue
	    vadif=vaind[1:]-vaind[:-1]
	    if (np.sum((vadif-1)**2)==0):
		ind_list.append(vaind)
		nchunck=1
	    else:
		jstart=0
		for jj in range(0,len(vadif)):
		    if (vadif[jj]>1):
			if (jj-jstart>=2):
			    ind_list.append(vaind[jstart:jj+1])
			    nchunck=nchunck+1
			jstart=jj+1  
	else:
	    ind_list.append(np.arange(0,nx))
	    nchunck=1
	
	for kk in range(0,nchunck):
	    ind=ind_list[kk]
	    if (np.max(dx)==np.min(dx)):
		if LooseVersion(np.version.version)>"1.9.1":
		    dydx[ind,ii]=np.gradient(yr[ind,ii],dx[0],edge_order=2)
		else:
		    dydx[ind,ii]=np.gradient(yr[ind,ii],dx[0])
		    dydx[ind[0],ii]=(-3.*yr[ind[0],ii]+4.*yr[ind[0]+1,ii]-yr[ind[0]+2,ii])/2/dx[0]
		    dydx[ind[-1],ii]=-(-3.*yr[ind[-1],ii]+4.*yr[ind[-1]-1,ii]-yr[ind[-1]-2,ii])/2/dx[0]
	    else:
		dydx[ind,ii]=middifue(yr[ind,ii],dx[ind[:-1]])
    dydx=np.reshape(dydx,yrr.shape,order='F')
    dydx=np.rollaxis(dydx,0,naxis+1)
	
    return dydx
###########################
def maeddy(x1,x2,naxis):
    nx=x1.shape[naxis]
    if ((np.ma.is_masked(x1)) or (np.ma.is_masked(x2))):
	if ((np.ma.is_masked(x1)) and (np.ma.is_masked(x2))):
	    maskx=~((~x1.mask)*(~x2.mask))
	elif (np.ma.is_masked(x1)):
	    maskx=x1.mask
	else:
	    maskx=x2.mask
	    
	eddy=np.ma.mean(x1*x2,axis=naxis)-np.ma.mean(x1,axis=naxis)*np.ma.mean(x2,axis=naxis)
	eddy=np.ma.masked_where(np.sum(maskx,axis=naxis)>nx/2,eddy)	
    else:
	eddy=np.mean(x1*x2,axis=naxis)-np.mean(x1,axis=naxis)*np.mean(x2,axis=naxis)
    
    return eddy
############################    
def mamean(x,naxis):
    nx=x.shape[naxis]
    if np.ma.is_masked(x):
	xm=np.ma.mean(x,axis=naxis)
	xm=np.ma.masked_where(np.sum(x.mask,axis=naxis)>nx/2,xm)
    else:
	xm=np.mean(x,axis=naxis)
    return xm
    
###########################
def v_int(v,plev):
    nt=v.shape[0]
    nlev=v.shape[1]
    nlat=v.shape[2]
    plev_ext=np.empty((nlev+1,))
    if plev[1]>plev[0]:
	plev_ext[0]=0.
	plev_ext[1:]=plev
	vr=v
	flipflag=0
    else:
	plev_ext[0]=0.
	plev_ext[1:]=plev[::-1]
	flipflag=1
	vr=v[:,::-1,:]
    dlev=np.reshape(plev_ext[1:]-plev_ext[:-1],(1,nlev,1),'F')
    vmid=np.concatenate((np.reshape(vr[:,0,:]/2.,(nt,1,nlat),'F'),(vr[:,1:,:]+vr[:,:-1,:])/2.),axis=1)
    vintr=np.cumsum(vmid*dlev,axis=1)
    if flipflag:
	vint=vintr[:,::-1,:]
    else:
	vint=vintr
    if np.ma.is_masked(v):
	vint=np.ma.array(vint,mask=v.mask)
    return vint

###########################
# parameters
inputdir = str(sys.argv[1])
outdir = str(sys.argv[2])
Y1 = int(sys.argv[3]) # the first year for the calculation
Y2 = int(sys.argv[4]) # the last year for the calculation

# check input directory
fileu=fnmatch.filter(os.listdir(inputdir),'*ua.nc')
filev=fnmatch.filter(os.listdir(inputdir),'*va.nc')
filet=fnmatch.filter(os.listdir(inputdir),'*ta.nc')
filew=fnmatch.filter(os.listdir(inputdir),'*wap.nc')

# coordinates
if len(fileu)==1:
    ncref=Dataset(inputdir+fileu[0],'r')
else:
    ncref=MFDataset(inputdir+'*ua.nc')
lat=ncref.variables['lat'][:]
plev=ncref.variables['plev26'][:]
lon=ncref.variables['lon'][:]
time=ncref.variables['time'][:]
timeunits=getattr(ncref.variables['time'],'units')
tcalendar=getattr(ncref.variables['time'],'calendar')

nlat=len(lat)
nlev=len(plev)
nlon=len(lon)

cdftime=utime(timeunits,calendar=tcalendar)
dtime=cdftime.num2date(time)
Ystart=dtime[0].year
Yend=dtime[-2].year

# define some constants
R_earth=6.37123e6
P0=1.01325e5
Rgas=287.058
Cp=1004.64
Grav=9.80665
H0=7.e3

phi=lat*np.pi/180.
factor=(P0/plev)**(Rgas/Cp)
fcor=2.*7.29212e-5*np.sin(phi)
coslat=np.cos(phi)
pleva=np.reshape(plev,(1,nlev,1),'F')

# variable list
varlist=[]
varlist.append({'var':'epfy','units':'m3 s-2',
'long name':'Northward Component of the Eliassen-Palm flux',
'standard name':'northward_eliassen_palm_flux_in_air',
'comment':'Transformed Eulerian Mean Diagnostics Meridional component Fy of Eliassen-Palm (EP) flux (Fy, Fz) derived from 6hr instantaneous fields using the formular (A13) in Gerber and Manzini (2016).'})
varlist.append({'var':'epfz','units':'m3 s-2',
'long name':'Eastward Component of the Eliassen-Palm flux',
'standard name':'upward_eliassen_palm_flux_in_air',
'comment':'Transformed Eulerian Mean Diagnostics Meridional component Fz of the Eliassen-Palm (EP) flux (Fy, Fz) derived from 6hr instantaneous fields using the formular (A14) in Gerber and Manzini (2016).'})
varlist.append({'var':'vtem','units':'m s-1',
'long name':'Transformed Eulerian mean northward wind',
'standard name':'northward_transformed_eulerian_mean_air_velocity', 
'comment':'Transformed Eulerian Mean Diagnostics v*, meridional component of the residual meridional circulation (v*, w*) derived from 6 hr instantaneous data fields using the formular (A6) in Gerber and Manzini (2016).'})
varlist.append({'var':'wtem','units':'m s-1',
'long name':'Transformed Eulerian mean upward wind',
'standard name': 'upward_transformed_eulerian_mean_air_velocity', 
'comment': 'Transformed Eulerian Mean Diagnostics w*, meridional component of the residual meridional circulation (v*, w*) derived from 6 hr instantaneous data fields using the formular (A16) in Gerber and Manzini (2016). Scale height: 7 km',})
varlist.append({'var':'psitem','units':'kg s-1',
'long name':'Transformed Eulerian mean mass stream function',
"standard name": "meridional_streamfunction_transformed_eulerian_mean", 
"comment": "Residual mass streamfunction, computed from vstar and integrated from the top of the atmosphere (on the native model grid) using formular (A8) in Gerber and Manzini (2016)."})
varlist.append({'var':'utendepfd','units':'m s-2',
'long name':'Tendency of eastward wind due to Eliassen-Palm flux divergence',
"standard name": "tendency_of_eastward_wind_due_to_eliassen_palm_flux_divergence", 
"comment": "Tendency of the zonal mean zonal wind due to the divergence of the Eliassen-Palm flux using formular (A15) in Gerber and Manzini (2016)."})
varlist.append({'var':'utendvtem','units':'m s-2',
'long name':'Tendency of eastward wind due to TEM northward wind advection and the Coriolis term',
'standard name': 'tendency_of_eastward_wind_due_to_advection_by_the_northward_transformed_eulerian_mean_air_velocity',
'comment':'Tendency of zonally averaged eastward wind, by the residual upward wind advection using formular (A9) in Gerber and Manzini (2016)'})
varlist.append({'var':'utendwtem','units':'m s-2',
'long name':'Tendency of astward wind due to TEM upward wind advection',
'standard name': 'tendency_of_eastward_wind_due_to_advection_by_the_upward_transformed_eulerian_mean_air_velocity',
'comment':'Tendency of zonally averaged eastward wind, by the residual northward wind advection using formular (A10) in Gerber and Manzini (2016).'})

freqname={'daily':'day','monthly':'month'}

# generate output ncfiles
os.mkdir(outdir+'monthly/')
os.mkdir(outdir+'daily/')
for outfreq in ('monthly','daily'):
    for varitem in varlist:
        if outfreq == 'monthly':
	    ncoutname=outdir+outfreq+'/atmos_plev26.'+"%04u"%Y1+'01-'+"%04u"%Y2+'12.'+varitem['var']+'.nc'
	    ncout=Dataset(ncoutname,'w',format='NETCDF3_CLASSIC')
            ncout.setncattr('filename','atmos_plev26.'+"%04u"%Y1+'01-'+"%04u"%Y2+'12.'+varitem['var']+'.nc')
            #continue
        else:
            ncoutname=outdir+outfreq+'/atmos_plev26.'+"%04u"%Y1+'0101-'+"%04u"%Y2+'1231.'+varitem['var']+'.nc'
            ncout=Dataset(ncoutname,'w',format='NETCDF3_CLASSIC')
            ncout.setncattr('filename','atmos_plev26.'+"%04u"%Y1+'0101-'+"%04u"%Y2+'1231.'+varitem['var']+'.nc')
            #continue
        #ncout=Dataset(ncoutname,'w',format='NETCDF3_CLASSIC')
	ncout.createDimension('time',None)
	ncout.createDimension('lat',nlat)
	ncout.createDimension('plev26',nlev)
	ncout.createDimension('bnds',2)
	#ncout.setncattr('filename','atmos_plev26.'+"%04u"%Y1+'-'+"%04u"%Y2+'.'+varitem['var']+'.nc')
	ncout.setncattr('title',getattr(ncref,'title'))
	ncout.setncattr('grid_type',getattr(ncref,'grid_type'))
	data={}
	data[varitem['var']]=ncout.createVariable(varitem['var'],ncref.variables['ua'].dtype,('time','plev26','lat'))
	data[varitem['var']].setncattr('units',varitem['units'])
	data[varitem['var']].setncattr('long_name',varitem['long name'])
	data[varitem['var']].setncattr('standard_name',varitem['standard name'])
	data[varitem['var']].setncattr('comment',varitem['comment'])
	data[varitem['var']].setncattr('cell_methods','longitude: mean time: mean')
	data[varitem['var']].setncattr('frequency',freqname[outfreq])
	data[varitem['var']].setncattr('dimensions','latitude plev26 time')
	data[varitem['var']].setncattr('modeling_realm','atmos')
	data[varitem['var']].setncattr('out_name',varitem['var'])
	data[varitem['var']].setncattr('_FillValue',ncref.variables['ua']._FillValue)
	data[varitem['var']].setncattr('missing_value',ncref.variables['ua']._FillValue)
	
	for corvar in ('lat','lat_bnds','plev26','time'):
	    data[corvar]=ncout.createVariable(corvar,ncref.variables[corvar].dtype,ncref.variables[corvar].dimensions)
	    for ncattr in ncref.variables[corvar].ncattrs():
		data[corvar].setncattr(ncattr,getattr(ncref.variables[corvar],ncattr))
	    if (corvar != 'time'):
		ncout.variables[corvar][:]=ncref.variables[corvar][:]
	data['plev26'].setncattr('comment','subset of plev39 grid of pressure levels that are at and below 3 hPa')
	data['time'].setncattr('bounds','time_bnds')
	data['time_bnds']=ncout.createVariable('time_bnds',ncref.variables['time'].dtype,('time','bnds'))
	data['time_bnds'].setncattr('long_name','time axis boundaries')
	data['time_bnds'].setncattr('units',timeunits)
	data['time_bnds'].setncattr('calendar',tcalendar)
        data['time_bnds'].setncattr('_FillValue',1.e+20)
        data['time_bnds'].setncattr('missing_value',1.e+20)
	del(data)
	ncout.close()

ncref.close()

# loop to read data
if len(fileu)==1:
    ncu=Dataset(inputdir+fileu[0],'r')
    ncv=Dataset(inputdir+filev[0],'r')
    nct=Dataset(inputdir+filet[0],'r')
    ncw=Dataset(inputdir+filew[0],'r')
else:
    ncu=MFDataset(inputdir+'*ua.nc')
    ncv=MFDataset(inputdir+'*va.nc')
    nct=MFDataset(inputdir+'*ta.nc')
    ncw=MFDataset(inputdir+'*wap.nc')
for iyear in np.arange(Y1,Y2+1):
    print(iyear)  
    
    for imonth in range(0,12):
	nstart=int(cdftime.date2num(datetime(iyear,imonth+1,1))-cdftime.date2num(datetime(Ystart,1,1)))
	if imonth==11:
	    nend=int(cdftime.date2num(datetime(iyear+1,1,1))-cdftime.date2num(datetime(Ystart,1,1)))
	else:
	    nend=int(cdftime.date2num(datetime(iyear,imonth+2,1))-cdftime.date2num(datetime(Ystart,1,1)))
	nstart2=nstart+int(cdftime.date2num(datetime(Ystart,1,1))-cdftime.date2num(datetime(Y1,1,1)))
	nend2=nend+int(cdftime.date2num(datetime(Ystart,1,1))-cdftime.date2num(datetime(Y1,1,1)))
	print(imonth)
	nday=nend-nstart
	UV=np.ma.empty((4*nday,nlev,nlat))
	VTH=np.ma.empty((4*nday,nlev,nlat))
	UO=np.ma.empty((4*nday,nlev,nlat))
	Uzm=np.ma.empty((4*nday,nlev,nlat))
	Vzm=np.ma.empty((4*nday,nlev,nlat))
	Ozm=np.ma.empty((4*nday,nlev,nlat))
	Thzm=np.ma.empty((4*nday,nlev,nlat))
	timem=ncu.variables['time'][nstart*4:nend*4]
	for ilev in range(0,nlev):
	    u=ncu.variables['ua'][nstart*4:nend*4,ilev,:,:]
	    v=ncv.variables['va'][nstart*4:nend*4,ilev,:,:]
	    t=nct.variables['ta'][nstart*4:nend*4,ilev,:,:]
	    omega=ncw.variables['wap'][nstart*4:nend*4,ilev,:,:]
	    
	    th=t*factor[ilev]
	    
	    UV[:,ilev,:]=maeddy(u,v,2)
	    VTH[:,ilev,:]=maeddy(v,th,2)
	    UO[:,ilev,:]=maeddy(u,omega,2)
	    Uzm[:,ilev,:]=mamean(u,2)
	    Vzm[:,ilev,:]=mamean(v,2)
	    Ozm[:,ilev,:]=mamean(omega,2)
	    Thzm[:,ilev,:]=mamean(th,2)
	    del(u,v,t,omega,th)
		
	U_plev=middif1(Uzm,plev,1)
	Th_plev=middif1(Thzm,plev,1)
	U_phi=middif1(Uzm*coslat,phi,2)/coslat/R_earth
	
	psi=VTH/Th_plev
	
	Fphi=(U_plev*psi-UV)*coslat*R_earth
	Fplev=((fcor-U_phi)*psi-UO)*coslat*R_earth
	
	DivF=middif1(Fphi*coslat,phi,2)/coslat/R_earth+middif1(Fplev,plev,1)
	
	vstar=Vzm-middif1(psi,plev,1)
	ostar=Ozm+middif1(psi*coslat,phi,2)/coslat/R_earth

	Psistar=(v_int(Vzm,plev)-psi)*coslat*2*np.pi*R_earth/Grav
	
	advv=vstar*(fcor-U_phi)
	advo=-ostar*U_plev
	
	epfy=Fphi*pleva/P0
	epfz=-H0*Fplev/P0
	utendepfd=DivF/coslat/R_earth
	wstar=-H0*ostar/pleva
	
	for varitem in varlist:
	    if varitem['var']=='wtem':
		x=wstar
	    elif varitem['var']=='vtem':
		x=vstar
	    elif varitem['var']=='epfy':
		x=epfy
	    elif varitem['var']=='epfz':
		x=epfz
	    elif varitem['var']=='psitem':
		x=Psistar
	    elif varitem['var']=='utendvtem':
		x=advv
	    elif varitem['var']=='utendwtem':
		x=advo
	    elif varitem['var']=='utendepfd':
		x=utendepfd
	    #print(x.fill_value)
	    ncout=Dataset(outdir+'monthly/atmos_plev26.'+"%04u"%Y1+'01-'+"%04u"%Y2+'12.'+varitem['var']+'.nc','r+')
	    ncout.variables['time'][(iyear-Y1)*12+imonth]=np.mean(timem)
	    ncout.variables['time_bnds'][(iyear-Y1)*12+imonth,0]=timem[0]-0.125
	    ncout.variables['time_bnds'][(iyear-Y1)*12+imonth,1]=timem[-1]+0.125
	    ncout.variables[varitem['var']][(iyear-Y1)*12+imonth,:,:]=np.mean(x,axis=0)
	    ncout.close()
	    ncout=Dataset(outdir+'daily/atmos_plev26.'+"%04u"%Y1+'0101-'+"%04u"%Y2+'1231.'+varitem['var']+'.nc','r+')
	    ncout.variables['time'][nstart2:nend2]=np.mean(np.reshape(timem,(4,nday),'F'),axis=0)
	    ncout.variables['time_bnds'][nstart2:nend2,0]=timem[0::4]-0.125
	    ncout.variables['time_bnds'][nstart2:nend2,1]=timem[3::4]+0.125
	    ncout.variables[varitem['var']][nstart2:nend2,:,:]=np.mean(np.reshape(x,(4,nday,nlev,nlat),'F'),axis=0)
	    ncout.close()

	del(UV,VTH,UO,Uzm,Vzm,Ozm,Thzm,U_plev,U_phi,Th_plev,psi,Fphi,Fplev,DivF,vstar,ostar,wstar,Psistar,advv,advo,epfy,epfz,utendepfd)
ncu.close()
ncv.close()
nct.close()
ncw.close()

