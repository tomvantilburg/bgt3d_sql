-- Function: public.patch_to_arc(pcpatch, jsonb)

DROP FUNCTION IF EXISTS public.patch_to_point(pcpatch, geometry);

CREATE OR REPLACE FUNCTION public.patch_to_point(
    inpatch pcpatch,
    ingeom geometry)
  RETURNS geometry AS
$BODY$
DECLARE
inpatch pcpatch := inpatch;
ingeom geometry := ingeom;
output geometry;

BEGIN


WITH 
papoints AS (
	SELECT PC_Explode(inpatch) pt
),
--Find the 10 closest points to the vertex
closestpoints AS (
	SELECT ingeom geom, 
	unnest(ARRAY( 
		SELECT PC_Get(pt,'z') FROM papoints b
		ORDER BY ingeom <-> Geometry(b.pt)
		LIMIT 1
	)) AS z
)
--Use the avg of the closest points as z
,emptyz AS ( 
	SELECT 
	geom, max(z) z
	FROM closestpoints 
	GROUP BY geom
)
-- assign z-value for every boundary point
,filledz AS ( 
	SELECT 
	ST_Translate(St_Force3D(emptyz.geom), 0,0,z) geom
	FROM emptyz
)

SELECT filledz.geom INTO output FROM filledz;

--RAISE NOTICE 'ArcOut: %',output;
RETURN output;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION public.patch_to_point(pcpatch, geometry)
  OWNER TO geodan;
