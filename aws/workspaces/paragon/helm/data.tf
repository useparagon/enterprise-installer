data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

# Stable apply-time gate for the ALB lookup. Helm release *names* are known at
# plan and do not change on chart upgrades, so this resource is created once and
# then has no planned action. Depending on helm_release itself would defer
# data.aws_lb whenever those releases update (chart hashes, values, etc.), which
# makes dns_name / arn_suffix "(known after apply)" and floods Route53 / Grafana
# plans with false in-place updates.
resource "terraform_data" "alb_lookup_gate" {
  input = {
    ingress = helm_release.ingress.name
    logging = helm_release.paragon_logging.name
    onprem  = helm_release.paragon_on_prem.name
  }
}

data "aws_lb" "load_balancer" {
  name = var.workspace

  # Wait until the controller and the charts that create Ingress objects exist
  # (first apply). Do not depend on the helm_release resources directly.
  depends_on = [terraform_data.alb_lookup_gate]
}
