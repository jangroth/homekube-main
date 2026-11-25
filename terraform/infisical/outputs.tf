output "identity_ids" {
  description = "Machine identity ID per app, for its InfisicalSecret's kubernetesAuth.identityId"
  value       = { for app, identity in infisical_identity.app : app => identity.id }
}

output "project_slugs" {
  description = "Project slug per app, for its InfisicalSecret's secretsScope.projectSlug"
  value       = { for app, project in infisical_project.app : app => project.slug }
}
