select plv8_startup();
do language plv8 'load_module("d3")';
do language plv8 'load_module("topojson")';
do language plv8 ' load_module("topojsonclient")';
do language plv8 ' load_module("simplify")';
DROP TABLE IF EXISTS tmp.tmp;
CREATE TABLE tmp.tmp AS

WITH arclist1 AS(
	SELECT id, jsonb_array_elements(data->'arcs') arcs
	FROM tmp.arcs
	WHERE type = 'entity' 
	AND (data->>'type' = 'Polygon')
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
)

SELECT 
gid,
ST_SetSrid(geom,28992) geom
FROM polygons;