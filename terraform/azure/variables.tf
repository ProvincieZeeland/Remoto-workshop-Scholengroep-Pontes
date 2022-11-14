variable "azure_rg_location" {
  type    = string
  default = "westeurope"
}

variable "azure_rg_name" {
  type    = string
  default = "remoto"
}
variable "ssh_pubkey" {
  type = string
}
variable "image_control" {
  type    = string
  default = "ghcr.io/timvosch/remoto:1.0"
}
variable "image_guacd" {
  type    = string
  default = "docker.io/guacamole/guacd:1.4.0"
}
variable "shared_image_sandbox_name" {
  type    = string
}
variable "shared_image_sandbox_gallery_name" {
  type    = string
}
variable "shared_image_sandbox_resource_group_name" {
  type    = string
}
variable "remoto_workshop_code" {
  type    = string
  default = "demo"
}
variable "remoto_admin_code" {
  type    = string
  default = "admin"
}
variable "remoto_sandbox_count" {
  type    = number
  default = 5
}
