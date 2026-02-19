# xforward.vcl -- X-Forwarded-For HTTP Headers

# This should generally be loaded first to make sure that the headers
# get set appropriately for all requests.  Note that when using this
# you MUST NOT fall through to the VCL default handler for vcl_recv
# since that will run the code again, resulting in the client.ip
# being added twice.

sub vcl_recv {
  # Keep only the first (client) IP when behind a trusted proxy (e.g. haproxy). Only set when present to avoid adding an empty header.
  if (req.http.X-Forwarded-For) {
    set req.http.X-Forwarded-For = regsub(req.http.X-Forwarded-For, "^([^,]+).*", "\1");
  }
}
