# Register a service
cat > service-register-payload.json << EOF 
{   
    "id": "i-093367e3e17c3d9a1",
    "name": "express-server-i-093367e3e17c3d9a1",
    "tags": ["api-register", "express"],
    "port": 3000,
    "check": {
      "name": "Express Server Available on Port 3000",
      "interval": "10s",
      "timeout": "2s",
      "tcp": "localhost:3000"
    }
}
EOF

curl \
    --request PUT \
    --data @service-register-payload.json \
    $CONSUL_HTTP_ADDR/v1/agent/service/register


# DNS Query to Find Service

# From Consul Node (in this case on the node locally)
dig @127.0.0.1 -p 8600 express-server.service.consul
dig @127.0.0.1 -p 8600 apache-server.service.consul

curl --request GET http://127.0.0.1:8500/v1/catalog/service/express-server | jq 
curl --request GET http://127.0.0.1:8500/v1/catalog/service/apache-server | jq 


# Prepared Query
curl http://127.0.0.1:8500/v1/query \
    --request POST \
    --data @- << EOF
{
  "Name": "06-query",
  "Service": {
    "Service": "apache-server",
    "Tags": ["i-06dff96ee19500d93"]
  }
}
EOF

# ID 75265303-e90c-ea57-1c09-13a17cd2e580
curl http://127.0.0.1:8500/v1/query/75265303-e90c-ea57-1c09-13a17cd2e580 | jq

dig @127.0.0.1 -p 8600 06-query.query.consul
curl http://127.0.0.1:8500/v1/query/75265303-e90c-ea57-1c09-13a17cd2e580/execute | jq


# Failover policies
# {
#   "Name": "web-app-v64",
#   "Service": {
#     "Service": "web-app",
#     "Tags": ["v6.4"]
#     "Failover": {
#         "NearestN": 2
#         "Datacenters": ["dc2", "dc3"]
#     }
#   }
# }

# Consul KV store
consul kv put pet cat
consul kv get pet

# Base 64
curl http://127.0.0.1:8500/v1/kv/data/pet | jq


# Monitor with Handlers
{
    "type": "key",
    "key": "pet",
    "handler_type": "script",
    "args": [/home/consul/handle.sh]
}

consul watch -type=key -key=pet /home/consul/handle.sh

consul kv put pet dog


# ENV consul
consul kv put db/DB_ADDR 10.2.23.98
consul kv put db/PORT 3306

envconsul -prefix db env

# new env variables
PORT=3306

consul kv put db/PORT 3435

# new env variables
PORT=3435

# Consul Template
cat > consul.tmpl << EOF
The port for my DB is {{"db/PORT"}}
EOF

# once otherwise its a long running daemon
consul-template -template consul.tmpl:consul.txt -once


# Snapshots


# Register Service Proxy

