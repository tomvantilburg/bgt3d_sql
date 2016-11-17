select plv8_startup();
do language plv8 'load_module("d3")';
do language plv8 'load_module("topojson")';
do language plv8 ' load_module("topojsonclient")';
do language plv8 ' load_module("simplify")';

CREATE SEQUENCE arcid START WITH 1;
CREATE SEQUENCE featid START WITH 1;
DROP TABLE IF EXISTS tmp.arcs;
CREATE TABLE tmp.arcs AS
WITH bounds AS (
	SELECT ST_MakeEnvelope(93660,464003,94765,464635,28992) as box
)
,entities AS (
	SELECT ogc_fid AS gid, type, geom
	FROM bgt.polygons, bounds b
	WHERE ST_Intersects(geom, box) --AND (ogc_fid = 1245832 OR ogc_fid = 1213681)
),
properties AS (
	SELECT gid, type
	FROM entities
),
geometry AS (
	SELECT gid, ST_AsGeoJson(geom) geom
	FROM entities
),
features AS (
	SELECT '{"type": "Feature"}'::JSONB ||
		jsonb_set('{}'::JSONB,'{properties}',row_to_json(p)::JSONB) ||
		jsonb_set('{}'::JSONB,'{geometry}',geom::JSONB)
		AS feat
	FROM 
	properties p 
	INNER JOIN geometry g USING(gid)
),
topojson AS (
	SELECT 
	d3_totopojson(
		'{"type": "FeatureCollection"}'::JSONB || 
		jsonb_set(
			'{}'::JSONB,
			'{features}',
			jsonb_agg(feat))
		,1e9) AS topojson
	FROM features
)

SELECT 
	'arc'::text AS type, 
	nextval('arcid')-1 id,  --should be zero based index for arcs
	row_data::JSONB As data 
	FROM (SELECT jsonb_array_elements(topojson.topojson->'arcs') AS row_data FROM topojson) foo
UNION ALL
SELECT 
	'entity'::text AS type, 
	nextval('featid') id, 
	row_data::JSONB AS data 
	FROM topojson,
	LATERAL jsonb_array_elements(topojson.topojson->'objects'->'entities'->'geometries') AS row_data
UNION ALL
SELECT 
	'transform'::text AS type, 
	1 as id, 
	(topojson.topojson->'transform')::JSONB AS data 
	FROM topojson;

DROP SEQUENCE arcid;
DROP SEQUENCE featid;