DROP FUNCTION  IF EXISTS d3_toponeighbours(collection JSONB);
CREATE FUNCTION d3_toponeighbours(collection JSONB)
RETURNS JSONB
immutable language plv8
as $$
	var startT = new Date();
	//plv8.elog(NOTICE,JSON.stringify(collection));
	var neighbours = topojson.neighbors(collection);
	var endT = new Date();
	//plv8.elog(NOTICE,'Topotime: ' + (endT - startT)/1000);
	//plv8.elog(NOTICE,JSON.stringify(topo));
	return neighbours;
$$;