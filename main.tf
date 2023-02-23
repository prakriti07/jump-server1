terraform {
  required_version = ">= 0.12.26"
}

# Create a Management Network for shared services
module "management_network" {
  source = "./modules/vpc-network"
  project     = var.project
  region      = var.region
}

# Create an instance with OS Login configured to use as a bastion host
resource "google_compute_instance" "bastion_host" {
  project      = var.project
  name         = "bastion-vm"
  machine_type = "t2a-standard-1"
  zone         = var.zone
  tags = ["public"]
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts-arm64"
    }
  }
  network_interface {
    subnetwork = module.management_network.public_subnetwork
    // If var.static_ip is set use that IP, otherwise this will generate an ephemeral IP
    access_config {
      nat_ip = var.static_ip
    }
  }
  metadata = {
    enable-oslogin = "TRUE"
  }
}
# Create a private instance to use alongside the bastion host.
resource "google_compute_instance" "private" {
  project = var.project
  name         = "bastion-private"
  machine_type = "t2a-standard-1"
  zone         = var.zone
  allow_stopping_for_update = true
  tags = ["private"]
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts-arm64"
    }
  }
  network_interface {
    subnetwork = module.management_network.private_subnetwork
  }
  metadata = {
    enable-oslogin = "TRUE"
  }
}
