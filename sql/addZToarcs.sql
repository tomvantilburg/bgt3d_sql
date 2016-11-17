WITH 
arcs AS (
	SELECT a.id,
	a.data as arc 
	,d3_topoBBox(a.data, b.data) geom
	,d3_arcToGeom(a.data, b.data) geom2
	FROM tmp.arcs a,tmp.arcs b 
	WHERE a.type = 'arc' AND b.type = 'transform'
	AND a.data Is Not Null
	--LIMIT 1000
)
,arcwithpoints AS (
	SELECT a.id, a.arc, PC_Union(PC_FilterEquals(pa,'classification',2)) pa FROM 
	arcs a 
	LEFT JOIN ahn3_pointcloud.vw_ahn3 b
	ON ST_Intersects(ST_SetSrid(a.geom2,28992), Geometry(b.pa))
	GROUP BY a.id, a.arc
	
)
UPDATE tmp.arcs a SET data= patch_to_arc(PC_FilterEquals(b.pa,'classification',2),b.arc) 
--SELECT COUNT(*)
FROM 
--tmp.arcs a, 
arcwithpoints b 
WHERE a.id = b.id AND a.type = 'arc';
