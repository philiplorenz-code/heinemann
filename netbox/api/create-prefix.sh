curl -X POST https://netbox.philiplorenz.com/api/ipam/prefixes/ \
  -H "Authorization: Token $NETBOX_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"prefix": "10.10.10.0/24", "status": "active"}'