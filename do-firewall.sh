#!/bin/bash
ACCESS_TOKEN="REPLACE_ME"
FIREWALL_ID=$(curl -s -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${ACCESS_TOKEN}" "https://api.digitalocean.com/v2/firewalls" | jq -r '.firewalls[0].id')

if [[ $1 == "info" ]]; then
  curl -s -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${ACCESS_TOKEN}" "https://api.digitalocean.com/v2/firewalls/${FIREWALL_ID}" | jq
elif [[ $1 == "allow" ]]; then
  curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${ACCESS_TOKEN}" -d '{"inbound_rules":[{"protocol":"tcp","ports":"443","sources":{ "addresses": ["0.0.0.0/0", "::/0"]}}]}' "https://api.digitalocean.com/v2/firewalls/${FIREWALL_ID}/rules" 
elif [[ $1 == "deny" ]]; then
  if [[ $2 == "wait" ]]; then sleep 60; fi
  curl -s -X DELETE -H "Content-Type: application/json" -H "Authorization: Bearer ${ACCESS_TOKEN}" -d '{"inbound_rules":[{"protocol":"tcp","ports":"443","sources":{ "addresses": ["0.0.0.0/0", "::/0"]}}]}' "https://api.digitalocean.com/v2/firewalls/${FIREWALL_ID}/rules" 
fi
