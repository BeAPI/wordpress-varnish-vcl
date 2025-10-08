# static.vcl -- Static File Caching for Varnish

sub vcl_recv {
    if (req.method ~ "^(GET|HEAD)$" && req.url ~ "\.(jpg|jpeg|gif|png|ico|css|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|bmp|rtf|js|flv|swf|html|htm|woff|woff2|svg|webp|avif)(\?.*)?$") {
        # Remove all file parameters from url
        set req.url = regsub(req.url, "\?.*$", "");

        # unset cookie only if no http auth
        if (!req.http.Authorization) {
            unset req.http.Cookie;
        }

        set req.http.X-Static-File = "true";

        return(hash);
    }
}

# Enhanced static file handling in backend response
sub vcl_backend_response {
    # If the file is marked as static we cache it for 1 day
    if (bereq.http.X-Static-File == "true") {
        unset beresp.http.Set-Cookie;
        set beresp.http.X-Cacheable = "YES:Forced";
        set beresp.ttl = 1d;
        set beresp.grace = 1h;
        set beresp.keep = 1d;
    }
}
