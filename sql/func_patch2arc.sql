-- Function: public.patch_to_arc(pcpatch, jsonb)

DROP FUNCTION public.patch_to_arc(pcpatch, jsonb);

CREATE OR REPLACE FUNCTION public.patch_to_arc(
    inpatch pcpatch,
    ingeom jsonb)
  RETURNS jsonb AS
$BODY$
DECLARE
inpatch pcpatch := inpatch;
ingeom JSONB := ingeom;
output JSONB;

BEGIN

CREATE SEQUENCE s;
WITH 
papoints AS (
	SELECT PC_Explode(inpatch) pt
),
--
pointsarray AS (
	SELECT nextval('s') i, jsonb_array_elements(ingeom) point
),
--Dump the linestring to points (keeping the originating ring path)
pointsgeom AS (
	SELECT i,ST_SetSrid(ST_MakePoint(
			(point->>0)::float,(point->>1)::float,0::float
		),28992) geom
	FROM pointsarray
),
--Find the 10 closest points to the vertex
closestpoints AS (
	SELECT i,a.geom, 
	unnest(ARRAY( 
		SELECT PC_Get(pt,'z') FROM papoints b
		ORDER BY a.geom <-> Geometry(b.pt)
		LIMIT 1
	)) AS z FROM pointsgeom AS a
)
--Use the avg of the closest points as z
,emptyz AS ( 
	SELECT 
	i,geom, max(z) z
	FROM closestpoints 
	GROUP BY i,geom
)
-- assign z-value for every boundary point
,filledz AS ( 
	SELECT 
	i,ST_Translate(St_Force3D(emptyz.geom), 0,0,z) geom
	FROM emptyz
	ORDER BY i
)
--Create tbe polygons back from the rings
,arcz AS (
	SELECT array_to_json(array_agg(ARRAY[
		ST_X(geom), 
		ST_Y(geom), 
		ST_Z(geom)]))::JSONB arc
	FROM filledz a
)

SELECT arcz.arc INTO output FROM arcz;
DROP SEQUENCE s;
--RAISE NOTICE 'ArcOut: %',output;
RETURN output;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION public.patch_to_arc(pcpatch, jsonb, jsonb)
  OWNER TO geodan;
