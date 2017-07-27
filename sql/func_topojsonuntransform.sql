DROP FUNCTION IF EXISTS d3_untransform(JSONB, JSONB);
CREATE FUNCTION d3_untransform(arc JSONB,transform JSONB)
RETURNS JSONB
immutable language plv8
as $$
	//plv8.elog(NOTICE,JSON.stringify(arc));
	var ut = topojson.untransform({transform:transform});
	var arcout = arc.map(ut);
	//plv8.elog(NOTICE,'Conversiontime: ' + (endT - startT)/1000);
	return arcout;
$$;