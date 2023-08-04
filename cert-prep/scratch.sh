# Register an Express Service and Health Check via API
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
    10.0.2.109:8500/v1/agent/service/register

# Prepared query
