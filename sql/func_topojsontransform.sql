DROP FUNCTION IF EXISTS d3_transform(JSONB, JSONB);
CREATE FUNCTION d3_transform(arc JSONB,transform JSONB)
RETURNS JSONB
immutable language plv8
as $$
	//plv8.elog(NOTICE,JSON.stringify(topology));
	var t = topojson.transform({transform:transform});
	var arcout = arc.map(t);
	//plv8.elog(NOTICE,'Conversiontime: ' + (endT - startT)/1000);
	return arcout;
$$;