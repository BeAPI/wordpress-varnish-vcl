# WordPress Varnish VCL

Varnish Cache VCL configuration optimized for WordPress and WooCommerce. Everything lives in a single `default.vcl` file for simplicity.

## Features

- **WordPress-aware caching**: Bypass cache for logged-in users, AJAX, auth, and WooCommerce sessions
- **Cookie normalization**: Strips tracking and analytics cookies (GA, WooTracker, etc.) for better hit ratio
- **Purge / BAN**: PURGE and BAN methods restricted by ACL (localhost by default)
- **Static & big files**: Dedicated handling for static assets; large files (>10 MB) delivered uncacheable
- **WebSockets**: Pipe for `Upgrade: websocket` requests
- **Tracking params**: Removes common UTM and campaign query parameters from the cache key
- **Grace & TTL**: Configurable grace period, 500/404 handling, and Cache-Control respect
- **Accept-Encoding normalization**: Reduces cache fragmentation (br > gzip > none)
- **Backend health checks**: Automatic probe to detect backend failures
- **Security**: HTTPOXY mitigation, debug headers only exposed with `X-Debug` request header

## Requirements

- Varnish Cache 4.x (or compatible)
- Varnish modules: `std`, `directors` (and optionally `xkey` if you use it)

## Structure

```
.
├── default.vcl      # Single-file VCL: ACL, backend, recv, hash, backend_response, deliver, pipe
├── CHANGELOG.md
├── README.md
└── LICENSE
```

## Installation

1. Copy `default.vcl` to your server (e.g. `/etc/varnish/default.vcl`).
2. Edit the `backend` and `acl purge_acl` sections at the top of the file to match your environment.
3. Start or reload Varnish:

   ```bash
   varnishd -f /etc/varnish/default.vcl
   # or
   varnishreload
   ```

## Configuration

All configuration is at the top of `default.vcl`:

- **Backend**: Adjust `.host`, `.port`, and `.probe` in the `backend backend1` block.
- **Purge ACL**: Add allowed IPs in the `acl purge_acl` block for PURGE/BAN.
- **Debug**: Send an `X-Debug: 1` request header to see `X-Cacheable` in the response.

## Cache key (hash)

- **Pages**: Protocol (X-Forwarded-Proto), Accept-Encoding (normalized), optional Cookie (when WordPress-related cookies are present), plus default (host, URL, etc.).
- **Static files**: Protocol, Accept-Encoding (normalized), and URL path only (no cookie in hash).

## License

GPL v2. See [LICENSE](LICENSE).

## Author

[BeAPI](https://beapi.fr)
