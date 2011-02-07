backend nginx {
  .host = "127.0.0.1";
  .port = "8008";
}

sub vcl_recv {
  // Strip cookies for static files:
  if (req.url ~ "\.(jpg|jpeg|gif|png|ico|css|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|bmp|rtf|js|flv|swf|html|htm)$") {
    unset req.http.Cookie;
    return(lookup);
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
