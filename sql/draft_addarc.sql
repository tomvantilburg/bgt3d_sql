select plv8_startup();
do language plv8 'load_module("d3")';
do language plv8 'load_module("topojson")';
do language plv8 ' load_module("topojsonclient")';
do language plv8 ' load_module("simplify")';

DROP SEQUENCE IF EXISTS arcid;
DROP SEQUENCE IF EXISTS featid;
DROP SEQUENCE IF EXISTS neighbourid;
CREATE SEQUENCE arcid START WITH 1;
CREATE SEQUENCE featid START WITH 1;
CREATE SEQUENCE neighbourid START WITH 0 MINVALUE 0;


WITH feats AS (
	SELECT 
	'{"type": "Feature", "properties": {"type":"water"}}'::JSONB ||
	jsonb_set('{}'::JSONB,'{geometry}',ST_AsGeoJson(ST_MakeEnvelope(0,0,100,100))::JSONB)
	AS feat
	UNION ALL
	SELECT 
	'{"type": "Feature", "properties": {"type":"land"}}'::JSONB ||
	
	jsonb_set('{}'::JSONB,'{geometry}',ST_AsGeoJson(ST_MakeEnvelope(0,100,100,200))::JSONB)
	AS feat
),
topojson AS (
	SELECT d3_totopojson(
		'{"type": "FeatureCollection"}'::JSONB || 
		jsonb_set(
		'{}'::JSONB,
			'{features}',
			jsonb_agg(feat))
	,0) AS topojson
	FROM feats
)
SELECT topojson->'objects' FROM topojson
arcs AS (
	SELECT 
	'arc'::text AS type, 
	nextval('arcid')-1 id,  --should be zero based index for arcs
	row_data::JSONB As data 
	FROM (SELECT jsonb_array_elements(topojson.topojson->'arcs') AS row_data FROM topojson) foo
	
	--LIMIT 1000
),
entities AS (
	SELECT 
	'entity'::text AS type, 
	nextval('featid') id,
	row_data::JSONB AS data 
	FROM topojson,
	LATERAL jsonb_array_elements(topojson.topojson->'objects'->'entities'->'geometries') AS row_data
),
neighbours AS (
	SELECT
	nextval('neighbourid') id,
	jsonb_array_elements(d3_toponeighbours(topojson->'objects'->'entities'->'geometries')) neighbours 
	FROM topojson
)

,water AS (
	SELECT * 
	FROM entities a,
	INNER JOIN arcs b ON (a.
	WHERE data->'properties'->>'type'='land'
)

SELECT * FROM water