vcl 4.0;

import std;
import header;

# Load configs
include "/etc/varnish/conf/acl.vcl";
include "/etc/varnish/conf/backend.vcl";

# Specific elements
include "/etc/varnish/lib/xforward.vcl";
include "/etc/varnish/lib/purge.vcl";
include "/etc/lib/bigfiles.vcl";
include "/etc/lib/static.vcl";

# Include the environment vcl
include "/etc/common.vcl";
