

# Set up express
sudo yum update
sudo yum upgrade
sudo yum install -y nodejs
mkdir my-express-app
cd my-express-app
npm init -y
npm install express --save
cat > index.js << EOF
const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
  res.send('Hello, Express!');
});

app.listen(port, () => {
  console.log(\`Server running on port \${port}\`);
});
EOF
nohup node index.js > app.log 2>&1 &

# Set up Consul
cat > /etc/consul.d/agent.hcl << EOF
log_level  = "INFO"
server     = false
datacenter = "consul-dc-a"
primary_datacenter = "consul-dc-a"
node_name="express-i-08567e8524d90b2c3"
leave_on_terminate = true

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

cat > service-register-payload.json << EOF
{
    "ID": "i-08567e8524d90b2c3",
    "name": "express-server-i-08567e8524d90b2c3",
    "tags": ["api-register", "express"],
    "port": 3000
}
EOF

curl \
    --request PUT \
    --data @service-register-payload.json \
    10.0.1.219:8500/v1/agent/service/register

# Register an Express Service via API

# Register via CLI

# Register via Configuration