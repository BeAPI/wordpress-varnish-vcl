### WordPress-specific config ###
sub vcl_recv {
    # Normalize Accept-Encoding to reduce cache fragmentation (br > gzip > none)
    if (req.http.Accept-Encoding) {
        if (req.http.Accept-Encoding ~ "br") {
            set req.http.Accept-Encoding = "br";
        } elsif (req.http.Accept-Encoding ~ "gzip") {
            set req.http.Accept-Encoding = "gzip";
        } else {
            unset req.http.Accept-Encoding;
        }
    }

    # Only handle relevant HTTP request methods
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

    # Implementing websocket support (https://www.varnish-cache.org/docs/4.0/users-guide/vcl-example-websockets.html)
    if (req.http.Upgrade ~ "(?i)websocket") {
        return (pipe);
    }

    # Only cache GET and HEAD requests
    if (req.method != "GET" && req.method != "HEAD") {
        set req.http.X-Cacheable = "NO:REQUEST-METHOD";
        return(pass);
    }

    # No caching of special URLs, logged in users and some plugins
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
	     if(req.http.X-Requested-With == "XMLHttpRequest") {
		     set req.http.X-Cacheable = "NO:Ajax";
	     }
        return(pass);
    }

    # don't cache ajax requests
    if (req.http.X-Requested-With == "XMLHttpRequest") {
        set req.http.X-Cacheable = "NO:AJAX";
        return(pass);
    }

    ### looks like we might actually cache it!
    # fix up the request
    set req.url = regsub(req.url, "\?replytocom=.*$", "");

    # Remove tracking/analytics cookies only when Cookie header is present (avoid adding empty Cookie to backend)
    if (req.http.Cookie) {
        set req.http.Cookie = regsuball(req.http.Cookie, "(^|;\s*)(has_js|wooTracker)=[^;]*", "");
        set req.http.Cookie = regsuball(req.http.Cookie, "__utm.=[^;]+(; )?", "");
        set req.http.Cookie = regsuball(req.http.Cookie, "_ga=[^;]+(; )?", "");
        set req.http.Cookie = regsuball(req.http.Cookie, "_gat=[^;]+(; )?", "");
        set req.http.Cookie = regsuball(req.http.Cookie, "utmctr=[^;]+(; )?", "");
        set req.http.Cookie = regsuball(req.http.Cookie, "utmcmd.=[^;]+(; )?", "");
        set req.http.Cookie = regsuball(req.http.Cookie, "utmccn.=[^;]+(; )?", "");
        set req.http.Cookie = regsub(req.http.Cookie, "^;\s*", "");

        # Remove DoubleClick offensive cookies
        set req.http.Cookie = regsuball(req.http.Cookie, "__gads=[^;]+(; )?", "");

        # Remove the Quant Capital cookies (added by some plugin, all __qca)
        set req.http.Cookie = regsuball(req.http.Cookie, "__qc.=[^;]+(; )?", "");

        # Remove the AddThis cookies
        set req.http.Cookie = regsuball(req.http.Cookie, "__atuv.=[^;]+(; )?", "");

        # Remove a ";" prefix in the cookie if present
        set req.http.Cookie = regsuball(req.http.Cookie, "^;\s*", "");

        # Are there cookies left with only spaces or that are empty?
        if (req.http.Cookie ~ "^\s*$") {
            unset req.http.Cookie;
        }
    }

    # Remove the proxy header to mitigate the httpoxy vulnerability
    # See https://httpoxy.org/
    unset req.http.proxy;

    # Enhanced tracking parameter removal - comprehensive list from Varnish docs (origin excluded: used by APIs/CORS)
    if (req.url ~ "(\?|&)(_branch_match_id|_bta_[a-z]+|_bta_c|_bta_tid|_ga|_gl|_ke|_kx|campid|cof|customid|cx|dclid|dm_i|ef_id|epik|fbclid|gad_source|gbraid|gclid|gclsrc|gdffi|gdfms|gdftrk|hsa_acc|hsa_ad|hsa_cam|hsa_grp|hsa_kw|hsa_mt|hsa_net|hsa_src|hsa_tgt|hsa_ver|ie|igshid|irclickid|matomo_campaign|matomo_cid|matomo_content|matomo_group|matomo_keyword|matomo_medium|matomo_placement|matomo_source|mc_[a-z]+|mc_cid|mc_eid|mkcid|mkevt|mkrid|mkwid|msclkid|mtm_campaign|mtm_cid|mtm_content|mtm_group|mtm_keyword|mtm_medium|mtm_placement|mtm_source|nb_klid|ndclid|pcrid|piwik_campaign|piwik_keyword|piwik_kwd|pk_campaign|pk_keyword|pk_kwd|redirect_log_mongo_id|redirect_mongo_id|rtid|s_kwcid|sb_referer_host|sccid|si|siteurl|sms_click|sms_source|sms_uph|srsltid|toolid|trk_contact|trk_module|trk_msg|trk_sid|ttclid|twclid|utm_[a-z]+|utm_campaign|utm_content|utm_creative_format|utm_id|utm_marketing_tactic|utm_medium|utm_source|utm_source_platform|utm_term|vmcid|wbraid|yclid|zanpid)=") {
        set req.url = regsuball(req.url, "(_branch_match_id|_bta_[a-z]+|_bta_c|_bta_tid|_ga|_gl|_ke|_kx|campid|cof|customid|cx|dclid|dm_i|ef_id|epik|fbclid|gad_source|gbraid|gclid|gclsrc|gdffi|gdfms|gdftrk|hsa_acc|hsa_ad|hsa_cam|hsa_grp|hsa_kw|hsa_mt|hsa_net|hsa_src|hsa_tgt|hsa_ver|ie|igshid|irclickid|matomo_campaign|matomo_cid|matomo_content|matomo_group|matomo_keyword|matomo_medium|matomo_placement|matomo_source|mc_[a-z]+|mc_cid|mc_eid|mkcid|mkevt|mkrid|mkwid|msclkid|mtm_campaign|mtm_cid|mtm_content|mtm_group|mtm_keyword|mtm_medium|mtm_placement|mtm_source|nb_klid|ndclid|pcrid|piwik_campaign|piwik_keyword|piwik_kwd|pk_campaign|pk_keyword|pk_kwd|redirect_log_mongo_id|redirect_mongo_id|rtid|s_kwcid|sb_referer_host|sccid|si|siteurl|sms_click|sms_source|sms_uph|srsltid|toolid|trk_contact|trk_module|trk_msg|trk_sid|ttclid|twclid|utm_[a-z]+|utm_campaign|utm_content|utm_creative_format|utm_id|utm_marketing_tactic|utm_medium|utm_source|utm_source_platform|utm_term|vmcid|wbraid|yclid|zanpid)=[-_A-Za-z0-9+(){}%.*]+&?", "");
        set req.url = regsub(req.url, "[?|&]+$", "");
    }

    # Strip hash, server doesn't need it.
    if (req.url ~ "\#") {
        set req.url = regsub(req.url, "\#.*$", "");
    }

    # Remove empty query string parameters
    # e.g.: www.example.com/index.html?
    if (req.url ~ "\?$") {
        set req.url = regsub(req.url, "\?$", "");
    }

    # Remove port number from host header (only when present to avoid sending empty Host to backend)
    if (req.http.Host) {
        set req.http.Host = regsub(req.http.Host, ":[0-9]+", "");
    }

    # Sorts query string parameters alphabetically for cache normalization purposes
    set req.url = std.querysort(req.url);

    return(hash);
}

sub vcl_hash {

    /**
    Here the hash cache key for pages is based on :
    - Proto (http/https)
    - Content encoding (gzip, none, br etc.)
    - Cookie
    - path (/fr/)
    - ip/host

    The hash cache key for static files is based on :
    - Proto (http/https)
    - Content encoding (gzip, none, br etc.)
    - path (/app/uploads/sites/3/cache/2022/03/cropped-favicon/1998897081.png)

    So for static files into WordPress the same file will be served on :
    - domain1.com/app/uploads/sites/3/cache/2022/03/cropped-favicon/1998897081.png
    OR
    - domain2.com/app/uploads/sites/3/cache/2022/03/cropped-favicon/1998897081.png
    **/

    if(req.http.X-Forwarded-Proto) {
        # Create cache variations depending on the request protocol
        hash_data(req.http.X-Forwarded-Proto);
    }

    # If the client supports compression, keep that in a different cache
    if (req.http.Accept-Encoding) {
        hash_data(req.http.Accept-Encoding);
    }

    # Only hash cookies for the non static files. Extension list must match vcl_recv static block.
    if (req.url !~ "\.(7z|avi|avif|bmp|bz2|css|csv|doc|docx|eot|flac|flv|gif|gz|ico|jpeg|jpg|js|less|mka|mkv|mov|mp3|mp4|mpeg|mpg|odt|ogg|ogm|opus|otf|pdf|png|ppt|pptx|rar|rtf|svg|svgz|swf|tar|tbz|tgz|ttf|txt|txz|wav|webm|webp|woff|woff2|xls|xlsx|xml|xz|zip)(\?.*)?$") {
        # Add the browser cookie only if a WordPress cookie found.
        if (req.http.Cookie ~ "wp-postpass_|wordpress_logged_in_") {
            hash_data(req.http.Cookie);
        }
    } else {
        # Static files: proto and encoding already hashed above; add path and done
        hash_data(req.url);
        return( lookup );
    }

    # Do not return anything to let Varnish create a hash based with the url, the domain etc.
}

sub vcl_backend_response {
    # Inject URL & Host header into the object for asynchronous banning purposes
    set beresp.http.x-url = bereq.url;
    set beresp.http.x-host = bereq.http.host;

    # make sure grace is at least 2 hours
    if (beresp.grace < 2h) {
        set beresp.grace = 2h;
    }

    # Catch obvious reasons we can't cache before applying default TTL
    if (beresp.http.Set-Cookie) {
        set beresp.http.X-Cacheable = "NO:Got Cookies";
        set beresp.ttl = 0s;
        return (deliver);
    }

    # If we dont get a Cache-Control header from the backend we default to 1h (excluding static files, which get 1d from static.vcl)
    if (!beresp.http.Cache-Control && bereq.http.X-Static-File != "true") {
        set beresp.ttl = 1h;
        set beresp.http.X-Cacheable = "YES:Forced";
    }

    if (beresp.ttl <= 0s) {
        set beresp.uncacheable = true;
        set beresp.http.X-Cacheable = "NO:TTL0";
        set beresp.ttl = 120s;

    # You are respecting the Cache-Control=private header from the backend
     } else if (beresp.http.Cache-Control ~ "private" || beresp.http.Cache-Control ~ "no-store") {
        set beresp.http.X-Cacheable = "NO:Cache-Control=private,no-store";
        set beresp.uncacheable = true;
        set beresp.ttl = 0s;

        # Cache object
    }

    # Short-lived cache for 5xx errors to absorb traffic spikes while the backend recovers.
    # Kept intentionally brief (1m TTL, 30s grace) to avoid masking persistent failures.
    if (beresp.status >= 500) {
        set beresp.ttl = 1m;
        set beresp.grace = 30s;
        set beresp.http.X-Cacheable = "YES:500";
    }

    # 404 responses - let Varnish handle them normally (respecting backend headers)
    if (beresp.status == 404) {
        set beresp.http.X-Cacheable = "YES:404";
    }

    # Deliver the content
    return(deliver);
}

sub vcl_deliver {
    # Remove some headers: PHP version
    unset resp.http.X-Powered-By;
    unset resp.http.Server;
    unset resp.http.Via;
    unset resp.http.X-Varnish;

    # Debug headers — only exposed when the request includes X-Debug
    if (req.http.X-Debug) {
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

    # Cleanup internal headers
    unset resp.http.x-url;
    unset resp.http.x-host;
}

sub vcl_pipe {
     if (req.http.upgrade) {
         set bereq.http.upgrade = req.http.upgrade;
     }
}