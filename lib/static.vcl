# static.vcl -- Static File Caching for Varnish

sub vcl_recv {
    # Mark static files with the X-Static-File header, and remove any cookies
    # X-Static-File is also used in vcl_backend_response to identify static files.
    if (req.url ~ "^[^?]*\.(7z|avi|avif|bmp|bz2|css|csv|doc|docx|eot|flac|flv|gif|gz|ico|jpeg|jpg|js|less|mka|mkv|mov|mp3|mp4|mpeg|mpg|odt|ogg|ogm|opus|otf|pdf|png|ppt|pptx|rar|rtf|svg|svgz|swf|tar|tbz|tgz|ttf|txt|txz|wav|webm|webp|woff|woff2|xls|xlsx|xml|xz|zip)(\?.*)?$") {
        # Remove query string for static files (cache key by path only)
        set req.url = regsub(req.url, "\?.*$", "");
        unset req.http.Cookie;
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
