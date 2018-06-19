# grass-lfp
GRASS GIS Shell Script for Creating the Longest Flow Path

This shell script is a GRASS GIS module that creates longest flow paths at multiple outlet points. The longest flow path modules in GRASS GIS ([r.lfp](https://grass.osgeo.org/grass72/manuals/addons/r.lfp.html) and [v.lfp](https://grass.osgeo.org/grass72/manuals/addons/v.lfp.html)) can handle only one longest flow path at a time.

I developed this module because the longest flow path tool in the ArcGIS ArcHydro toolbox was not able to process one of my study areas. It took forever to generate outputs in ArcGIS, so I needed a way to generate longest flow paths at multiple monitoring points (name for outlet points in ArcHydro) in GRASS GIS.

This shell script is deprecated by the new [r.lfp]((https://grass.osgeo.org/grass74/manuals/addons/r.lfp.html)) addon, which supports multiple outlets.

## How to import the flow direction raster from ArcGIS

In ArcGIS, export the flow direction raster to fdr.tif.

```
# import fdr.tif into a new raster map <fdr>
r.in.gdal input=fdr.tif output=fdr

# convert ArcGIS flow directions to GRASS GIS flow directions
r.mapcalc expression="drain=int(8-log(fdr,2))"
```

For more information about flow direction conversion, see [this article](https://idea.isnew.info/how-to-import-arcgis-flow-direction-into-grass-gis.html).

## How to import monitoring points from ArcGIS

In ArcGIS, export monitoroing points to mp.shp.

```
# import the monitoring points shapefile into a new vector map <mp>
v.in.ogr input=mp.shp output=mp

# drop unnecessary columns
v.db.dropcolumn map=mp columns=OBJECTID_1,OBJECTID_2,AREA,PERIMETER,AL_SITES_G,AL_SITES_1,OBJECTID,STATION_NO,SNAME,DA_MI2,SGRF1_ID,REALTIME,NONET_REAL,FIRSTYEAR,YEARSREC,HCDN,HBM,DISTRICT,STATE,AGENCY,NASQAN2,BENCHMRK,NAWQALIP,ONREACH,MATCHID,COMPACT,BORDER,NWS_SITE,NRCS_SITE,HUC6_MVPSI,SENTINEL_S,FURNISHED,HUC6,USGS_SITE,WHO,PROPOSED,SITE_TYPE,QW_SITE,ACTIVE_K,SITE_STATU,SCORE,ID,POLYGONID,SCALE,ANGLE,HydroID,GageID,HydroCode,FType,Name,RiverID

# rename the JunctionID column to id
v.db.renamecolumn map=mp column=JunctionID,id
```

## How to create longest flow paths

```
# create a new vector map <lfp> with longest flow paths for all outlet points
lfp.sh outlets=mp idattr=id drainage=drain output=lfp
```
