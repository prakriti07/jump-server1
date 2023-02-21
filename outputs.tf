output "address" {
  description = "The public IP of the bastion host."
  value       = google_compute_instance.bastion_host.network_interface[0].access_config[0].nat_ip
}

output "private_instance" {
  description = "A reference (self_link) to the private instance"
  value       = google_compute_instance.private.self_link
}
