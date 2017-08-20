# grass-lfp
GRASS GIS Shell Script for Creating the Longest Flow Path

This shell script is a GRASS GIS module that creates longest flow paths at multiple outlet points. The longest flow path modules in GRASS GIS ([r.lfp](https://grass.osgeo.org/grass72/manuals/addons/r.lfp.html) and [v.lfp](https://grass.osgeo.org/grass72/manuals/addons/v.lfp.html)) can handle only one longest flow path at a time.

I developed this module because the longest flow path tool in the ArcGIS ArcHydro toolbox was not able to process one of my study areas. It took forever to generate outputs in ArcGIS, so I needed a way to generate longest flow paths at multiple monitoring points (name for outlet points in ArcHydro) in GRASS GIS.

I plan to rewrite this shell script in Python and make it use a prefix to avoid name conflicts. Then, I will commit that Python module to the GRASS GIS repository.
