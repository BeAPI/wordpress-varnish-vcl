vcl 4.1;

import std;
import directors;

# ----------------------------------------------------------------------
# ACL
# ----------------------------------------------------------------------

acl purge_acl {
    "localhost";
    "127.0.0.1";
    "::1";
}

# ----------------------------------------------------------------------
# Backend
# ----------------------------------------------------------------------

backend backend1 {
    .host = "127.0.0.1";
    .port = "8080";
    .first_byte_timeout = 300s;
    .connect_timeout    = 5s;
    .between_bytes_timeout = 2s;
    .probe = {
        .url = "/";
        .interval = 10s;
        .timeout = 5s;
        .window = 5;
        .threshold = 3;
    }
}

# Uncomment to enable imgproxy image processing (see README).
# backend imgproxy {
#     .host = "127.0.0.1";
#     .port = "8089";
#     .first_byte_timeout = 60s;
#     .connect_timeout    = 5s;
#     .between_bytes_timeout = 2s;
#     .probe = {
#         .url = "/health";
#         .interval = 10s;
#         .timeout = 5s;
#         .window = 5;
#         .threshold = 3;
#     }
# }

sub vcl_init {
    new backends = directors.round_robin();
    backends.add_backend(backend1);
}

# ----------------------------------------------------------------------
# vcl_recv
# ----------------------------------------------------------------------

sub vcl_recv {
    # -- Backend selection --
    set req.backend_hint = backends.backend();

    # -- Route WordPress upload images through imgproxy --
    # Uncomment to enable (requires the imgproxy backend above).
    # Matches content/uploads/ and app/uploads/ paths with image extensions supported by imgproxy Community.
    # URLs may include processing params before the path (e.g. /rs:fill:500:500/content/uploads/...).
    # if (req.url ~ "^/(.*)?((content|app)/uploads/(sites/)?[0-9]+/.+)\.(jpg|jpeg|png|webp|gif|avif|tiff|tif|bmp|ico|heic|heif|svg)(\?.*)?$") {
    #     set req.backend_hint = imgproxy;
    # }

    # -- X-Forwarded-For: keep only the first (client) IP behind a trusted proxy --
    if (req.http.X-Forwarded-For) {
        set req.http.X-Forwarded-For = regsub(req.http.X-Forwarded-For, "^([^,]+).*", "\1");
    }

    # -- Purge / BAN --
    # Tailored to the Proxy Cache Purge WordPress plugin.
    # See https://wordpress.org/plugins/varnish-http-purge/
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

    # -- Static files: strip cookies, mark with X-Static-File, skip to hash --
    # Extension list must match the one in vcl_hash.
    if (req.url ~ "^[^?]*\.(7z|avi|avif|bmp|bz2|css|csv|doc|docx|eot|flac|flv|gif|gz|ico|jpeg|jpg|js|less|mka|mkv|mov|mp3|mp4|mpeg|mpg|odt|ogg|ogm|opus|otf|pdf|png|ppt|pptx|rar|rtf|svg|svgz|swf|tar|tbz|tgz|ttf|txt|txz|wav|webm|webp|woff|woff2|xls|xlsx|xml|xz|zip)(\?.*)?$") {
        set req.url = regsub(req.url, "\?.*$", "");
        unset req.http.Cookie;
        set req.http.X-Static-File = "true";
        return (hash);
    }

    # -- Normalize Accept-Encoding to reduce cache fragmentation (br > gzip > none) --
    if (req.http.Accept-Encoding) {
        if (req.http.Accept-Encoding ~ "br") {
            set req.http.Accept-Encoding = "br";
        } elsif (req.http.Accept-Encoding ~ "gzip") {
            set req.http.Accept-Encoding = "gzip";
        } else {
            unset req.http.Accept-Encoding;
        }
    }

    # -- Pipe unknown HTTP methods --
    if (
        req.method != "GET" &&
        req.method != "HEAD" &&
        req.method != "PUT" &&
        req.method != "POST" &&
        req.method != "PATCH" &&
        req.method != "TRACE" &&
        req.method != "OPTIONS" &&
        req.method != "DELETE"
    ) {
        return (pipe);
    }

    # -- Pipe WebSocket upgrades --
    # https://www.varnish-cache.org/docs/4.0/users-guide/vcl-example-websockets.html
    if (req.http.Upgrade ~ "(?i)websocket") {
        return (pipe);
    }

    # -- Pass non-cacheable HTTP methods --
    if (req.method != "GET" && req.method != "HEAD") {
        set req.http.X-Cacheable = "NO:REQUEST-METHOD";
        return (pass);
    }

    # -- Pass special URLs, authenticated users, and plugin-specific paths --
    if (
        req.http.Cookie ~ "wordpress_(?!test_)[a-zA-Z0-9_]+|wp-postpass|comment_author_[a-zA-Z0-9_]+|woocommerce_cart_hash|woocommerce_items_in_cart|wp_woocommerce_session_[a-zA-Z0-9]+|wordpress_logged_in_|comment_author|PHPSESSID" ||
        req.http.Authorization ||
        req.url ~ "add_to_cart" ||
        req.url ~ "edd_action" ||
        req.url ~ "nocache" ||
        req.url ~ "^/addons" ||
        req.url ~ "^/bb-admin" ||
        req.url ~ "^/bb-login.php" ||
        req.url ~ "^/bb-reset-password.php" ||
        req.url ~ "^/cart" ||
        req.url ~ "^/checkout" ||
        req.url ~ "^/control.php" ||
        req.url ~ "^/login" ||
        req.url ~ "^/logout" ||
        req.url ~ "^/lost-password" ||
        req.url ~ "^/my-account" ||
        req.url ~ "^/register" ||
        req.url ~ "^/register.php" ||
        req.url ~ "^/server-status" ||
        req.url ~ "^/signin" ||
        req.url ~ "^/signup" ||
        req.url ~ "^/stats" ||
        req.url ~ "^/wc-api" ||
        req.url ~ "^/wp-admin" ||
        req.url ~ "^/wp-comments-post.php" ||
        req.url ~ "^/wp-cron.php" ||
        req.url ~ "^/wp-login.php" ||
        req.url ~ "^/wp-activate.php" ||
        req.url ~ "^/wp-mail.php" ||
        req.url ~ "(\?|&)add-to-cart=" ||
        req.url ~ "(\?|&)wc-api=" ||
        req.url ~ "(\?|&)preview=" ||
        req.url ~ "^/\.well-known/acme-challenge/"
    ) {
        set req.http.X-Cacheable = "NO:Logged in/Got Sessions";
        if (req.http.X-Requested-With == "XMLHttpRequest") {
            set req.http.X-Cacheable = "NO:Ajax";
        }
        return (pass);
    }

    # -- Pass AJAX requests --
    if (req.http.X-Requested-With == "XMLHttpRequest") {
        set req.http.X-Cacheable = "NO:AJAX";
        return (pass);
    }

    # -- URL cleanup --
    set req.url = regsub(req.url, "\?replytocom=.*$", "");

    # -- Strip tracking/analytics cookies --
    if (req.http.Cookie) {
        set req.http.Cookie = regsuball(req.http.Cookie, "(^|;\s*)(has_js|wooTracker)=[^;]*", "");
        set req.http.Cookie = regsuball(req.http.Cookie, "__utm.=[^;]+(; )?", "");
        set req.http.Cookie = regsuball(req.http.Cookie, "_ga=[^;]+(; )?", "");
        set req.http.Cookie = regsuball(req.http.Cookie, "_gat=[^;]+(; )?", "");
        set req.http.Cookie = regsuball(req.http.Cookie, "utmctr=[^;]+(; )?", "");
        set req.http.Cookie = regsuball(req.http.Cookie, "utmcmd.=[^;]+(; )?", "");
        set req.http.Cookie = regsuball(req.http.Cookie, "utmccn.=[^;]+(; )?", "");
        set req.http.Cookie = regsuball(req.http.Cookie, "__gads=[^;]+(; )?", "");
        set req.http.Cookie = regsuball(req.http.Cookie, "__qc.=[^;]+(; )?", "");
        set req.http.Cookie = regsuball(req.http.Cookie, "__atuv.=[^;]+(; )?", "");
        set req.http.Cookie = regsuball(req.http.Cookie, "^;\s*", "");

        if (req.http.Cookie ~ "^\s*$") {
            unset req.http.Cookie;
        }
    }

    # -- HTTPOXY mitigation (https://httpoxy.org/) --
    unset req.http.proxy;

    # -- Strip tracking query parameters (origin excluded: used by APIs/CORS) --
    if (req.url ~ "(\?|&)(_branch_match_id|_bta_[a-z]+|_bta_c|_bta_tid|_ga|_gl|_ke|_kx|campid|cof|customid|cx|dclid|dm_i|ef_id|epik|fbclid|gad_source|gbraid|gclid|gclsrc|gdffi|gdfms|gdftrk|hsa_acc|hsa_ad|hsa_cam|hsa_grp|hsa_kw|hsa_mt|hsa_net|hsa_src|hsa_tgt|hsa_ver|ie|igshid|irclickid|matomo_campaign|matomo_cid|matomo_content|matomo_group|matomo_keyword|matomo_medium|matomo_placement|matomo_source|mc_[a-z]+|mc_cid|mc_eid|mkcid|mkevt|mkrid|mkwid|msclkid|mtm_campaign|mtm_cid|mtm_content|mtm_group|mtm_keyword|mtm_medium|mtm_placement|mtm_source|nb_klid|ndclid|pcrid|piwik_campaign|piwik_keyword|piwik_kwd|pk_campaign|pk_keyword|pk_kwd|redirect_log_mongo_id|redirect_mongo_id|rtid|s_kwcid|sb_referer_host|sccid|si|siteurl|sms_click|sms_source|sms_uph|srsltid|toolid|trk_contact|trk_module|trk_msg|trk_sid|ttclid|twclid|utm_[a-z]+|utm_campaign|utm_content|utm_creative_format|utm_id|utm_marketing_tactic|utm_medium|utm_source|utm_source_platform|utm_term|vmcid|wbraid|yclid|zanpid)=") {
        set req.url = regsuball(req.url, "(_branch_match_id|_bta_[a-z]+|_bta_c|_bta_tid|_ga|_gl|_ke|_kx|campid|cof|customid|cx|dclid|dm_i|ef_id|epik|fbclid|gad_source|gbraid|gclid|gclsrc|gdffi|gdfms|gdftrk|hsa_acc|hsa_ad|hsa_cam|hsa_grp|hsa_kw|hsa_mt|hsa_net|hsa_src|hsa_tgt|hsa_ver|ie|igshid|irclickid|matomo_campaign|matomo_cid|matomo_content|matomo_group|matomo_keyword|matomo_medium|matomo_placement|matomo_source|mc_[a-z]+|mc_cid|mc_eid|mkcid|mkevt|mkrid|mkwid|msclkid|mtm_campaign|mtm_cid|mtm_content|mtm_group|mtm_keyword|mtm_medium|mtm_placement|mtm_source|nb_klid|ndclid|pcrid|piwik_campaign|piwik_keyword|piwik_kwd|pk_campaign|pk_keyword|pk_kwd|redirect_log_mongo_id|redirect_mongo_id|rtid|s_kwcid|sb_referer_host|sccid|si|siteurl|sms_click|sms_source|sms_uph|srsltid|toolid|trk_contact|trk_module|trk_msg|trk_sid|ttclid|twclid|utm_[a-z]+|utm_campaign|utm_content|utm_creative_format|utm_id|utm_marketing_tactic|utm_medium|utm_source|utm_source_platform|utm_term|vmcid|wbraid|yclid|zanpid)=[-_A-Za-z0-9+(){}%.*]+&?", "");
        set req.url = regsub(req.url, "[?|&]+$", "");
    }

    # -- Strip URL fragment (hash) --
    if (req.url ~ "\#") {
        set req.url = regsub(req.url, "\#.*$", "");
    }

    # -- Strip trailing empty query string --
    if (req.url ~ "\?$") {
        set req.url = regsub(req.url, "\?$", "");
    }

    # -- Strip port number from Host header --
    if (req.http.Host) {
        set req.http.Host = regsub(req.http.Host, ":[0-9]+", "");
    }

    # -- Sort query string for cache normalization --
    set req.url = std.querysort(req.url);

    return (hash);
}

# ----------------------------------------------------------------------
# vcl_backend_fetch
# ----------------------------------------------------------------------

# Uncomment to enable imgproxy URL rewriting (requires the imgproxy backend and routing above).
# sub vcl_backend_fetch {
#     # -- Rewrite URLs to imgproxy format before sending to the imgproxy backend --
#     if (bereq.backend == imgproxy) {
#         unset bereq.http.If-Modified-Since;
#         unset bereq.http.ETag;
#         unset bereq.http.Cache-Control;
#
#         # With processing params (e.g. /rs:fill:500:500/content|app/uploads/sites/2/img.jpg)
#         if (bereq.url ~ "^/(.+)(/(content|app)/uploads/sites/[0-9]+/.+)$") {
#             set bereq.url = regsub(bereq.url, "^/(.+)(/(content|app)/uploads/sites/[0-9]+/.+)$", "/insecure/\1/plain/local://\2");
#         }
#         # Without processing params, multisite (e.g. /content|app/uploads/sites/2/img.jpg)
#         elsif (bereq.url ~ "^(/(content|app)/uploads/sites/[0-9]+/.+)$") {
#             set bereq.url = regsub(bereq.url, "^(/(content|app)/uploads/sites/[0-9]+/.+)$", "/insecure/plain/local://\1");
#         }
#         # With processing params, single site (e.g. /rs:fill:500:500/content|app/uploads/2025/10/img.jpg)
#         elsif (bereq.url ~ "^/(.+)(/(content|app)/uploads/[0-9]+/.+)$") {
#             set bereq.url = regsub(bereq.url, "^/(.+)(/(content|app)/uploads/[0-9]+/.+)$", "/insecure/\1/plain/local://\2");
#         }
#         # Without processing params, single site (e.g. /content|app/uploads/2025/10/img.jpg)
#         elsif (bereq.url ~ "^(/(content|app)/uploads/[0-9]+/.+)$") {
#             set bereq.url = regsub(bereq.url, "^(/(content|app)/uploads/[0-9]+/.+)$", "/insecure/plain/local://\1");
#         }
#     }
# }

# ----------------------------------------------------------------------
# vcl_hash
# ----------------------------------------------------------------------

sub vcl_hash {
    /**
    Cache key for pages:
    - Proto (http/https)
    - Content encoding (br, gzip — normalized in vcl_recv)
    - URL + host (Varnish default)

    Cache key for static files:
    - Proto (http/https)
    - Content encoding (br, gzip — normalized in vcl_recv)
    - URL path only (no host — shared across domains)
    **/

    # -- Protocol variation --
    if (req.http.X-Forwarded-Proto) {
        hash_data(req.http.X-Forwarded-Proto);
    }

    # -- Encoding variation --
    if (req.http.Accept-Encoding) {
        hash_data(req.http.Accept-Encoding);
    }

    # -- Page vs static file hashing --
    # Extension list must match the vcl_recv static block.
    #
    # By default, static files are hashed by URL path only (no host), so the same
    # asset served from domain1.com and domain2.com shares a single cache entry.
    # This is optimal for WordPress multisite with shared uploads (e.g. /app/uploads/).
    #
    # To cache static files per domain instead, add hash_data(req.http.host) below:
    #       hash_data(req.url);
    #       hash_data(req.http.host);
    #       return (lookup);
    #
    # Non-static files fall through without returning, so Varnish appends its
    # default hash (host + URL) automatically.
    if (req.url ~ "\.(7z|avi|avif|bmp|bz2|css|csv|doc|docx|eot|flac|flv|gif|gz|ico|jpeg|jpg|js|less|mka|mkv|mov|mp3|mp4|mpeg|mpg|odt|ogg|ogm|opus|otf|pdf|png|ppt|pptx|rar|rtf|svg|svgz|swf|tar|tbz|tgz|ttf|txt|txz|wav|webm|webp|woff|woff2|xls|xlsx|xml|xz|zip)(\?.*)?$") {
        hash_data(req.url);
        return (lookup);
    }
}

# ----------------------------------------------------------------------
# vcl_backend_response
# ----------------------------------------------------------------------

sub vcl_backend_response {
    # -- Bypass cache for files > 10 MB and stream them directly --
    if (std.integer(beresp.http.Content-Length, 0) > 10485760) {
        set beresp.uncacheable = true;
        set beresp.do_stream = true;
        set beresp.ttl = 120s;
        return (deliver);
    }

    # -- Static files: respect Cache-Control; default 1d only when backend sends no Cache-Control --
    # When Cache-Control is present, do not force TTL (beresp.ttl may still be 0 here; Varnish
    # applies max-age later). Only force 1d when the backend omits Cache-Control entirely.
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
        # Backend sent Cache-Control (e.g. max-age) — fall through, Varnish keeps it
    }

    # -- Fix backend port leaking into redirect Location headers --
    if (beresp.status == 301 || beresp.status == 302) {
        set beresp.http.Location = regsub(beresp.http.Location, ":[0-9]+", "");
    }

    # -- Inject URL and Host for asynchronous banning --
    set beresp.http.x-url = bereq.url;
    set beresp.http.x-host = bereq.http.host;

    # -- Ensure grace is at least 2 hours --
    if (beresp.grace < 2h) {
        set beresp.grace = 2h;
    }

    # -- Responses with Set-Cookie are not cacheable --
    if (beresp.http.Set-Cookie) {
        set beresp.http.X-Cacheable = "NO:Got Cookies";
        set beresp.ttl = 0s;
        return (deliver);
    }

    # -- Default TTL when the backend sends no Cache-Control --
    # When the backend omits Cache-Control, we force a 1h TTL so responses are cached.
    # To disable: comment out the block below. Responses without Cache-Control will then
    # keep beresp.ttl = 0 and be marked uncacheable by the "beresp.ttl <= 0s" block.
    # See README "Default TTL when backend has no Cache-Control".
    if (!beresp.http.Cache-Control) {
        set beresp.ttl = 1h;
        set beresp.http.X-Cacheable = "YES:Forced";
    }

    # -- Mark as uncacheable: zero TTL, private/no-store, or Vary: * --
    if (beresp.ttl <= 0s) {
        set beresp.uncacheable = true;
        set beresp.http.X-Cacheable = "NO:TTL0";
        set beresp.ttl = 120s;
    } else if (beresp.http.Cache-Control ~ "private" || beresp.http.Cache-Control ~ "no-store") {
        set beresp.http.X-Cacheable = "NO:Cache-Control=private,no-store";
        set beresp.uncacheable = true;
        set beresp.ttl = 0s;
    } else if (beresp.http.Vary == "*") {
        set beresp.http.X-Cacheable = "NO:Vary=*";
        set beresp.uncacheable = true;
        set beresp.ttl = 120s;
    }

    # -- Short-lived cache for 5xx errors --
    # Absorbs traffic spikes while the backend recovers.
    # Only set TTL when the backend did not send Cache-Control and TTL is 0 (respect HTTP semantics).
    # Kept intentionally brief (1m TTL, 30s grace) to avoid masking persistent failures.
    if (beresp.status >= 500) {
        if (!beresp.http.Cache-Control && beresp.ttl <= 0s) {
            set beresp.ttl = 1m;
            set beresp.grace = 30s;
            set beresp.http.X-Cacheable = "YES:500";
        }
    }

    # -- Cache 404 responses normally (respecting backend headers) --
    if (beresp.status == 404) {
        set beresp.http.X-Cacheable = "YES:404";
    }

    return (deliver);
}

# ----------------------------------------------------------------------
# vcl_deliver
# ----------------------------------------------------------------------

sub vcl_deliver {
    # -- Strip backend-revealing headers --
    unset resp.http.X-Powered-By;
    unset resp.http.Server;
    unset resp.http.Via;
    unset resp.http.X-Varnish;

    # -- Debug headers (only when the request includes X-Debug) --
    if (req.http.X-Debug) {
        if (obj.hits > 0) {
            set resp.http.X-Cache = "HIT";
        } else {
            set resp.http.X-Cache = "MISS";
        }
        set resp.http.X-Cache-Hits = obj.hits;

        if (req.http.X-Cacheable) {
            set resp.http.X-Cacheable = req.http.X-Cacheable;
        } elsif (obj.uncacheable) {
            if (!resp.http.X-Cacheable) {
                set resp.http.X-Cacheable = "NO:UNCACHEABLE";
            }
        } elsif (!resp.http.X-Cacheable) {
            set resp.http.X-Cacheable = "YES";
        }
    } else {
        unset resp.http.X-Cacheable;
    }

    # -- Cleanup internal headers used for banning --
    unset resp.http.x-url;
    unset resp.http.x-host;
}

# ----------------------------------------------------------------------
# vcl_pipe
# ----------------------------------------------------------------------

sub vcl_pipe {
    # -- Forward WebSocket upgrade header to the backend --
    if (req.http.upgrade) {
        set bereq.http.upgrade = req.http.upgrade;
    }
}
