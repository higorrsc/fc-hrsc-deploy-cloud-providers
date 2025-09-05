resource "kubernetes_namespace" "codeflix" {
  metadata {
    name = "codeflix"
  }
  wait_for_default_service_account = true
}

data "aws_secretsmanager_secret_version" "db_secret" {
  secret_id = "DbSecret"
}

data "aws_secretsmanager_secret_version" "rmq_secret" {
  secret_id = "RmqSecret"
}

data "aws_secretsmanager_secret_version" "gcp_secret" {
  secret_id = "GcpSecret"
}

locals {
  db_secret_data  = jsondecode(data.aws_secretsmanager_secret_version.db_secret.secret_string)
  rmq_secret_data = jsondecode(data.aws_secretsmanager_secret_version.rmq_secret.secret_string)
}

resource "kubernetes_secret" "db_k8s_secret" {
  metadata {
    name      = "fc-hrsc-db-secret"
    namespace = "codeflix"
  }

  data = {
    username = local.db_secret_data["username"]
    password = local.db_secret_data["password"]
  }
  depends_on = [kubernetes_namespace.codeflix]
}

resource "kubernetes_secret" "rmq_k8s_secret" {
  metadata {
    name      = "fc-hrsc-rabbitmq-secret"
    namespace = "codeflix"
  }

  data = {
    username = local.rmq_secret_data["username"]
    password = local.rmq_secret_data["password"]
  }
  depends_on = [kubernetes_namespace.codeflix]
}

resource "kubernetes_secret" "gcp_credentials_secret" {
  metadata {
    name      = "gcp-credentials-secret"
    namespace = "codeflix"
  }

  data = {
    "key.json" = data.aws_secretsmanager_secret_version.gcp_secret.secret_string
  }
  depends_on = [kubernetes_namespace.codeflix]
}

resource "helm_release" "keycloak_operator" {
  name             = "keycloak-operator"
  repository       = "https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/main/charts"
  chart            = "keycloak-operator"
  version          = "25.0.1" # Use a specific version for consistency
  namespace        = kubernetes_namespace.codeflix.metadata[0].name
  depends_on       = [kubernetes_namespace.codeflix]
  create_namespace = false
}

resource "helm_release" "rmq_operator" {
  name       = "rabbitmq-cluster-operator"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "rabbitmq-cluster-operator"
  namespace  = "default" # This operator is often installed in the default namespace
  depends_on = [kubernetes_namespace.codeflix]
}

resource "helm_release" "eck" {
  name       = "eck-operator"
  repository = "https://helm.elastic.co"
  chart      = "eck-operator"
  namespace  = "default" # This operator is often installed in the default namespace
  depends_on = [kubernetes_namespace.codeflix]
}
