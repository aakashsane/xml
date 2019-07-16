#!/usr/bin/env python
from __future__ import print_function

import netCDF4 as nc
import numpy as np
import argparse
import sys
import datetime

def addHistory(dst, text):
    if 'history' in dst.ncattrs() :
        history = '\n'+dst.history
    else:
        history = ''
    dst.history = text+history

parser = argparse.ArgumentParser(
    formatter_class=argparse.RawDescriptionHelpFormatter,
    description='''
This script fills the variable mrsofc with missing values over the ocean. It relies on the
presence of the variable attribute ocean_fillvalue, which is normally set to 0 by the
model. If this attribute is not present, the file is unchanged; if it is, then the values
where land fraction (sftlf) is zero are masked out, and the attributed is removed to avoid
repeated application of the procedure.
''')
parser.add_argument('-v','--verbose', action='count',
    help='increase verbosity')
parser.add_argument('--variable', default='mrsofc',
    help='variable to fill with missing values over the ocean, in case it is different than the default "mrsofc"')
parser.add_argument('-l','--sftlf','--land-fracion', required=True,
    help='location of the land fraction file')
parser.add_argument('input', metavar='file', nargs='+',
    help='input/output file')
args=parser.parse_args()

if args.verbose>0 : print('reading land fraction (sftlf) from "%s"'%(args.sftlf))
src0 = nc.Dataset(args.sftlf,'r')
sftlf = src0.variables['sftlf']

for f in args.input:
    if args.verbose>0: print('processing file "{}"...'.format(f))
    src=nc.Dataset(f,'a')
    if args.variable not in src.variables:
        if args.verbose>0: print('    variable "{}" is not in the file, skipping.'.format(args.variable))
        src.close()
        continue # do nothing if the variable is not in the file
    var = src.variables[args.variable]
    if 'ocean_fillvalue' in var.ncattrs():
        if args.verbose>0: print('    filling variable "{}" with missing values where "{}" is zero'.format(args.variable,args.sftlf))
        var[:] = np.ma.array(data=var[:],mask=(sftlf[:]==0))
        addHistory(src,datetime.datetime.now().isoformat(' ')+' : '+' '.join(sys.argv))
        var.delncattr('ocean_fillvalue')
    else:
        if args.verbose>0: print('    variable "{}" appears to be filled with missing values over the ocean, no need to do it again.'.format(args.variable))
    src.close()
src0.close()
