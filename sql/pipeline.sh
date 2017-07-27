#!/bin/bash
echo 'Writing topojson'
psql -d research -U postgres -f write_as_topojsontable.sql
echo 'Adding terrain Z'
psql -d research -U postgres -f addZToarcs.sql
echo 'Writing back to geometry'
psql -d research -U postgres -f write_as_geomtable.sql