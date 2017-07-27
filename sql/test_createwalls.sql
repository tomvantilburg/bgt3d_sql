DROP SEQUENCE IF EXISTS s;
CREATE SEQUENCE s;
DROP TABLE tmp.test;
CREATE TABLE tmp.test AS
WITH bounds AS (
	--SELECT ST_MakeEnvelope(93805,463800, 93850,463850,28992) as box --small burgt leiden
	SELECT ST_MakeEnvelope(93625,463670, 93956,463904,28992) as box
)
,pand as (
	SELECT ogc_fid AS gid, 'pand'::text as type, wkb_geometry as geom,
	ST_Buffer(wkb_geometry,-0.01) as scaledpand
	FROM bgt.pand_2dactueelbestaand a, bounds b
	WHERE ST_Intersects(wkb_geometry, b.box)
)
,outsidewalls AS (
	SELECT ogc_fid,nextval('s') as id, a.type, 
	a.geom, 
	(ST_Dump(ST_Intersection(a.geom, b.geom))).geom AS wall,
	b.scaledpand as pandgeom
	FROM bgt.polygons a, pand b
	WHERE ST_Intersects(a.geom, b.geom)
)
,dumps As (
	SELECT id, pandgeom, ST_DumpPoints(wall) AS pt FROM outsidewalls
)
 ,segments AS (
	SELECT id, pandgeom,
	ST_MakeLine(
		lag((pt).geom, 1, NULL) OVER (PARTITION BY id ORDER BY id, pandgeom, (pt).path), 
		(pt).geom
	) AS wall
	FROM  dumps
)
--    SELECT * FROM segments WHERE geom IS NOT NULL;

SELECT 
	ST_MakePolygon(
	ST_MakeLine(ARRAY[
		ST_ClosestPoint(pandgeom,ST_EndPoint(wall)),
		ST_ClosestPoint(pandgeom,ST_StartPoint(wall)) ,
		wall,
		ST_ClosestPoint(pandgeom,ST_EndPoint(wall))
	])
	) 
	wall

FROM segments
WHERE wall IS NOT NULL;
DROP SEQUENCE IF EXISTS s;