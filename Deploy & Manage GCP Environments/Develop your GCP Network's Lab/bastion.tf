resource "google_compute_instance" "griffin-bastion" {
  project      = var.project_id
  name         = "griffin-bastion"
  machine_type = "e2-medium"
  tags = ["bastion"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = module.griffin-dev-vpc.network_name
    access_config {
    }
    subnetwork  = "projects/qwiklabs-gcp-03-7defe700d041/regions/var.region/subnetworks/griffin-dev-mgmt"
  }

  network_interface {
    network = module.griffin-prod-vpc.network_name
    access_config {
    }
    subnetwork  = "projects/qwiklabs-gcp-03-7defe700d041/regions/var.region/subnetworks/griffin-prod-mgmt"
  }

}
