variable "project_id" {
  description = "The ID of the project in which to provision resources."
  type        = string
  default     = "qwiklabs-gcp-03-9af11be5f50f"
}

variable "region" {
  description = "Project GCP region."
  type        = string
  default     = "us-east1"
}

variable "zone" {
  description = "Project GCP zone."
  type        = string
  default     = "us-east1-d"
}