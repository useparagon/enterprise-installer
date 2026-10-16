# Preserve the existing ingress-nginx Helm release state when introducing count.
# When agc_direct is explicitly enabled, nginx is intentionally removed.
moved {
  from = helm_release.ingress
  to   = helm_release.ingress[0]
}
