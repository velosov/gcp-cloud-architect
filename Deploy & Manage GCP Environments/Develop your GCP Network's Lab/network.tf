terraform {
    required_providers {
        google = {
            source = "hashicorp/google"
            version = "4.53.0"
        }
    }
}

provider "google" {
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}

module "griffin-dev-vpc" {
    source  = "terraform-google-modules/network/google"
    version = "~> 6.0.0"

    project_id   = var.project_id
    network_name = "griffin-dev-vpc"

    subnets = [
        {
            subnet_name           = "griffin-dev-wp"
            subnet_ip             = "192.168.16.0/20"
            subnet_region         = var.region
        },
        {
            subnet_name           = "griffin-dev-mgmt"
            subnet_ip             = "192.168.32.0/20"
            subnet_region         = var.region
        }
    ]
}

module "griffin-prod-vpc" {
    source  = "terraform-google-modules/network/google"
    version = "~> 6.0.0"

    project_id   = var.project_id
    network_name = "griffin-prod-vpc"

    subnets = [
        {
            subnet_name           = "griffin-prod-wp"
            subnet_ip             = "192.168.48.0/20"
            subnet_region         = var.region
        },
        {
            subnet_name           = "griffin-prod-mgmt"
            subnet_ip             = "192.168.64.0/20"
            subnet_region         = var.region
        }
    ]
}

resource "google_compute_firewall" "griffin-firewall" {
  name    = "griffin-firewall"
  network = "projects/qwiklabs-gcp-03-7defe700d041/global/networks/griffin-prod-vpc"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_tags = ["bastion"]
  source_ranges = ["0.0.0.0/0"]
}


resource "google_compute_firewall" "griffin-dev-firewall" {
  name    = "griffin-dev-firewall"
  network = "projects/qwiklabs-gcp-03-7defe700d041/global/networks/griffin-dev-vpc"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_tags = ["bastion"]
  source_ranges = ["0.0.0.0/0"]
}