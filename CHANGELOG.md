# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Single-file VCL: all logic merged into `default.vcl` (removed `common.vcl`, `conf/`, `lib/`)
- WordPress-specific cache rules (cookies, AJAX, auth, WooCommerce)
- Purge/BAN support with ACL
- Static and big files handling
- WebSockets pipe support
- Tracking parameter stripping (UTM, fbclid, gclid, etc.)
- Grace period and 500/404 caching behavior
- README, CHANGELOG, and GPL v2 license

### Changed

- **Accept-Encoding normalization**: Normalize to `br`, `gzip`, or unset in `vcl_recv` to reduce cache fragmentation
- **Product pages**: Remove overly broad `^/product` bypass — product pages are now cacheable (add-to-cart actions remain excluded)
- **5xx caching**: Reduce TTL from 5m to 1m and grace from 1m to 30s to avoid masking persistent backend failures
- **Debug headers**: `X-Cacheable` is now only returned when the request includes an `X-Debug` header (no longer leaks cache info in production)
- **Backend health check**: Add `.probe` to backend definition for automatic health monitoring
- **Backend timeouts**: Explicit `.first_byte_timeout` (300s), `.connect_timeout` (5s), `.between_bytes_timeout` (2s)
- **Big files streaming**: Enable `do_stream` for files > 10 MB so Varnish does not buffer them entirely in memory
- **Redirect port fix**: Strip backend port from `Location` header on 301/302 responses
- **Vary: \***: Treat `Vary: *` backend responses as uncacheable
- **Debug X-Cache**: Add `X-Cache: HIT/MISS` and `X-Cache-Hits` headers when `X-Debug` is present
- **Purge ACL fallback**: Use `client.ip` instead of `0.0.0.0` as fallback when `X-Forwarded-For` is absent (works without a fronting proxy)

### Deprecated

- (none)

### Removed

- **`import header`**: Removed unused `header` vmod import
- **Multi-file structure**: Merged `common.vcl`, `conf/acl.vcl`, `conf/backend.vcl`, `lib/xforward.vcl`, `lib/purge.vcl`, `lib/bigfiles.vcl`, and `lib/static.vcl` into a single `default.vcl`

### Fixed

- **Hash for static files**: Include `X-Forwarded-Proto` and `Accept-Encoding` in cache key so HTTP/HTTPS and gzip/br variants are stored separately
- **Cookie handling**: Only run cookie-stripping when `Cookie` header is present to avoid sending an empty Cookie header to the backend
- **Purge comment**: Corrected comment (403 Forbidden instead of 405)
- **Tracking params**: Removed `origin` from stripped query params to avoid breaking APIs/CORS usage
- **Tracking params regex**: Fixed `A-z` character class to `A-Za-z` (was matching unintended characters `[\]^_\``)
- **bigfiles_pipe.vcl**: Removed (was Varnish 3-only, unused; large files are handled by `bigfiles.vcl` as uncacheable)

### Security

- HTTPOXY mitigation (`unset req.http.proxy`)
- Purge restricted to configured ACL
- Debug headers (`X-Cacheable`) no longer exposed by default in production responses
