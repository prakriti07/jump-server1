resource "google_compute_network" "vpc" {
  name    = "bastion-network"
  project = var.project
  # Always define custom subnetworks- one subnetwork per region isn't useful for an opinionated setup
  auto_create_subnetworks = "false"
  # A global routing mode can have an unexpected impact on load balancers; always use a regional mode
  routing_mode = "REGIONAL"
}

resource "google_compute_router" "vpc_router" {
  name = "bastion-router"
  project = var.project
  region  = var.region
  network = google_compute_network.vpc.self_link
}

# Public Subnetwork Config
resource "google_compute_subnetwork" "vpc_subnetwork_public" {
  name = "bastion-subnetwork-public"
  project = var.project
  region  = var.region
  network = google_compute_network.vpc.self_link
  private_ip_google_access = true
  ip_cidr_range            = cidrsubnet(var.cidr_block, var.cidr_subnetwork_width_delta, 0)
  secondary_ip_range {
    range_name = "public-cluster"
    ip_cidr_range = cidrsubnet(
      var.secondary_cidr_block,
      var.secondary_cidr_subnetwork_width_delta,
      0
    )
  }
  secondary_ip_range {
    range_name = "public-services"
    ip_cidr_range = var.public_services_secondary_cidr_block != null ? var.public_services_secondary_cidr_block : cidrsubnet(
      var.secondary_cidr_block,
      var.secondary_cidr_subnetwork_width_delta,
      1 * (2 + var.secondary_cidr_subnetwork_spacing)
    )
  }
  dynamic "log_config" {
    for_each = var.log_config == null ? [] : tolist([var.log_config])
    content {
      aggregation_interval = var.log_config.aggregation_interval
      flow_sampling        = var.log_config.flow_sampling
      metadata             = var.log_config.metadata
    }
  }
}

resource "google_compute_router_nat" "vpc_nat" {
  name = "bastion-nat"
  project = var.project
  region  = var.region
  router  = google_compute_router.vpc_router.name
  nat_ip_allocate_option = "AUTO_ONLY"
  # "Manually" define the subnetworks for which the NAT is used, so that we can exclude the public subnetwork
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = google_compute_subnetwork.vpc_subnetwork_public.self_link
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

# Private Subnetwork Config
resource "google_compute_subnetwork" "vpc_subnetwork_private" {
  name = "bastion-subnetwork-private"
  project = var.project
  region  = var.region
  network = google_compute_network.vpc.self_link
  private_ip_google_access = true
  ip_cidr_range = cidrsubnet(
    var.cidr_block,
    var.cidr_subnetwork_width_delta,
    1 * (1 + var.cidr_subnetwork_spacing)
  )
  secondary_ip_range {
    range_name = "private-services"
    ip_cidr_range = var.private_services_secondary_cidr_block != null ? var.private_services_secondary_cidr_block : cidrsubnet(
      var.secondary_cidr_block,
      var.secondary_cidr_subnetwork_width_delta,
      1 * (1 + var.secondary_cidr_subnetwork_spacing)
    )
  }
  dynamic "log_config" {
    for_each = var.log_config == null ? [] : tolist([var.log_config])
    content {
      aggregation_interval = var.log_config.aggregation_interval
      flow_sampling        = var.log_config.flow_sampling
      metadata             = var.log_config.metadata
    }
  }
}

# Attach Firewall Rules to allow inbound traffic to tagged instances
module "network_firewall" {
  source = "../network-firewall"
  project                               = var.project
  network                               = google_compute_network.vpc.self_link
  allowed_public_restricted_subnetworks = var.allowed_public_restricted_subnetworks
  public_subnetwork  = google_compute_subnetwork.vpc_subnetwork_public.self_link
  private_subnetwork = google_compute_subnetwork.vpc_subnetwork_private.self_link
}
