curl -H "Authorization: Token $NETBOX_TOKEN" \
     -H "Content-Type: application/json" \
     -X POST https://netbox.philiplorenz.com/graphql/ \
     --data '{"query": "{ device_list { id name site { name } primary_ip4 { address } } }"}'