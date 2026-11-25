locals {
  apps = {
    homepage = { namespace = "homepage", service_account = "infisical-auth" }
  }
}

resource "infisical_project" "app" {
  for_each = local.apps

  name                       = each.key
  slug                       = each.key
  should_create_default_envs = false
  has_delete_protection      = true
}

resource "infisical_project_environment" "prod" {
  for_each = local.apps

  project_id = infisical_project.app[each.key].id
  name       = "Production"
  slug       = "prod"
  position   = 1
}

resource "infisical_identity" "app" {
  for_each = local.apps

  name   = each.key
  org_id = var.org_id
  role   = "no-access"
}

# Client's service account needs system:auth-delegator.
resource "infisical_identity_kubernetes_auth" "app" {
  for_each = local.apps

  identity_id                   = infisical_identity.app[each.key].id
  kubernetes_host               = "https://kubernetes.default.svc.cluster.local"
  kubernetes_ca_certificate     = var.kubernetes_ca_certificate
  token_reviewer_mode           = "api"
  allowed_namespaces            = [each.value.namespace]
  allowed_service_account_names = [each.value.service_account]
}

resource "infisical_project_identity" "app" {
  for_each = local.apps

  project_id  = infisical_project.app[each.key].id
  identity_id = infisical_identity.app[each.key].id
  roles = [
    { role_slug = "viewer" }
  ]
}
