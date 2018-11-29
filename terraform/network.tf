resource "google_compute_instance_template" "haproxy" {
  name_prefix = "haproxy-template-"
  description = "This template is used to create app haproxy instances."

  tags = ["haproxy"]

  instance_description = "haproxy-pool instance"
  machine_type         = "f1-micro"

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  // Create a new boot disk from an image
  disk {
    source_image = "centos-7-v20181011"
    auto_delete  = true
    boot         = true
  }

  metadata_startup_script = "${file("config/scripts/haproxy_startup.sh")}"

  network_interface {
    network       = "default"
    access_config = {}
  }

  service_account {
    scopes = ["compute-ro"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_instance_group_manager" "haproxy" {
  name = "haproxy-igm"

  base_instance_name = "haproxy"
  instance_template  = "${google_compute_instance_template.haproxy.self_link}"
  region             = "${var.google_region}"

  # TODO: After assuring that this works, scale down to just 1, its SPOF is okay for this playground
  target_size = 3
} 

resource "google_compute_backend_service" "haproxy" {
  name        = "haproxy-pool"
  description = "Runs HAProxy"
  port_name   = "http"
  protocol    = "HTTP"
  timeout_sec = 10

  backend {
    group = "${google_compute_region_instance_group_manager.haproxy.instance_group}"
  }

  health_checks = ["${google_compute_health_check.haproxy.self_link}"]
}


resource "google_compute_health_check" "haproxy" {
  name                = "haproxy-health-check"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 10                         # 50 seconds

  http_health_check {
    request_path = "/healthz"
    port         = "8080"
  }
}
