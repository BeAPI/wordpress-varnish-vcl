# =============================================================================
# SITE CONFIGURATION — customize for your stack
# =============================================================================
# This file is not generic defaults: adjust purge_acl entries to match which
# IPs or networks may issue PURGE/BAN (e.g. WordPress admin hosts, cache
# plugins, orchestration). Wrong entries weaken security or break purging.
# =============================================================================

acl purge_acl {
    "localhost";
    "127.0.0.1";
    "::1";
}
