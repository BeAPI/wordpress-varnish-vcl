vcl 4.1;

import std;

# Load configs
include "/etc/varnish/conf/acl.vcl";
include "/etc/varnish/conf/backend.vcl";

# Specific elements
include "/etc/varnish/lib/xforward.vcl";
include "/etc/varnish/lib/purge.vcl";
include "/etc/varnish/lib/bigfiles.vcl";
include "/etc/varnish/lib/static.vcl";

# Include the environment vcl
include "/etc/varnish/common.vcl";
