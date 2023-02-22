output "public_ip_bastion_host" {
  description = "The public IP of the bastion host."
  value       = google_compute_instance.bastion_host.network_interface[0].access_config[0].nat_ip
}

output "private_ip_instance" {
  description = "Private IP of the private instance"
  value       = google_compute_instance.private.network_interface[0].network_ip
}
