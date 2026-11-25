terraform {
  required_providers {
    infisical = { source = "infisical/infisical", version = "~> 0.20" }
  }
  # Local state — single operator. Gitignored (see homekube-main/.gitignore).
}

# Admin identity credentials come from INFISICAL_UNIVERSAL_AUTH_CLIENT_ID / _SECRET.
provider "infisical" {
  host = var.infisical_host
  auth = {
    universal = {}
  }
}
