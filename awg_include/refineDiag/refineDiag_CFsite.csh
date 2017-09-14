#!/bin/csh -fx
#
# Background:
# For CMIP6, CFMIP requests instantaneous high-frequency output at 121 specific sites.
# The output for all sites should be saved in a single file, with a "site" dimension
# that indicates the site number. See http://clipc-services.ceda.ac.uk/dreq/u/MIPtable::CFsubhr.html
# The FMS diag manager can save out site-data, but each site is saved to a different diagfile.
#
# Inputs:
# 121 history files of this pattern: atmos_station_XXX*, where XXX corresponds to the 121 sites
#
# Output:
# One file, atmos_station.nc, that contains the output from the 121 sites in CMIP-compliant format.
#
# Description:
# 1. The degenerate FMS lat/lon dimensions (e.g. grid_yt_sub01, grid_xt_sub01) are removed using ncwa.
# 2. The 121 files from step 1 are combined using ncecat, which creates a new "site" dimension
#    that represents the 121 files.
# 3. The record dimension is returned to "time" from "site" using ncpdq.
#
# Usage:
# Designed to be source'd by the refineDiag step in frepp.
# Required frepp variables: $oname, $refineDiagDir

setenv NC_BLKSZ 64K
alias ncwa "ncwa --overwrite --header_pad 16384"
alias ncecat "ncecat --overwrite --header_pad 16384"
alias ncpdq "ncpdq --overwrite --header_pad 16384"

# Verify there are 121 site files
set files = (`ls *.atmos_station_???.tile?.nc`)
if ($#files != 121) then
    echo "ERROR: Expected 121 site files but found only $#files"
    #exit 1
endif

# Remove degenerate lat/lon dimensions - doing this after combining now
#foreach file ($files)
#    ncwa -a grid_xt_sub01,grid_yt_sub01 $file $file.tmp
#    if ($status) then
#        echo "ERROR: ncwa error"
#        exit 1
#    endif
#    mv $file.tmp $file
#end

# Combine files into a single file with dimension "site"
set output = "$oname.atmos_station.nc"
ncecat -u site $files $output
if ($status) then
    echo "ERROR: ncecat error"
    exit 1
endif

# Remove degenerate lat/lon dimensions
ncwa -a grid_xt_sub01,grid_yt_sub01 $output $output.tmp
if ($status) then
    echo "ERROR: ncwa error"
    exit 1
endif
mv $output.tmp $output

# Make the "time" dimension the record dimension again
ncpdq -a time,site $output $output.tmp
if ($status) then
    echo "ERROR: ncpdq error"
    exit 1
endif
mv $output.tmp $refineDiagDir/$output

echo "Done"
exit 0
