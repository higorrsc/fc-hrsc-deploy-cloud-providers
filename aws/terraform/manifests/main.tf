locals {
  db_manifest = yamldecode(file("../../k8s/db.yaml"))
}

resource "kubernetes_manifest" "storageclass" {
  manifest = yamldecode(file("../../k8s/storageclass.yaml"))
}

resource "kubernetes_manifest" "db" {
  manifest = merge(local.db_manifest, {
    "spec" = {
      "template" = {
        "spec" = {
          "containers" = [for c in local.db_manifest.spec.template.spec.containers :
            merge(c, { "env" = [for e in c.env : e.name == "MYSQL_ROOT_PASSWORD" ? merge(e, { "valueFrom" = { "secretKeyRef" = { "name" = "fc-hrsc-db-secret" } } }) : e] })
          ]
        }
      }
    }
  })

  wait {
    fields = {
      "status.readyReplicas" = "1"
    }
  }

  timeouts {
    create = "2m"
    update = "2m"
    delete = "30s"
  }
}

resource "kubernetes_manifest" "db-service" {
  manifest = yamldecode(file("../../k8s/db-service.yaml"))
}

resource "kubernetes_manifest" "keycloak" {
  manifest   = yamldecode(file("../../k8s/keycloak.yaml"))
  depends_on = [kubernetes_manifest.db]
}

resource "kubernetes_manifest" "keycloak_import" {
  manifest        = yamldecode(file("../../k8s/keycloak-import.yaml"))
  computed_fields = ["spec.realm.roles", "spec.realm.components"]
  depends_on      = [kubernetes_manifest.keycloak]
}

resource "kubernetes_manifest" "rmq" {
  manifest = yamldecode(file("../../k8s/rabbitmq.yaml"))
  wait {
    fields = {
      "status.conditions[3].reason" = "Success"
    }
  }

  timeouts {
    create = "2m"
    update = "2m"
    delete = "30s"
  }
}

resource "kubernetes_manifest" "rmq_topology" {
  manifest   = yamldecode(file("../../k8s/rabbitmq-topology.yaml"))
  depends_on = [kubernetes_manifest.rmq]
  # This resource creates multiple objects. A simple wait might not be sufficient.
  # Consider breaking this into separate resources if more granular control is needed.
}

data "kubernetes_secret" "db_secret" {
  metadata {
    name      = "fc-hrsc-db-secret"
    namespace = "codeflix"
  }
  depends_on = [
    data.terraform_remote_state.crds # Ensure CRDs module which creates the secret has run
  ]
}

resource "kubernetes_deployment" "admin_catalog" {
  metadata {
    name      = "fc-hrsc-admin-catalog"
    namespace = "codeflix"
    labels = {
      app = "admin-catalog"
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "admin-catalog"
      }
    }
    template {
      metadata {
        labels = {
          app                = "admin-catalog"
          filebeat_collector = "true"
        }
      }
      spec {
        container {
          name  = "admin-catalog"
          image = "igorgomes96/fc3-admin-catalogo-de-videos-c-sharp:latest"
          env {
            name  = "ASPNETCORE_ENVIRONMENT"
            value = "Development"
          }
          env {
            name  = "ConnectionStrings__CatalogDb"
            value = "Server=fc-hrsc-mysql-0.fc-hrsc-mysql-h.codeflix.svc.cluster.local;Port=3306;Database=catalog;Uid=${data.kubernetes_secret.db_secret.data.username};Pwd=${data.kubernetes_secret.db_secret.data.password};"
          }
          env {
            name  = "RabbitMQ__Hostname"
            value = "fc-hrsc-rabbitmq.codeflix.svc.cluster.local"
          }
          env {
            name  = "Keycloak__auth-server-url"
            value = "http://${kubernetes_manifest.ingress.manifest.status.load_balancer.ingress[0].hostname}"
          }
          env {
            name  = "Storage__BucketName"
            value = "fc3-medias-catalog-admin"
          }
          env {
            name  = "GOOGLE_APPLICATION_CREDENTIALS"
            value = "/app/gcp_credentials/key.json"
          }
          volume_mount {
            name       = "gcp-credentials-volume"
            mount_path = "/app/gcp_credentials"
            read_only  = true
          }
        }
        volume {
          name = "gcp-credentials-volume"
          secret {
            secret_name = "gcp-credentials-secret"
          }
        }
      }
    }
  }
  depends_on = [kubernetes_manifest.rmq_topology, kubernetes_manifest.ingress]
}

resource "kubernetes_manifest" "admin_catalog_service" {
  manifest = yamldecode(file("../../k8s/admin-catalog-service.yaml"))
}

resource "kubernetes_manifest" "elasticsearch" {
  manifest        = yamldecode(file("../../k8s/elasticsearch.yaml"))
  computed_fields = ["spec.nodeSets"]
}

resource "kubernetes_manifest" "beats_rbac" {
  manifest = yamldecode(file("../../k8s/beats-rbac.yaml"))
}

resource "kubernetes_manifest" "beats" {
  manifest = yamldecode(file("../../k8s/beats.yaml"))
  field_manager {
    force_conflicts = true
  }
  depends_on = [kubernetes_manifest.beats_rbac, kubernetes_manifest.elasticsearch]
}

resource "kubernetes_manifest" "kibana" {
  manifest = yamldecode(file("../../k8s/kibana.yaml"))
  field_manager {
    force_conflicts = true
  }
  depends_on = [kubernetes_manifest.elasticsearch]

}

resource "kubernetes_manifest" "front_admin_catalog" {
  manifest = yamldecode(file("../../k8s/front.yaml"))
  wait {
    rollout = true
  }

  timeouts {
    create = "2m"
    update = "2m"
    delete = "30s"
  }

  depends_on = [kubernetes_deployment.admin_catalog]
}

resource "kubernetes_manifest" "front_admin_catalog_service" {
  manifest = yamldecode(file("../../k8s/front-service.yaml"))
}

resource "kubernetes_manifest" "ingress" {
  manifest   = yamldecode(file("../../k8s/ingress.yaml"))
  depends_on = [kubernetes_manifest.admin_catalog_service]
}
