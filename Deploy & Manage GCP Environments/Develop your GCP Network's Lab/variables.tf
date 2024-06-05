variable "project_id" {
  description = "The ID of the project in which to provision resources."
  type        = string
  default     = "qwiklabs-gcp-03-7defe700d041"
}

variable "team" {
  type        = string
  default     = "griffin"
}

variable "region" {
  description = "Project GCP region."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Project GCP zone."
  type        = string
  default     = "us-central1-c"
}