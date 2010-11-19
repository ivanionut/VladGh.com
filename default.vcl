backend nginx {
	.host = "127.0.0.1";
	.port = "8008";
}

acl purge {
        "localhost";
        "127.0.0.1";
}

sub vcl_recv {
	
	// Strip cookies for static files:
	if (req.url ~ "\.(jpg|jpeg|gif|png|ico|css|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|bmp|rtf|js|flv|swf|html|htm)$") {
		unset req.http.Cookie;
		return(lookup);
	}	

	// Remove has_js and Google Analytics __* cookies.
	set req.http.Cookie = regsuball(req.http.Cookie, "(^|;\s*)(_[_a-z]+|has_js)=[^;]*", "");
	// Remove a ";" prefix, if present.
	set req.http.Cookie = regsub(req.http.Cookie, "^;\s*", "");
	
	if (req.request == "PURGE") {
		if (!client.ip ~ purge) {
			error 405 "Not allowed.";
		}
		purge("req.url ~ " req.url " && req.http.host == " req.http.host);
		error 200 "Purged.";
	}
}

sub vcl_pipe {
    set bereq.http.connection = "close"; 
	if (req.http.X-Forwarded-For) {
		set bereq.http.X-Forwarded-For = req.http.X-Forwarded-For;
	} else {
		set bereq.http.X-Forwarded-For = regsub(client.ip, ":.*", "");
	}
}

sub vcl_pass {
	if (req.http.X-Forwarded-For) {
		set bereq.http.X-Forwarded-For = req.http.X-Forwarded-For;
	} else {
		set bereq.http.X-Forwarded-For = regsub(client.ip, ":.*", "");
	}
}

sub vcl_miss {
	if (req.http.X-Forwarded-For) {
		set bereq.http.X-Forwarded-For = req.http.X-Forwarded-For;
	} else {
		set bereq.http.X-Forwarded-For = regsub(client.ip, ":.*", "");
	}
}

sub vcl_hash {
  if (req.http.Cookie) {
    set req.hash += req.http.Cookie;
  }
}

sub vcl_fetch {

	// Strip cookies for static files:
	if (req.url ~ "\.(jpg|jpeg|gif|png|ico|css|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|bmp|rtf|js|flv|swf|html|htm)$") {
		unset beresp.http.set-cookie;
	}

	// Varnish determined the object was not cacheable
	if (!beresp.cacheable) {
		set beresp.http.X-Cacheable = "NO:Not Cacheable";
	}
	
	// You don't wish to cache content for logged in users
	elsif(req.http.Cookie ~"(UserID|_session)") {
		set beresp.http.X-Cacheable = "NO:Got Session";
		return(pass);
	}

	// You are respecting the Cache-Control=private header from the backend
	elsif ( beresp.http.Cache-Control ~ "private") {
		set beresp.http.X-Cacheable = "NO:Cache-Control=private";
		return(pass);
	}
	
	// You are extending the lifetime of the object artificially
	elsif ( beresp.ttl < 1s ) {
		set beresp.ttl   = 300s;
		set beresp.grace = 300s;
		set beresp.http.X-Cacheable = "YES:Forced";
	}
	
	// Varnish determined the object was cacheable
	else {
		set beresp.http.X-Cacheable = "YES";
	}
	
	return(deliver);
}

