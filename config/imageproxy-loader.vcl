# =============================================================================
# SITE CONFIGURATION — customize for your stack
# =============================================================================
# Toggle imgproxy integration: choose one path below. Defaults keep imgproxy
# off; enable it only if your stack runs imgproxy and you load
# config/imageproxy-backend.vcl with correct host/port.
# =============================================================================
#
# Imageproxy module toggle:
# - default: disabled (no-op subs; no imgproxy backend)
# - enable: comment disabled include, uncomment backend + logic includes
include "vcl/includes/imageproxy.disabled.vcl";
# include "config/imageproxy-backend.vcl";
# include "vcl/includes/imageproxy.vcl";
