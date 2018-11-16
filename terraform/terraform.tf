variable "google_creds_file" {}
variable "google_project_id" {}

variable "google_region" {
  default = "us-east1"
}

provider "google" {
  credentials = "${file(var.google_creds_file)}"
  project     = "${var.google_project_id}"
  region      = "${var.google_region}"
}
