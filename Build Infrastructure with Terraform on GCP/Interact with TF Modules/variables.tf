variable "project_id" {
  description = "The ID of the project in which to provision resources."
  type        = string
  default     = "qwiklabs-gcp-03-2e8ed03b0dfb"

}

variable "name" {
  description = "Name of the buckets to create."
  type        = string
  default     = "qwiklabs-gcp-03-2e8ed03b0dfbucket"
}