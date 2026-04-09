# WordPress Varnish VCL

Varnish Cache VCL configuration optimized for WordPress and WooCommerce. The main flow stays in `default.vcl`. **Site-specific settings** (ACL, backends, imgproxy toggle and backend) live under `config/`. **Reusable VCL logic** stays under `vcl/includes/` (do not fork unless you need custom behaviour).

## Features

- **WordPress-aware caching**: Bypass cache for logged-in users, AJAX, auth, and WooCommerce sessions
- **Cookie normalization**: Strips tracking and analytics cookies (GA, WooTracker, etc.) for better hit ratio
- **Purge / BAN**: PURGE and BAN methods restricted by ACL (localhost by default)
- **Static & big files**: Dedicated handling for static assets (Cache-Control respected; 1d default when omitted); large files (>10 MB) delivered uncacheable
- **WebSockets**: Pipe for `Upgrade: websocket` requests
- **Tracking params**: Removes common UTM and campaign query parameters from the cache key
- **Grace & TTL**: Configurable grace period, 500/404 handling, and Cache-Control respect
- **Accept-Encoding normalization**: Reduces cache fragmentation (br > gzip > none)
- **Backend health checks**: Automatic probe to detect backend failures
- **imgproxy** (opt-in): Dedicated backend for WordPress upload images — URLs automatically rewritten to imgproxy format (supports processing params)
- **Security**: HTTPOXY mitigation, debug headers only exposed with `X-Debug` request header

## Requirements

- Varnish Cache 4.x (or compatible)
- Varnish modules: `std`, `directors` (and optionally `xkey` if you use it)

## Structure

```
.
├── default.vcl
├── config/
│   ├── acl.vcl
│   ├── backends.vcl
│   ├── imageproxy-loader.vcl      # enable/disable imgproxy (which includes are loaded)
│   └── imageproxy-backend.vcl     # imgproxy host/port (used when imageproxy is enabled)
├── vcl/
│   └── includes/
│       ├── imageproxy.disabled.vcl
│       └── imageproxy.vcl         # imgproxy routing & URL rewrite logic (not host config)
├── CHANGELOG.md
├── README.md
└── LICENSE
```

## Installation

1. Copy `default.vcl` to your server (e.g. `/etc/varnish/default.vcl`).
2. Edit `config/backends.vcl` and `config/acl.vcl` to match your environment.
3. Start or reload Varnish:

   ```bash
   varnishd -f /etc/varnish/default.vcl
   # or
   varnishreload
   ```

## Configuration

Core configuration is under `config/` and loaded by `default.vcl`:

- **Backend**: Adjust `.host`, `.port`, and `.probe` in `config/backends.vcl` (`backend backend1`).
- **Purge ACL**: Add allowed IPs in `config/acl.vcl` (`acl purge_acl`).
- **Debug**: Send an `X-Debug: 1` request header to see `X-Cacheable` in the response.

### Default TTL when backend has no Cache-Control

By default, when the backend sends **no** `Cache-Control` header, the VCL forces a 1 hour TTL so the response is cached. This avoids uncacheable pages when WordPress (or the backend) omits cache headers.

To **disable** this and only cache responses that explicitly send cache headers (or a positive TTL):

1. In `default.vcl`, in `vcl_backend_response`, find the block `# -- Default TTL when the backend sends no Cache-Control --`.
2. Comment out the entire `if (!beresp.http.Cache-Control) { ... }` block (the three lines inside the `if` and the `if` itself).

After disabling, responses without `Cache-Control` keep `beresp.ttl = 0` and are marked uncacheable by the next block; they will not be stored in the cache.

## imgproxy (optional)

Image processing via [imgproxy](https://imgproxy.net/) is supported but **disabled by default**. When enabled, WordPress upload images (`content/uploads/...`) are routed to a dedicated imgproxy backend and URLs are rewritten to the imgproxy format automatically.

To enable:

1. In `config/imageproxy-loader.vcl`, switch the includes:
   - comment `include "vcl/includes/imageproxy.disabled.vcl";`
   - uncomment `include "config/imageproxy-backend.vcl";` and `include "vcl/includes/imageproxy.vcl";`
2. In `config/imageproxy-backend.vcl`, adjust `.host` and `.port` in `backend imgproxy` to match your imgproxy instance.

This way, you only touch files under `config/` (not `default.vcl`).

Supported image extensions (imgproxy Community): `jpg`, `jpeg`, `png`, `webp`, `gif`, `avif`, `tiff`, `tif`, `bmp`, `ico`, `heic`, `heif`, `svg`.

URL rewriting handles both single-site and multisite WordPress installs, with or without processing parameters:

| Incoming URL | Rewritten URL sent to imgproxy |
|---|---|
| `/content/uploads/2025/10/photo.jpg` | `/insecure/plain/local:///content/uploads/2025/10/photo.jpg` |
| `/rs:fill:500:500/content/uploads/2025/10/photo.jpg` | `/insecure/rs:fill:500:500/plain/local:///content/uploads/2025/10/photo.jpg` |
| `/content/uploads/sites/2/2025/10/photo.jpg` | `/insecure/plain/local:///content/uploads/sites/2/2025/10/photo.jpg` |

## Cache key (hash)

- **Pages**: Protocol (X-Forwarded-Proto), Accept-Encoding (normalized), optional Cookie (when WordPress-related cookies are present), plus default (host, URL, etc.).
- **Static files**: Protocol, Accept-Encoding (normalized), and URL path only (no cookie, **no host** in hash).

### Static files: shared vs per-domain cache

By default, static files are cached **without the host in the hash key**. This means a file at the same path on two different domains shares a single cache entry:

```
domain1.com/app/uploads/photo.jpg  ──┐
                                     ├──> same cache entry
domain2.com/app/uploads/photo.jpg  ──┘
```

This is optimal for **WordPress multisite** setups where uploads are physically shared across domains (same files, same paths).

If your domains serve **different static files at the same path** (e.g. different themes per domain), you need per-domain caching. In `vcl_hash`, find the `else` branch for static files and add `hash_data(req.http.host)`:

```vcl
    } else {
        hash_data(req.url);
        hash_data(req.http.host);
        return (lookup);
    }
```

This change is also documented inline in `default.vcl` (search for "cache static files per domain").

## License

GPL v2. See [LICENSE](LICENSE).

## Author

[BeAPI](https://beapi.fr)
