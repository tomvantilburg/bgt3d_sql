DROP TABLE tmp.triangs;
CREATE TABLE tmp.triangs AS


WITH
triangles AS(
	SELECT 
	gid,
	geom,
	ST_MakePolygon(
		ST_ExteriorRing(
			(ST_Dump(ST_Triangulate2DZ(ST_Collect(geom)))).geom
		)
	) triang
	FROM tmp.tmp
	GROUP BY gid, geom
)

,assign_triags AS (
	SELECT 	a.gid, a.triang as geom
	FROM triangles a
	INNER JOIN tmp.tmp b
	ON ST_Contains(b.geom, a.triang)
	AND a.gid = b.gid
)


SELECT gid as id, 
	ST_Collect(p.geom) geom, 'topo' as type
FROM assign_triags p
GROUP BY gid;
---------------
DROP TABLE tmp.points;
CREATE TABLE tmp.points AS

WITH points AS
(
	SELECT gid,ST_DumpPoints(geom) pt
	FROM tmp.tmp
)
SELECT ST_Z((pt).geom) z, (pt).geom, gid
FROM points;


---------------
DROP TABLE IF EXISTS tmp.pointcloud;
CREATE TABLE tmp.pointcloud AS 

WITH bounds AS (
	SELECT ST_MakeEnvelope(93777,463792 , 93825,463825, 28992) geom
)
,points AS(
	SELECT Geometry(PC_Explode(PC_FilterEquals(pa,'classification',2))) geom
	FROM ahn3_pointcloud.vw_ahn3 a, bounds b
	WHERE ST_Contains(b.geom, Geometry(a.pa))
)
SELECT ST_Z(geom), geom FROM points;
----------------------
