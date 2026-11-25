variable "infisical_host" {
  description = "Infisical API base URL; the default is a kubectl port-forward to the HTTP backend"
  type        = string
  default     = "http://localhost:8080"
}

variable "org_id" {
  description = "Infisical organization ID (Organization Settings → General)"
  type        = string
}

variable "kubernetes_ca_certificate" {
  description = "PEM of the cluster CA, from the kube-root-ca.crt ConfigMap"
  type        = string
}
