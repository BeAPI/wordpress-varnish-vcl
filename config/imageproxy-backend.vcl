# =============================================================================
# SITE CONFIGURATION — customize for your stack
# =============================================================================
# Loaded only when imgproxy is enabled in config/imageproxy-loader.vcl.
# Set .host / .port (and .probe) to your imgproxy service. Defaults are
# placeholders for local development.
# =============================================================================

backend imgproxy {
    .host = "127.0.0.1";
    .port = "8089";
    .first_byte_timeout = 60s;
    .connect_timeout    = 5s;
    .between_bytes_timeout = 2s;
    .probe = {
        .url = "/health";
        .interval = 10s;
        .timeout = 5s;
        .window = 5;
        .threshold = 3;
    }
}
