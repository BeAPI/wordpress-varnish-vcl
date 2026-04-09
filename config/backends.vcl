# =============================================================================
# SITE CONFIGURATION — customize for your stack
# =============================================================================
# Point backend1 at your real origin (WordPress / PHP-FPM / reverse proxy).
# Tune timeouts and .probe (.url, intervals) to match how your app responds.
# =============================================================================

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
