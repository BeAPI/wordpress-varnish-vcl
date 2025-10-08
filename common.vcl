vcl 4.0;

### WordPress-specific config ###
sub vcl_recv {
    # pipe on weird http methods
    if (req.method !~ "^GET|HEAD|PUT|POST|TRACE|OPTIONS|DELETE$") {
        return(pipe);
    }

    # Implementing websocket support (https://www.varnish-cache.org/docs/4.0/users-guide/vcl-example-websockets.html)
    if (req.http.Upgrade ~ "(?i)websocket") {
        return (pipe);
    }

    ### Check for reasons to bypass the cache!
    # never cache anything except GET/HEAD
    if (req.method != "GET" && req.method != "HEAD") {
        set req.http.X-Cacheable = "NO:REQUEST-METHOD";
        return(pass);
    }

    # don't cache ajax requests
    if (req.http.X-Requested-With == "XMLHttpRequest") {
        set req.http.X-Cacheable = "NO:AJAX";
        return(pass);
    }

    # Check for HTTP authentication - no cache
    if (req.http.Authorization) {
        set req.http.X-Cacheable = "NO:AUTH";
        return(pass);
    }

    # Enhanced cookie handling for WordPress and PHP sessions
    # don't cache post-passwords and logged in users
    if (req.http.Cookie ~ "wordpress_(?!test_)[a-zA-Z0-9_]+|wp-postpass|comment_author_[a-zA-Z0-9_]+|woocommerce_cart_hash|woocommerce_items_in_cart|wp_woocommerce_session_[a-zA-Z0-9]+|wordpress_logged_in_|comment_author|PHPSESSID|sessionid") {
        set req.http.X-Cacheable = "NO:LOGGEDIN";
        return(pass);
    }

    ### looks like we might actually cache it!
    # fix up the request
    set req.url = regsub(req.url, "\?replytocom=.*$", "");

    # Remove has_js, Google Analytics __*, and wooTracker cookies.
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

    # Protecting against the HTTPOXY CGI vulnerability.
    unset req.http.proxy;

    # Enhanced tracking parameter removal - comprehensive list from Varnish docs
    if (req.url ~ "(\?|&)(_branch_match_id|_bta_[a-z]+|_bta_c|_bta_tid|_ga|_gl|_ke|_kx|campid|cof|customid|cx|dclid|dm_i|ef_id|epik|fbclid|gad_source|gbraid|gclid|gclsrc|gdffi|gdfms|gdftrk|hsa_acc|hsa_ad|hsa_cam|hsa_grp|hsa_kw|hsa_mt|hsa_net|hsa_src|hsa_tgt|hsa_ver|ie|igshid|irclickid|matomo_campaign|matomo_cid|matomo_content|matomo_group|matomo_keyword|matomo_medium|matomo_placement|matomo_source|mc_[a-z]+|mc_cid|mc_eid|mkcid|mkevt|mkrid|mkwid|msclkid|mtm_campaign|mtm_cid|mtm_content|mtm_group|mtm_keyword|mtm_medium|mtm_placement|mtm_source|nb_klid|ndclid|origin|pcrid|piwik_campaign|piwik_keyword|piwik_kwd|pk_campaign|pk_keyword|pk_kwd|redirect_log_mongo_id|redirect_mongo_id|rtid|s_kwcid|sb_referer_host|sccid|si|siteurl|sms_click|sms_source|sms_uph|srsltid|toolid|trk_contact|trk_module|trk_msg|trk_sid|ttclid|twclid|utm_[a-z]+|utm_campaign|utm_content|utm_creative_format|utm_id|utm_marketing_tactic|utm_medium|utm_source|utm_source_platform|utm_term|vmcid|wbraid|yclid|zanpid)=") {
        set req.url = regsuball(req.url, "(_branch_match_id|_bta_[a-z]+|_bta_c|_bta_tid|_ga|_gl|_ke|_kx|campid|cof|customid|cx|dclid|dm_i|ef_id|epik|fbclid|gad_source|gbraid|gclid|gclsrc|gdffi|gdfms|gdftrk|hsa_acc|hsa_ad|hsa_cam|hsa_grp|hsa_kw|hsa_mt|hsa_net|hsa_src|hsa_tgt|hsa_ver|ie|igshid|irclickid|matomo_campaign|matomo_cid|matomo_content|matomo_group|matomo_keyword|matomo_medium|matomo_placement|matomo_source|mc_[a-z]+|mc_cid|mc_eid|mkcid|mkevt|mkrid|mkwid|msclkid|mtm_campaign|mtm_cid|mtm_content|mtm_group|mtm_keyword|mtm_medium|mtm_placement|mtm_source|nb_klid|ndclid|origin|pcrid|piwik_campaign|piwik_keyword|piwik_kwd|pk_campaign|pk_keyword|pk_kwd|redirect_log_mongo_id|redirect_mongo_id|rtid|s_kwcid|sb_referer_host|sccid|si|siteurl|sms_click|sms_source|sms_uph|srsltid|toolid|trk_contact|trk_module|trk_msg|trk_sid|ttclid|twclid|utm_[a-z]+|utm_campaign|utm_content|utm_creative_format|utm_id|utm_marketing_tactic|utm_medium|utm_source|utm_source_platform|utm_term|vmcid|wbraid|yclid|zanpid)=[-_A-z0-9+(){}%.*]+&?", "");
        set req.url = regsub(req.url, "[?|&]+$", "");
    }

    # Strip hash, server doesn't need it.
    if (req.url ~ "\#") {
        set req.url = regsub(req.url, "\#.*$", "");
    }

    # Strip a trailing ? if it exists
    if (req.url ~ "\?$") {
        set req.url = regsub(req.url, "\?$", "");
    }

    # Normalize the query arguments
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

    # Only hash cookies for the non static files.
    if (req.url !~ "\.(jpg|jpeg|gif|png|ico|css|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|bmp|rtf|js|flv|swf|html|htm|woff|woff2|svg|webp)(\?.*)?$") {
        # Add the browser cookie only if a WordPress cookie found.
        if (req.http.Cookie ~ "wp-postpass_|wordpress_logged_in_") {
            hash_data(req.http.Cookie);
        }
    } else {
        # hash Based on path only for the static files
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

    # catch obvious reasons we can't cache
    if (beresp.http.Set-Cookie) {
        set beresp.http.X-Cacheable = "NO:Got Cookies";
        set beresp.ttl = 0s;
        return (deliver);
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

    # Light cache for 500 errors (respecting backend headers)
    if (beresp.status >= 500) {
        # Only set a default TTL if backend doesn't provide one
        if (!beresp.http.Cache-Control && beresp.ttl <= 0s) {
            set beresp.ttl = 5m;
        }
        set beresp.http.X-Cacheable = "YES:500";
        set beresp.grace = 1m;
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

    # Debug header
    if(req.http.X-Cacheable) {
        set resp.http.X-Cacheable = req.http.X-Cacheable;
    } elseif(obj.uncacheable) {
        if(!resp.http.X-Cacheable) {
            set resp.http.X-Cacheable = "NO:UNCACHEABLE";
        }
    } elseif(!resp.http.X-Cacheable) {
        set resp.http.X-Cacheable = "YES";
    }

    # Cleanup of headers
    unset resp.http.x-url;
    unset resp.http.x-host;
}

sub vcl_pipe {
     if (req.http.upgrade) {
         set bereq.http.upgrade = req.http.upgrade;
     }
}