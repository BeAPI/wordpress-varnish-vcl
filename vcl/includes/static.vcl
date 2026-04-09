# Static asset handling: strip cookies in recv, path-only hash key, backend TTL rules.
# Extension list in static_recv and static_hash must stay in sync.

sub static_recv {
    if (req.url ~ "^[^?]*\.(7z|avi|avif|bmp|bz2|css|csv|doc|docx|eot|flac|flv|gif|gz|ico|jpeg|jpg|js|less|mka|mkv|mov|mp3|mp4|mpeg|mpg|odt|ogg|ogm|opus|otf|pdf|png|ppt|pptx|rar|rtf|svg|svgz|swf|tar|tbz|tgz|ttf|txt|txz|wav|webm|webp|woff|woff2|xls|xlsx|xml|xz|zip)(\?.*)?$") {
        set req.url = regsub(req.url, "\?.*$", "");
        unset req.http.Cookie;
        set req.http.X-Static-File = "true";
        return (hash);
    }
}

# Page vs static: static uses URL path only (no host) for shared multisite uploads.
# To cache static per domain: hash_data(req.url); hash_data(req.http.host); return (lookup);
sub static_hash {
    if (req.url ~ "\.(7z|avi|avif|bmp|bz2|css|csv|doc|docx|eot|flac|flv|gif|gz|ico|jpeg|jpg|js|less|mka|mkv|mov|mp3|mp4|mpeg|mpg|odt|ogg|ogm|opus|otf|pdf|png|ppt|pptx|rar|rtf|svg|svgz|swf|tar|tbz|tgz|ttf|txt|txz|wav|webm|webp|woff|woff2|xls|xlsx|xml|xz|zip)(\?.*)?$") {
        hash_data(req.url);
        return (lookup);
    }
}

sub static_backend_response {
    if (bereq.http.X-Static-File == "true") {
        unset beresp.http.Set-Cookie;
        if (beresp.http.Cache-Control ~ "private|no-store|no-cache") {
            set beresp.http.X-Cacheable = "NO:Cache-Control";
            set beresp.uncacheable = true;
            set beresp.ttl = 120s;
            return (deliver);
        }
        if (!beresp.http.Cache-Control) {
            set beresp.http.X-Cacheable = "YES:Forced";
            set beresp.ttl = 1d;
            set beresp.grace = 1h;
            set beresp.keep = 1d;
            return (deliver);
        }
    }
}
