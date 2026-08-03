resource "kubernetes_service_account" "hoop_cluster_admin" {
  metadata {
    name      = "hoop-cluster-admin"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/service-account.name" = "hoop-cluster-admin"
    }
  }

  depends_on = [helm_release.hoopagent]
}

resource "kubernetes_cluster_role_binding" "hoop_cluster_admin" {
  metadata {
    name = "hoop-cluster-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.hoop_cluster_admin.metadata[0].name
    namespace = var.namespace
  }
}

resource "kubernetes_secret" "hoop_cluster_admin_token" {
  metadata {
    name      = "hoop-cluster-admin-token"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/service-account.name" = "hoop-cluster-admin"
    }
  }

  type = "kubernetes.io/service-account-token"

  depends_on = [kubernetes_service_account.hoop_cluster_admin]
}

resource "time_sleep" "wait_for_hoop_tokens" {
  create_duration = "30s"

  depends_on = [kubernetes_secret.hoop_cluster_admin_token]
}

data "kubernetes_secret" "hoop_cluster_admin_token" {
  metadata {
    name      = kubernetes_secret.hoop_cluster_admin_token.metadata[0].name
    namespace = var.namespace
  }

  depends_on = [time_sleep.wait_for_hoop_tokens]
}
