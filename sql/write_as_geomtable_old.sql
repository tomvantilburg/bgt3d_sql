DROP TABLE IF EXISTS  tmp.tmp;
CREATE TABLE tmp.tmp AS

WITH arclist AS (
	SELECT
		data,
		(data->'properties'->>'gid')::int AS id,
		--data->'arcs'
		jsonb_array_elements_text(data->'arcs'->0)::text::int arcid
	FROM tmp.arcs 
	WHERE type = 'entity' 
	AND (data->>'type' = 'Polygon')
	
	--AND (data->'properties'->>'gid')::text::int  = 4254389
) 

,geojson AS (
	SELECT
	
	d3_ToGeoJson(
		a.data, 
		jsonb_agg(
			row_to_json(b)
		)
		,t.data
	) geojson
	FROM arclist a 
	JOIN tmp.arcs b ON (
		b.type = 'arc' AND (
			(a.arcid = b.id AND a.arcid >= 0)
			OR (abs(a.arcid)-1 = b.id AND a.arcid < 0)
		)
	)
	JOIN tmp.arcs t ON (t.type = 'transform')
	GROUP BY a.data, t.data             

)

SELECT 

(geojson->'properties'->>'gid')::text::int as gid,
ST_SetSrid(ST_GeomFromGeoJSON((geojson->'geometry')::text),28992) geom
FROM geojson;