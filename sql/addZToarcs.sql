select plv8_startup();
do language plv8 'load_module("d3")';
do language plv8 'load_module("topojson")';
do language plv8 ' load_module("topojsonclient")';
do language plv8 ' load_module("simplify")';
DROP SEQUENCE IF EXISTS s;
CREATE SEQUENCE s;
WITH 
arcids AS (
	SELECT DISTINCT
	CASE
		WHEN id::int < 0 THEN ~ id::int
		ELSE id::int
	END
	AS id	
	FROM (
		SELECT 
		jsonb_array_elements_text(jsonb_array_elements(data->'arcs')) id
		FROM tmp.arcs 
		WHERE type = 'entity'
		AND data->>'type' = 'Polygon'
		AND data->'properties'->>'type' != 'pand'
	) as foo
)
,arcs AS (
	SELECT a.id,
	d3_transform(a.data, b.data) as arc 
	,d3_topoBBox(a.data, b.data) geom
	,d3_arcToGeom(a.data, b.data) geom2,
	b.data as transform
	FROM arcids, tmp.arcs a,tmp.arcs b 
	WHERE arcids.id = a.id AND a.type = 'arc' AND b.type = 'transform'
	AND a.data Is Not Null
	
	--LIMIT 1000
)
,pointsarray AS (
	SELECT nextval('s') i, id, jsonb_array_elements(arc) point
	FROM arcs
)
,
pointsgeom AS (
	SELECT i, id,ST_SetSrid(ST_MakePoint(
			(point->>0)::float,(point->>1)::float,0::float
		),28992) geom
	FROM pointsarray
),
closestpatch AS (
	SELECT i, id, geom, 
	unnest(ARRAY( 
		SELECT PC_FilterEquals(pa,'classification',2) pa 
		FROM ahn3_pointcloud.vw_ahn3 b
		ORDER BY a.geom <-> Geometry(b.pa)
		LIMIT 1 --5 patches should be enough to get a ground point
	)) pa
	FROM pointsgeom a
)
,closestpoints AS (
	SELECT i,id, 
	CASE 
	WHEN (PC_Numpoints(pa) > 0)
		THEN patch_to_point(pa, geom)
	ELSE 
		ST_Translate(St_Force3D(geom), 0,0,0)
	END as geom
	FROM closestpatch
	ORDER BY id, i

),
arcsz AS (
	SELECT id, array_to_json(array_agg(ARRAY[
		ST_X(geom), 
		ST_Y(geom), 
		ST_Z(geom)]))::JSONB arc
	FROM closestpoints
	GROUP BY id
)


UPDATE tmp.arcs a SET data= d3_untransform(b.arc,c.data) 
--SELECT COUNT(*)
FROM 
--tmp.arcs a, 
arcsz b,
tmp.arcs c 
WHERE a.id = b.id AND a.type = 'arc' AND c.type = 'transform';

DROP SEQUENCE s;
