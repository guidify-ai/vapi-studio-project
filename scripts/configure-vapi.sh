#!/usr/bin/env bash
# Claim POC_ASSISTANT_ID onto VAPI_PHONE_NUMBER_ID and point both at this host's /vapi URLs.
#
# HARD RULE: phone.assistantId MUST equal POC_ASSISTANT_ID after configure.
# Requires: VAPI_API_KEY, POC_ASSISTANT_ID, VAPI_PHONE_NUMBER_ID, PUBLIC_BASE_URL
# Optional: POC_ASSISTANT_ID_AB, VAPI_PHONE_NUMBER, VAPI_CLAIM_*_SLOT (print only)
set -euo pipefail

ROOT="$(CDPATH="" cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash "$ROOT/scripts/require-vapi-env.sh" "$ROOT/.env"

if [[ -f .env ]]; then
  eval "$(
    python3 - <<'PY'
from pathlib import Path
import shlex
for raw in Path(".env").read_text().splitlines():
    line = raw.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    key, val = line.split("=", 1)
    key = key.strip()
    if not key or not key.replace("_", "").isalnum() or key[0].isdigit():
        continue
    if len(val) >= 2 and val[0] == val[-1] and val[0] in "\"'":
        val = val[1:-1]
    print(f"export {key}={shlex.quote(val)}")
PY
  )"
fi

API_KEY="${VAPI_API_KEY:-}"
PRIMARY="${POC_ASSISTANT_ID:-${VAPI_ASSISTANT_ID:-}}"
SECONDARY="${POC_ASSISTANT_ID_AB:-}"
PHONE_ID="${VAPI_PHONE_NUMBER_ID:-}"
PHONE_E164="${VAPI_PHONE_NUMBER:-${VAPI_PHONE_NUMBER_READABLE:-}}"
PUBLIC_BASE="${PUBLIC_BASE_URL:-}"
END_CALL_TOOL="${VAPI_END_CALL_TOOL_NAME:-end_call_tool}"
TRANSFER_DEST="${VAPI_TRANSFER_DESTINATION:-}"
WEBHOOK_SECRET="${VAPI_WEBHOOK_SECRET:-}"
A_SLOT="${VAPI_CLAIM_ASSISTANT_SLOT:-}"
P_SLOT="${VAPI_CLAIM_PHONE_SLOT:-}"

fail() { echo ">> vapi configure FAILED: $*" >&2; exit 1; }
ok() { echo ">> ok  $*"; }
note() { echo ">>     $*"; }

[[ -n "$PUBLIC_BASE" ]] || fail "PUBLIC_BASE_URL required (ngrok / public host)"

PUBLIC_BASE="${PUBLIC_BASE%/}"
WEBHOOK_URL="${PUBLIC_BASE}/vapi/webhook"
LLM_URL="${PUBLIC_BASE}/vapi/chat/completions"

echo ">> Vapi configure (claim assistant → phone)"
echo "   assistant=${PRIMARY}${A_SLOT:+  slot ${A_SLOT}}"
echo "   phone=${PHONE_ID}${P_SLOT:+  slot ${P_SLOT}}  e164=${PHONE_E164:-(unset)}"
echo "   webhook=${WEBHOOK_URL}"
echo "   custom_llm=${LLM_URL}"

vapi_api() {
  local method="$1" path="$2" body="${3:-}" url="https://api.vapi.ai${path}" tmp http_code
  tmp="$(mktemp)"
  if [[ -n "$body" ]]; then
    http_code="$(
      curl -sS -o "$tmp" -w '%{http_code}' -X "$method" "$url" \
        -H "Authorization: Bearer ${API_KEY}" \
        -H 'content-type: application/json' \
        -H 'accept: application/json' \
        --data "$body" || true
    )"
  else
    http_code="$(
      curl -sS -o "$tmp" -w '%{http_code}' -X "$method" "$url" \
        -H "Authorization: Bearer ${API_KEY}" \
        -H 'accept: application/json' || true
    )"
  fi
  if [[ "$http_code" != 2* ]]; then
    echo ">> Vapi ${method} ${path} → HTTP ${http_code}" >&2
    head -c 800 "$tmp" >&2 || true
    echo >&2
    rm -f "$tmp"
    return 1
  fi
  cat "$tmp"
  rm -f "$tmp"
}

assistant_body() {
  WEBHOOK_URL="$WEBHOOK_URL" LLM_URL="$LLM_URL" \
    END_CALL_TOOL="$END_CALL_TOOL" TRANSFER_DEST="$TRANSFER_DEST" \
    python3 - <<'PY'
import json, os
webhook, llm = os.environ["WEBHOOK_URL"], os.environ["LLM_URL"]
end_call = os.environ.get("END_CALL_TOOL") or "end_call_tool"
transfer = (os.environ.get("TRANSFER_DEST") or "").strip()
tools = [{
  "type": "function",
  "function": {
    "name": end_call,
    "description": "End the call when the conversation is complete.",
    "parameters": {"type": "object", "properties": {}},
  },
}]
if transfer:
  tools.append({
    "type": "transferCall",
    "destinations": [{"type": "number", "number": transfer, "message": "Connecting you now."}],
  })
print(json.dumps({
  "server": {"url": webhook},
  "firstMessage": "",
  "firstMessageMode": "assistant-speaks-first-with-model-generated-message",
  "model": {
    "provider": "custom-llm",
    "url": llm,
    "model": "studio-project",
    "messages": [{"role": "system", "content": "You are a voice relay. Follow Custom LLM / tool instructions from the server."}],
    "tools": tools,
  },
  "silenceTimeoutSeconds": 120,
}))
PY
}

patch_assistant() {
  local id="$1" label="$2" body resp
  body="$(assistant_body)"
  resp="$(vapi_api PATCH "/assistant/${id}" "$body")" || fail "PATCH /assistant/${id} (${label})"
  RESP="$resp" WANT_WEBHOOK="$WEBHOOK_URL" WANT_LLM="$LLM_URL" python3 - <<'PY' || fail "${label} verify failed"
import json, os, sys
d = json.loads(os.environ["RESP"])
got = ((d.get("server") or {}).get("url")) or d.get("serverUrl") or ""
m = d.get("model") or {}
if got != os.environ["WANT_WEBHOOK"]:
    print(f"server.url={got}", file=sys.stderr); sys.exit(1)
if m.get("provider") != "custom-llm" or m.get("url") != os.environ["WANT_LLM"]:
    print(f"model={m}", file=sys.stderr); sys.exit(1)
PY
  ok "assistant ${label} → ${id}"
}

patch_phone() {
  local body resp
  body="$(
    WEBHOOK_URL="$WEBHOOK_URL" WEBHOOK_SECRET="$WEBHOOK_SECRET" PRIMARY="$PRIMARY" python3 - <<'PY'
import json, os
body = {
  "assistantId": os.environ["PRIMARY"],
  "squadId": None,
  "server": {"url": os.environ["WEBHOOK_URL"], "timeoutSeconds": 20},
}
secret = (os.environ.get("WEBHOOK_SECRET") or "").strip()
if secret:
  body["server"]["secret"] = secret
print(json.dumps(body))
PY
  )"
  resp="$(vapi_api PATCH "/phone-number/${PHONE_ID}" "$body")" || fail "PATCH /phone-number/${PHONE_ID}"
  RESP="$resp" WANT_WEBHOOK="$WEBHOOK_URL" WANT_ASSISTANT="$PRIMARY" python3 - <<'PY' || fail "phone verify failed"
import json, os, sys
d = json.loads(os.environ["RESP"])
url = ((d.get("server") or {}).get("url")) or ""
if url != os.environ["WANT_WEBHOOK"]:
    print(f"server.url={url}", file=sys.stderr); sys.exit(1)
if str(d.get("assistantId") or "").lower() != os.environ["WANT_ASSISTANT"].lower():
    print(f"assistantId={d.get('assistantId')}", file=sys.stderr); sys.exit(1)
PY
  ok "phone ${PHONE_ID} SELECT assistant ${PRIMARY}"
}

patch_assistant "$PRIMARY" "primary"
if [[ -n "$SECONDARY" && "$SECONDARY" != "$PRIMARY" ]]; then
  patch_assistant "$SECONDARY" "secondary-ab"
fi
patch_phone

selected="$(
  vapi_api GET "/phone-number/${PHONE_ID}" \
    | python3 -c 'import json,sys; print(str(json.load(sys.stdin).get("assistantId") or "").lower())'
)"
[[ "$selected" == "$(printf '%s' "$PRIMARY" | tr '[:upper:]' '[:lower:]')" ]] \
  || fail "phone.assistantId=${selected} want=${PRIMARY}"

echo ">> vapi configure PASSED — inbound claims assistant${A_SLOT:+ #${A_SLOT}} + phone${P_SLOT:+ #${P_SLOT}}"
