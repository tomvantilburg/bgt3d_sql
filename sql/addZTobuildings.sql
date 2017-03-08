select plv8_startup();
do language plv8 'load_module("d3")';
do language plv8 'load_module("topojson")';
do language plv8 ' load_module("topojsonclient")';
do language plv8 ' load_module("simplify")';
DROP SEQUENCE IF EXISTS s;
CREATE SEQUENCE s;

WITH arclist1 AS(
	SELECT id, jsonb_array_elements(data->'arcs') arcs
	FROM tmp.arcs
	WHERE type = 'entity' 
	AND (data->>'type' = 'Polygon')
	AND (data->'properties'->>'type' = 'Polygon')
)
,arclist2 AS (
	SELECT id, row_number() OVER (PARTITION BY id) AS n,jsonb_array_elements_text(arcs) arcid
	FROM arclist1
),
arclist3 AS (
	SELECT id, n, 
	  CASE 
		WHEN arcid::int < 0 THEN abs(arcid::int) -1
		ELSE arcid::int
	  END as arcid,
	  CASE 
		WHEN arcid::int < 0 THEN true
		ELSE false
	  END as reverse
	  FROM arclist2
)

,outersegments AS (
	SELECT a.id, a.n, 
	CASE reverse
	  WHEN false THEN
	    ST_GeomFromGeoJSON('{"type":"LineString","coordinates":' || d3_transform(b.data,c.data)::text || '}')
	  ELSE 
	    ST_Reverse(ST_GeomFromGeoJSON('{"type":"LineString","coordinates":' || d3_transform(b.data,c.data)::text || '}'))
	END AS geom
	FROM arclist3 a
	INNER JOIN tmp.arcs b ON (a.arcid::int = b.id AND b.type = 'arc')
	INNER JOIN tmp.arcs c ON (c.type = 'transform')
	WHERE n = 1
	ORDER BY a.id, a.n
),
outerrings AS (
	SELECT id, n, ST_MakeLine(geom) geom
	FROM outersegments
	GROUP BY id, n
)

,innersegments AS (
	SELECT a.id, a.n, 
	CASE reverse
	  WHEN false THEN 
	    ST_GeomFromGeoJSON('{"type":"LineString","coordinates":' || d3_transform(b.data,c.data)::text || '}')
	  ELSE 
	    ST_Reverse(ST_GeomFromGeoJSON('{"type":"LineString","coordinates":' || d3_transform(b.data,c.data)::text || '}'))
	END AS geom
	FROM arclist3 a
	INNER JOIN tmp.arcs b ON (a.arcid::int = b.id AND b.type = 'arc')
	INNER JOIN tmp.arcs c ON (c.type = 'transform')
	WHERE n > 1
	ORDER BY a.id, a.n
)
,innerrings AS (
	SELECT id, n, ST_MakeLine(geom) geom
	FROM innersegments
	GROUP BY id, n
)
,polygons AS (
	SELECT a.id AS gid, 
		CASE
		WHEN (ST_Accum(b.geom))[1] Is Not Null
			THEN ST_MakePolygon(a.geom, ST_Accum(b.geom))
		ELSE 
			ST_MakePolygon(a.geom)
		END as geom
	 FROM outerrings a
	LEFT JOIN innerrings b ON (a.id = b.id)
	GROUP BY a.id, a.geom
),
polypoints AS (
	SELECT gid, geom, PC_Explode(PC_FilterEquals(pa,'classification',6)) pt
	FROM polygons a
	INNER JOIN ahn3_pointcloud.vw_ahn3 b ON ST_Intersects(a.geom, Geometry(b.pa))
)
,polyz AS (
	SELECT gid, avg(PC_Get(pt,'z') z
	FROM polypoints
	WHERE ST_Intersects(ST_Buffer(geom,-0.2),Geometry(pt))
)


WITH 
arcids AS (
	SELECT DISTINCT
	gid,
	CASE
		WHEN id::int < 0 THEN ~ id::int
		ELSE id::int
	END
	AS id	
	FROM (
		SELECT 
		id as gid, jsonb_array_elements_text(jsonb_array_elements(data->'arcs')) id
		FROM tmp.arcs 
		WHERE type = 'entity'
		AND data->>'type' = 'Polygon'
		AND data->'properties'->>'type' = 'pand'
	) as foo
)
,arcs AS (
	SELECT a.gid,a.id,
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
		SELECT PC_FilterEquals(pa,'classification',6) pa 
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
