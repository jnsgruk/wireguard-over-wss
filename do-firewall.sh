#!/bin/bash
ACCESS_TOKEN="REPLACE_ME"
FIREWALL_ID=$(curl -s -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${ACCESS_TOKEN}" "https://api.digitalocean.com/v2/firewalls" | jq -r '.firewalls[0].id')
FIREWALL_URL="https://api.digitalocean.com/v2/firewalls/${FIREWALL_ID}"
RULE_SPEC="{\"inbound_rules\":[{\"protocol\":\"tcp\",\"ports\":\"${WSS_PORT:-443}\",\"sources\":{ \"addresses\": [\"0.0.0.0/0\", \"::/0\"]}}]}"
HEADERS=(-H "Content-Type: application/json" -H "Authorization: Bearer ${ACCESS_TOKEN}")

if [[ $1 == "info" ]]; then
  curl -s -X GET "${HEADERS[@]}" "${FIREWALL_URL}" | jq
elif [[ $1 == "allow" ]]; then
  curl -s -X POST "${HEADERS[@]}" -d "${RULE_SPEC}" "${FIREWALL_URL}/rules" 
elif [[ $1 == "deny" ]]; then
  if [[ $2 == "wait" ]]; then sleep 60; fi
  curl -s -X DELETE "${HEADERS[@]}" -d "${RULE_SPEC}" "${FIREWALL_URL}/rules" 
fi
