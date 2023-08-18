cat > home/consul/red-query.json << EOF
{
    "Name": "red-server",
    "Service": {
        "Service": "express-server",
        "Tags": ["red"]
    }
}
EOF

curl --request POST --data @/home/consul/red-query.json http://127.0.0.1:8500/v1/query

cat > home/consul/blue-query.json << EOF
{
    "Name": "blue-server",
    "Service": {
        "Service": "express-server",
        "Tags": ["blue"]
    }
}
EOF

curl --request POST --data @/home/consul/blue-query.json http://127.0.0.1:8500/v1/query
