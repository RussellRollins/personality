data "google_compute_zones" "available" {}

resource "google_compute_instance" "consul_server" {
  project      = "${var.google_project_id}"
  zone         = "${element(data.google_compute_zones.available.names, count.index)}"
  name         = "consul-server-${count.index + 1}"
  machine_type = "f1-micro"

  count = 3

  boot_disk {
    initialize_params {
      image = "centos-7-v20181011"
    }
  }

  metadata_startup_script = "${file("config/scripts/consul_server_startup.sh")}"

  tags = ["consulserver"]

  network_interface {
    network       = "default"
    access_config = {}
  }

  service_account {
    scopes = ["compute-ro"]
  }
}

resource "google_compute_instance" "nomad_server" {
  project      = "${var.google_project_id}"
  zone         = "${element(data.google_compute_zones.available.names, count.index)}"
  name         = "nomad-server-${count.index + 1}"
  machine_type = "f1-micro"

  count = 3

  boot_disk {
    initialize_params {
      image = "centos-7-v20181011"
    }
  }

  metadata_startup_script = "${file("config/scripts/nomad_server_startup.sh")}"

  tags = ["nomadserver"]

  network_interface {
    network       = "default"
    access_config = {}
  }

  service_account {
    scopes = ["compute-ro"]
  }
}

resource "google_compute_instance" "nomad_client" {
  project      = "${var.google_project_id}"
  zone         = "${element(data.google_compute_zones.available.names, count.index)}"
  name         = "nomad-client-${count.index + 1}"
  machine_type = "n1-standard-1"

  count = 4

  boot_disk {
    initialize_params {
      image = "centos-7-v20181011"
    }
  }

  metadata_startup_script = "${file("config/scripts/nomad_client_startup.sh")}"

  tags = ["nomadclient"]

  network_interface {
    network       = "default"
    access_config = {}
  }

  service_account {
    scopes = ["compute-ro"]
  }
}


output "instance_id" {
  value = "${google_compute_instance.nomad_server.*.self_link[0]}"
}
