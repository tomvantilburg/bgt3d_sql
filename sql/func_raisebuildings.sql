DROP FUNCTION  IF EXISTS d3_raisebuildings(JSONB, TEXT);
CREATE FUNCTION d3_raisebuildings(collection JSONB, objecttype TEXT)
RETURNS JSONB
immutable language plv8
as $$
	/* Example topojson
	var collection =
	{
	"type": "Topology",
	"arcs": [
		[[0, 100,0], [100, 100,0]], 
		[[100, 100,0], [100, 0,0], [0, 0,0], [0, 100,0]], 
		[[0, 100,0], [0, 200,0], [100, 200,0], [100, 100,0]]
		], 
	"bbox": [0, 0, 100, 200], "type": "Topology", 
	"objects": {
		"entities": {
			"type": "GeometryCollection", 
			"geometries": [
				{"arcs": [[0, 1]], "type": "Polygon", "properties": {"type": "water"}}, 
				{"arcs": [[2, -1]], "type": "Polygon", "properties": {"type": "land"}}]
	}}}
	*/
	//plv8.elog(NOTICE,JSON.stringify(collection));
	//var neighours = topojson.neighbors(collection.objects.entities.geometries);
	var features = topojson.feature(collection,collection.objects.entities).features;
	var geoms = features.filter(d=>d.properties.type == objecttype).map(d=>d.geometry);
	//Comment: hoping that zarray keeps the same order as geometry input

	var zarray = plv8.execute(`
			WITH polygons AS (										
				SELECT ST_SetSrid(ST_GeomFromGeoJSON(jsonb_array_elements($1)::text),28992) geom                                              
			)                                                                                   
			,polypoints AS (                                                                    
				SELECT geom, PC_Explode(PC_FilterEquals(pa,'classification',6)) pt            
				FROM polygons a                                                                  
				INNER JOIN ahn3_pointcloud.vw_ahn3 b ON ST_Intersects(a.geom, Geometry(b.pa))   
			),polyz AS (                                                                        
				SELECT geom,avg(PC_Get(pt,'z')) z                                                  
				FROM polypoints                                                                 
				WHERE ST_Intersects(geom,Geometry(pt)) 
				AND ST_Intersects(ST_Buffer(geom,-0.2),Geometry(pt))
				GROUP BY geom 
			)                                                                                   
			SELECT z FROM polyz;
		`,[geoms]);
	plv8.elog(NOTICE,JSON.stringify(zarray));
	//1. duplicate roof arcs where not touching void or neighbour roof
	var liftme = collection.objects.entities.geometries.filter(d=>d.properties.type == objecttype);
	liftme.forEach((d,i)=>{
		var newarcs = d.arcs.map(ring=>{
			return ring.map(arc=>{
				var srcarc;
				if (arc < 0) {srcarc = ~arc}
				else {srcarc = arc}
				//Copy arc to end of arcs array
				var newarc = collection.arcs[srcarc].map(x=>[x[0],x[1],zarray[i].z]);
				collection.arcs.push(newarc);
				var newid = collection.arcs.length -1;
				if (arc < 0){ return ~newid}
				else {return newid;}
			});
		});
		liftme[i].arcs = newarcs;
	});
	
	
	return collection;
$$;