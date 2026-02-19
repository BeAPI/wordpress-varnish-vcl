# WordPress Varnish VCL

Varnish Cache VCL configuration optimized for WordPress and WooCommerce. Handles cache rules, purge, static files, and common WordPress cookies/headers.

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
├── default.vcl      # Main entry, includes config and libs
├── common.vcl       # WordPress-specific recv/hash/backend_response/deliver/pipe
├── conf/
│   ├── acl.vcl      # Purge ACL (localhost, 127.0.0.1, ::1)
│   └── backend.vcl  # Backend definition(s)
└── lib/
    ├── xforward.vcl # X-Forwarded-* handling
    ├── purge.vcl    # PURGE/BAN logic
    ├── static.vcl   # Static file handling
    ├── bigfiles.vcl
```

## Installation

1. Clone or copy this repo to your server (e.g. `/etc/varnish/`).
2. Adjust `default.vcl` include paths if needed (defaults assume `/etc/varnish/`).
3. Edit `conf/backend.vcl` with your WordPress backend host/port.
4. Edit `conf/acl.vcl` to allow PURGE/BAN from your purge origin (e.g. WordPress server IP).
5. Start or reload Varnish with this VCL:

   ```bash
   varnishd -f /etc/varnish/default.vcl
   # or
   varnishreload
   ```

## Configuration

- **Backend**: Set in `conf/backend.vcl`.
- **Health check**: Adjust the `.probe` in `conf/backend.vcl` to match your backend (Host header, path, intervals).
- **Purge ACL**: Add allowed IPs in `conf/acl.vcl` for PURGE/BAN.
- **Debug**: Send an `X-Debug: 1` request header to see `X-Cacheable` in the response.
- **Paths**: If you don't use `/etc/varnish/`, update every `include` in `default.vcl`.

## Cache key (hash)

- **Pages**: Protocol (X-Forwarded-Proto), Accept-Encoding (normalized), optional Cookie (when WordPress-related cookies are present), plus default (host, URL, etc.).
- **Static files**: Protocol, Accept-Encoding (normalized), and URL path only (no cookie in hash).

## License

GPL v2. See [LICENSE](LICENSE).

## Author

[BeAPI](https://beapi.fr)
