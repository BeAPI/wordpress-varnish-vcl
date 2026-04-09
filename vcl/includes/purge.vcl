# PURGE/BAN for the Proxy Cache Purge WordPress plugin.
# See https://wordpress.org/plugins/varnish-http-purge/

sub purge_recv {
    if (req.method == "PURGE" || req.method == "BAN") {
        if (!std.ip(regsub(req.http.X-Forwarded-For, "[, ].*$", ""), client.ip) ~ purge_acl) {
            return (synth(405, "PURGE not allowed for this IP address"));
        }

        if (req.http.X-Purge-Method == "regex") {
            ban("obj.http.x-url ~ " + req.url + " && obj.http.x-host == " + req.http.host);
            return (synth(200, "Purged"));
        }

        if (req.http.X-Purge-Method == "all") {
            ban("obj.http.x-url ~ / && obj.http.x-host == " + req.http.host);
            return (synth(200, "Purged all caches"));
        }

        ban("obj.http.x-url == " + req.url + " && obj.http.x-host == " + req.http.host);
        return (synth(200, "Purged"));
    }
}
