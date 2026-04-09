sub imageproxy_recv {
    # Route WordPress uploads to imgproxy backend.
    if (req.url ~ "^/(.*)?((content|app)/uploads/(sites/)?[0-9]+/.+)\.(jpg|jpeg|png|webp|gif|avif|tiff|tif|bmp|ico|heic|heif|svg)(\?.*)?$") {
        set req.backend_hint = imgproxy;
    }
}

sub imageproxy_backend_fetch {
    # Rewrite request URL to imgproxy format.
    if (bereq.backend == imgproxy) {
        unset bereq.http.If-Modified-Since;
        unset bereq.http.ETag;
        unset bereq.http.Cache-Control;

        # With processing params (e.g. /rs:fill:500:500/content|app/uploads/sites/2/img.jpg)
        if (bereq.url ~ "^/(.+)(/(content|app)/uploads/sites/[0-9]+/.+)$") {
            set bereq.url = regsub(bereq.url, "^/(.+)(/(content|app)/uploads/sites/[0-9]+/.+)$", "/insecure/\1/plain/local://\2");
        }
        # Without processing params, multisite (e.g. /content|app/uploads/sites/2/img.jpg)
        elsif (bereq.url ~ "^(/(content|app)/uploads/sites/[0-9]+/.+)$") {
            set bereq.url = regsub(bereq.url, "^(/(content|app)/uploads/sites/[0-9]+/.+)$", "/insecure/plain/local://\1");
        }
        # With processing params, single site (e.g. /rs:fill:500:500/content|app/uploads/2025/10/img.jpg)
        elsif (bereq.url ~ "^/(.+)(/(content|app)/uploads/[0-9]+/.+)$") {
            set bereq.url = regsub(bereq.url, "^/(.+)(/(content|app)/uploads/[0-9]+/.+)$", "/insecure/\1/plain/local://\2");
        }
        # Without processing params, single site (e.g. /content|app/uploads/2025/10/img.jpg)
        elsif (bereq.url ~ "^(/(content|app)/uploads/[0-9]+/.+)$") {
            set bereq.url = regsub(bereq.url, "^(/(content|app)/uploads/[0-9]+/.+)$", "/insecure/plain/local://\1");
        }
    }
}
