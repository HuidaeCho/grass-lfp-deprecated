#!/bin/sh

############################################################################
#
# MODULE:       lfp.sh
# AUTHOR(S):    Huidae Cho
#
# PURPOSE:      Creates longest flow paths at multiple outlets
#
# COPYRIGHT:    (C) 2017, 2019 by Huidae Cho <https://idea.isnew.info>
#
#               This program is free software under the GNU General Public
#               License (>=v2). Read the file COPYING that comes with this
#               script for details.
#
#############################################################################

#%module
#% description: Creates longest flow paths at multiple outlets
#% keywords: hydrology
#%end
#%option G_OPT_V_INPUT
#% key: outlets
#% type: string
#% description: Name of input outlet points map
#% guisection: Input data
#% required: yes
#%end
#%option G_OPT_DB_COLUMN
#% key: idattr
#% type: string
#% description: Name of the attribute column with outlet IDs
#% guisection: Input data
#% required: yes
#%end
#%option G_OPT_R_INPUT
#% key: drainage
#% type: string
#% description: Name of input drainage direction raster map
#% guisection: Input data
#% required: yes
#%end
#%option G_OPT_V_OUTPUT
#% key: output
#% type: string
#% description: Name for output longest flow path vector map
#%end

# check whether running GRASS
if [ -z $GISRC ]; then
	echo "Sorry, you are not running GRASS " 1>&2
	exit 1
fi

# parse arguments
if [ "$1" != "@ARGS_PARSED@" ]; then
	exec g.parser "$0" "$@"
fi

outlets=$GIS_OPT_OUTLETS
idattr=$GIS_OPT_IDATTR
drainage=$GIS_OPT_DRAINAGE
output=$GIS_OPT_OUTPUT

if [ "$GRASS_OVERWRITE" = "1" ]; then
	overwrite=--o
else
	overwrite=
fi

# settings
res=`g.region -g | sed -n '/^nsres=/{s/nsres=//; p}'`
buf=`perl -e "print $res/2"`
diagres=`echo $res | awk '{printf "%f", sqrt(2)*$0+0.1}'`

# make a copy of outlet points
g.copy vect=$outlets,lfp_tmp_out $overwrite

# convert outlet points to raster
v.to.rast input=lfp_tmp_out output=lfp_tmp_out use=attr attr=$idattr $overwrite

# calculate downstream distance
r.stream.distance -o stream_rast=lfp_tmp_out direc=$drainage method=downstream distance=lfp_tmp_flds $overwrite
# calculate upstream distance
r.stream.distance -o stream_rast=lfp_tmp_out direc=$drainage method=upstream distance=lfp_tmp_flus $overwrite
# calculate the longest flow path (lfp)
r.mapcalc exp="lfp_tmp_fldsus=lfp_tmp_flds+lfp_tmp_flus" $overwrite

# upload x, y, lfp distance to the outlet vector map
v.db.addcolumn map=lfp_tmp_out column="x double precision, y double precision, fldsus double precision"
v.to.db map=lfp_tmp_out option=coor column=x,y
v.what.rast map=lfp_tmp_out raster=lfp_tmp_fldsus column=fldsus

# create an intermediate lfp vector map
v.edit map=lfp_tmp tool=create $overwrite
v.db.addtable map=lfp_tmp columns="id int"

# for each outlet
for i in `v.db.select -c map=lfp_tmp_out column=$idattr,x,y,fldsus`; do
	id=`echo $i | awk -F'|' '{print $1}'`
	x=`echo $i | awk -F'|' '{print $2}'`
	y=`echo $i | awk -F'|' '{print $3}'`
	fldsus=`echo $i | awk -F'|' '{print $4}'`
	echo "$id: $fldsus @ $x,$y"

	# find lfp for this outlet
	r.mapcalc exp="lfp_tmp_$id=if(lfp_tmp_fldsus>=$fldsus-0.0005&lfp_tmp_fldsus<=$fldsus+0.0005,$id,null())" $overwrite

	# convert lfp to vector
	r.thin input=lfp_tmp_$id output=lfp_tmp2_$id $overwrite
	r.to.vect input=lfp_tmp2_$id output=lfp_tmp_$id column=id type=line $overwrite

	# clean lfp
	# r.to.vect sometimes produces continous line segments that are not
	# connected; merge them first
	v.edit map=lfp_tmp_$id tool=merge where=""

	# remove dangles
	v.edit map=lfp_tmp_$id tool=delete query=dangle threshold=0,0,-$diagres
	v.edit map=lfp_tmp_$id tool=merge where=""

	# remove the shorter path from closed loops; these are not dangles
	v.edit map=lfp_tmp_$id tool=delete query=length threshold=0,0,-$diagres
	v.edit map=lfp_tmp_$id tool=merge where=""
	v.db.dropcolumn map=lfp_tmp_$id columns=label

	# delete extra lines
	v.edit -r map=lfp_tmp_$id tool=delete coords=$x,$y thresh=$res

	# leave the first category only
	cats=`v.category input=lfp_tmp_$id option=print | sed 's#/#,#g'`
	firstcat=`echo $cats | sed 's/,.*//'`
	othercats=`echo $cats | sed -n '/,/{s/^[^,]*,//; p}'`
	db.execute "delete from lfp_tmp_$id where cat<>$firstcat"
	if [ "$othercats" != "" ]; then
		line=`v.edit map=lfp_tmp_$id tool=select cats=$firstcat`
		v.edit map=lfp_tmp_$id tool=catdel id=$line cats=$othercats
	fi

	# patch all lfps into one vector map
	v.patch -ae --o input=lfp_tmp_$id output=lfp_tmp
done

# snap outlet points to lfps
v.edit map=lfp_tmp_out tool=move move=0,0,0 where="" snap=node thresh=$res bgmap=lfp_tmp

# buffer outlet points
v.buffer input=lfp_tmp_out output=lfp_tmp_out_buf distance=$buf $overwrite

# extract lfp end nodes
v.to.points input=lfp_tmp use=node output=lfp_tmp_end $overwrite
v.edit map=lfp_tmp_end layer=2 tool=delete where="along=0"

# find lfps that need to be flipped: outlet points should be close to lfp end
# nodes
g.remove -f type=vector name=lfp_tmp_end_flip
v.select ainput=lfp_tmp_end binput=lfp_tmp_out_buf output=lfp_tmp_end_flip operator=disjoint $overwrite

# flip lfps so that lfps point to outlets
eval `g.findfile element=vector file=lfp_tmp_end_flip`
if [ "$file" ]; then
	for cat in `v.db.select -c map=lfp_tmp_end_flip column=cat`; do
		v.edit map=lfp_tmp tool=flip cat=$cat
	done
fi

# find lfp start nodes
v.to.points input=lfp_tmp output=lfp_tmp_start use=node $overwrite
v.edit map=lfp_tmp_start layer=2 tool=delete where="along>0"

# find lfp end nodes
v.to.points input=lfp_tmp output=lfp_tmp_end use=node $overwrite
v.edit map=lfp_tmp_end layer=2 tool=delete where="along=0"

# create lines connecting continuous lfps
v.distance from=lfp_tmp_end to=lfp_tmp_start output=lfp_tmp2 dmax=$diagres $overwrite

# patch original lfp and connecting lines
v.patch input=lfp_tmp,lfp_tmp2 output=lfp_tmp3 $overwrite

# build seamless lfp polylines
v.build.polylines input=lfp_tmp3 output=lfp_tmp4 cats=first $overwrite

# create an empty lfp vector map
v.edit map=$output tool=create $overwrite
v.db.addtable map=$output columns="id int"

# for each outlet
for cat in `v.category input=lfp_tmp_out option=print`; do
	# extract a single outlet point
	id=`v.db.select -c map=lfp_tmp_out column=$idattr where="cat=$cat"`
	v.extract input=lfp_tmp_out cat=$cat output=lfp_tmp_out_tmp $overwrite

	# select lfp polyline for this outlet
	g.remove -f type=vector name=lfp_tmp5
	v.select ainput=lfp_tmp4 binput=lfp_tmp_out_tmp output=lfp_tmp5 $overwrite
	v.db.addtable map=lfp_tmp5 columns="id int"

	# add outlet ID to the lfp polyline
	v.db.update map=lfp_tmp5 column=id value=$id

	# get the end node coordinates of the lfp polyline
	endcoor=`v.to.db -p map=lfp_tmp5 option=end separator=, | awk -F, '{if(NR==2) printf "%s,%s", $2, $3}'`

	# get the outlet coordinates
	coor=`v.to.db -p map=lfp_tmp_out_tmp option=coor separator=, | awk -F, '{if(NR==2) printf "%s,%s", $2, $3}'`

	# if these two points are different, split the lfp polyline and delete
	# the downstream segment
	if [ $coor != $endcoor ]; then
		v.edit map=lfp_tmp5 tool=break coor=$coor
		v.edit map=lfp_tmp5 tool=delete coor=$endcoor
	fi

	# patch all these lfps into the final vector map
	v.patch -ae --o input=lfp_tmp5 output=$output
done
