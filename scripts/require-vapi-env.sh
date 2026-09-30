#!/usr/bin/env bash
# Fail closed unless the three Vapi telephony keys are set.
# Required for every vapi-studio-project (local yarn start / remote deploy).
#
#   VAPI_API_KEY          — Vapi org token (Bearer)
#   POC_ASSISTANT_ID      — assistant this project claims
#   VAPI_PHONE_NUMBER_ID  — phone number this project claims (inbound SELECT)
#
# Optional slot labels (platform inventory; print / sync only):
#   VAPI_CLAIM_ASSISTANT_SLOT=1
#   VAPI_CLAIM_PHONE_SLOT=1
set -euo pipefail

ROOT="$(CDPATH="" cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${1:-$ROOT/.env}"

fail() { echo ">> require-vapi-env FAILED: $*" >&2; exit 1; }

[[ -f "$ENV_FILE" ]] || fail "missing $ENV_FILE — copy .env.example and set Vapi keys"

eval "$(
  ENV_FILE="$ENV_FILE" python3 - <<'PY'
from pathlib import Path
import os, shlex
path = Path(os.environ["ENV_FILE"])
for raw in path.read_text().splitlines():
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

API_KEY="${VAPI_API_KEY:-}"
ASSISTANT="${POC_ASSISTANT_ID:-${VAPI_ASSISTANT_ID:-}}"
PHONE_ID="${VAPI_PHONE_NUMBER_ID:-}"
A_SLOT="${VAPI_CLAIM_ASSISTANT_SLOT:-}"
P_SLOT="${VAPI_CLAIM_PHONE_SLOT:-}"

[[ -n "$API_KEY" ]] || fail "VAPI_API_KEY required (Vapi org token)"
[[ -n "$ASSISTANT" ]] || fail "POC_ASSISTANT_ID required (assistant this project claims)"
[[ -n "$PHONE_ID" ]] || fail "VAPI_PHONE_NUMBER_ID required (phone this project claims)"

echo ">> vapi env OK"
echo "   VAPI_API_KEY=***${#API_KEY} chars"
echo "   POC_ASSISTANT_ID=${ASSISTANT}${A_SLOT:+  (claim slot ${A_SLOT})}"
echo "   VAPI_PHONE_NUMBER_ID=${PHONE_ID}${P_SLOT:+  (claim slot ${P_SLOT})}"
