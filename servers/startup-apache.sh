#!/bin/bash
export INSTANCE_ID=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .instanceId)

adduser consul
usermod -a -G systemd-journal consul
echo 'consul ALL=(ALL:ALL) NOPASSWD: ALL' | sudo EDITOR='tee -a' visudo

yum update
yum install -y httpd
service httpd start

curl --silent -Lo /tmp/consul.zip https://releases.hashicorp.com/consul/${consul_version}/consul_${consul_version}_linux_amd64.zip
unzip /tmp/consul.zip
mv consul /usr/bin
rm -f /tmp/consul.zip

mkdir -p /opt/consul/data/
chown -R consul:consul /opt/consul/data

mkdir /etc/consul.d/
echo -e "CONSUL_LICENSE=${consul_license}" > /etc/consul.d/env
chown -R consul:consul /etc/consul.d/

# Copy .ssh keys from ec2-user to consul user so you can ssh
# into the ec2 instance as consul.
mkdir -p /home/consul/.ssh
cat /home/ec2-user/.ssh/authorized_keys > /home/consul/.ssh/authorized_keys
chown -R consul:consul /home/consul/.ssh
chmod 700 /home/consul/.ssh
chmod 600 /home/consul/.ssh/authorized_keys

cat > /etc/systemd/system/consul.service << EOF
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul.d/agent.hcl

[Service]
Type=notify
User=consul
Group=consul
EnvironmentFile=/etc/consul.d/env
ExecStart=/usr/bin/consul agent -config-dir=/etc/consul.d/
ExecReload=/usr/bin/consul reload
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/consul.d/agent.hcl << EOF
log_level  = "INFO"
server     = false
datacenter = "consul-dc-a"
primary_datacenter = "consul-dc-a"
node_name="apache-$INSTANCE_ID"

ui_config {
  enabled = true
}

# Gossip Encryption - generate key using consul keygen
encrypt            = "pCOEKgL2SYHmDoFJqnolFUTJi7Vy+Qwyry04WIZUupc="
data_dir           = "/opt/consul/data"

# Agent Network Configuration
client_addr    = "0.0.0.0"
bind_addr      = "0.0.0.0"
advertise_addr = "{{ GetPublicIP }}"

retry_join = ["provider=aws tag_key=consul tag_value=join region=us-west-2"]

connect {
  enabled = true
}

acl {
  enabled = true
  default_policy = "allow"
  down_policy = "extend-cache"
}
EOF

cat > /etc/consul.d/service.hcl << EOF
node_name = "$INSTANCE_ID"
service {
    name = "web-server-$INSTANCE_ID"
    tags = ["prod", "webapp", "$INSTANCE_ID"]
    port = 80
    check = {
        id = "web"
        name = "Check web on port 80"
        tcp = "localhost:80"
        interval = "10s"
        timeout = "1s"
    }
}
EOF

# Create bash helper commands
cat > /etc/profile.d/consul.sh << EOF
export PS1="\[\033[0;31m\]\u@\[\033[0m\]$INSTANCE_ID "
alias nukeconsul="sudo rm -rf /opt/consul/*"
alias cl="journalctl -fu consul"
alias pc="cat /etc/consul.d/config.hcl"
alias vc="sudo vim /etc/consul.d/config.hcl"
EOF

systemctl start consul