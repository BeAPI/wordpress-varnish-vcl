sub vcl_recv {

  # Allow purging from ACL
  if (req.method == "PURGE" || req.method == "BAN") {
     # If not allowed then a error 405 is returned
     if (!std.ip(regsub(req.http.X-Forwarded-For, "[, ].*$", ""), "0.0.0.0") ~ purge_acl) {
       return (synth(403, "Forbidden"));
     } else {
       ban("req.http.host == " + req.http.host + " && req.url ~ /");
       return (synth(200,"Purged all caches"));
     }
  }
}