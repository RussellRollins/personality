#!/bin/bash
set -euo pipefail

# install some needed packages, most importantly, haproxy + dnsmasq
sudo yum install --assumeyes unzip dnsmasq centos-release-scl
sudo yum install --assumeyes rh-haproxy18-haproxy rh-haproxy18-haproxy-syspaths

curl -o "/tmp/consul.zip" "https://releases.hashicorp.com/consul/1.3.0/consul_1.3.0_linux_amd64.zip"
unzip "/tmp/consul.zip" -d "/usr/local/bin/"

curl -o "/tmp/consul-template.zip" "https://releases.hashicorp.com/consul-template/0.19.5/consul-template_0.19.5_linux_amd64.zip"
unzip "/tmp/consul-template.zip" -d "/usr/local/bin/"

sudo chown root:root "/usr/local/bin/consul"
sudo chown root:root "/usr/local/bin/consul-template"

# create a non-priveledge user to run consul, and some directories it needs.
sudo useradd --system --home /etc/consul.d --shell /bin/false consul
sudo mkdir --parents /opt/consul
sudo mkdir --parents /etc/consul.d

# create a non-priveledge user to run consul-template, and some directories it needs.
sudo useradd --system --home /etc/consul-template.d --shell /bin/false consul-template
sudo mkdir --parents /opt/consul-template
sudo mkdir --parents /etc/consul-template.d

# Add files to those directories, and make sure consul owns them
sudo chown --recursive consul:consul /etc/consul.d
sudo chown --recursive consul:consul /opt/consul

# Add files to those directories, and make sure consul-template owns them
# TODO: consul-template doesn't own haproxy.cfg, so they can't write it :(
cat <<EOF > /etc/haproxy/haproxy.ctmpl
global
  daemon
  maxconn 10000
  description HAProxy / consul demo

resolvers consul
  nameserver consul 127.0.0.1:8600
  accepted_payload_size 8192

defaults
  log global
  option httplog
  option socket-stats
  load-server-state-from-file global
  default-server init-addr none inter 1s rise 2 fall 2
  mode http
  timeout connect 10s
  timeout client 300s
  timeout server 300

frontend http-in
  bind *:80
  maxconn 10000
  use_backend b_%[req.hdr(Host),lower,word(1,:)]

{{range services}}{{\$servicename := .Name}}
backend b_{{\$servicename}}.testamjig.example
  server-template {{\$servicename}} 10 _{{\$servicename}}._tcp.service.consul resolvers consul resolve-prefer ipv4 check
{{end}}
EOF

cat <<EOF > /etc/consul-template.d/consul-template.hcl
# This template will render haproxy config from a template.
template {
  source      = "/etc/haproxy/haproxy.ctmpl"
  destination = "/etc/haproxy/haproxy.cfg"

  command         = "service rh-haproxy18-haproxy.service restart"
  command_timeout = "60s"
  backup          = true

  wait {
    min = "5s"
  }
}
EOF

sudo chown --recursive consul-template:consul-template /etc/consul-template.d
sudo chown --recursive consul-template:consul-template /opt/consul-template
sudo chown --recursive consul-template:consul-template /etc/haproxy

# Create the systemd unit files for the consul service
cat <<EOF > /etc/systemd/system/consul.service
[Unit]
Description=consul

[Service]
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d -data-dir=/etc/consul.d -retry-join "provider=gce tag_value=consulserver" 
[Install]
WantedBy=multi-user.target
EOF

# Enable & Start the service.
systemctl enable consul.service
systemctl start consul.service

# Create the systemd unit files for the consul-template service
cat <<EOF > /etc/systemd/system/consul-template.service
[Unit]
Description=consul-template
Requires=network-online.target
After=network-online.target consul.service

[Service]
User=consul-template
Group=consul-template
Restart=on-failure
KillSignal=SIGINT
ExecStart=/usr/local/bin/consul-template -config=/etc/consul-template.d

[Install]
WantedBy=multi-user.target
EOF

# Enable & Start the service.
systemctl enable consul-template.service
systemctl start consul-template.service

# Configure dnsmasq
cat <<EOF > /etc/dnsmasq.d/10-consul
# Enable forward lookup of the 'consul' domain:
server=/consul/127.0.0.1#8600
EOF

# Configure resolv.conf to check dnsmasq first (dnsmasq knows to ignore this!)
sed -i '/nameserver/i nameserver 127.0.0.1' /etc/resolv.conf

# Enable & Start the service.
systemctl enable dnsmasq
systemctl start dnsmasq
