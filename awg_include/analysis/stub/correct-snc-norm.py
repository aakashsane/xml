#!/usr/bin/env python
from __future__ import print_function

import netCDF4 as nc
import argparse
import sys
import datetime

def addHistory(dst, text):
    if 'history' in dst.ncattrs() :
        history = '\n'+dst.history
    else:
        history = ''
    dst.history = text+history

parser = argparse.ArgumentParser(description='''
This script re-normalizes snc (Snow area percentage) in CMIP6 output. Data Request
says it must be a fraction of grid cell area, but the model saves it as a fraction
of land area; therefore the model output needs to be multiplied by land fraction to get
the desired normalization.
''')
parser.add_argument('-v','--verbose', help='increase verbosity', action='count')
parser.add_argument('-l','--sftlf','--land-fracion', required=True, help='''
location of the land fraction file
''')
parser.add_argument('input', metavar='files', nargs='+', help='input/output files')
args=parser.parse_args()

if args.verbose>0  : print('reading land fraction (sftlf) from "%s"'%(args.sftlf))
src0 = nc.Dataset(args.sftlf,'r')
sftlf = src0.variables['sftlf']

for f in args.input:
    if args.verbose>0: print('processing file "%s"...'%(f))
    src=nc.Dataset(f,'a')
    var = src.variables['snc']
    if 'snc_renormalized' in src.ncattrs():
        if args.verbose>0: print('    variable "snc" has already been renormalized, no need to do it again.')
    else:
        if args.verbose>0: print('    multiplying variable "snc" by "sftlf" to renormalize per grid cell area')
        addHistory(src,datetime.datetime.now().isoformat(' ')+' : '+' '.join(sys.argv))
        var[:] = var[:]*sftlf[:]*0.01 # factor of 0.01 converts sftlf from % to fractions of 1
        src.snc_renormalized = 'per-grid-cell-area'
    src.close()

