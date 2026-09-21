#!/usr/bin/env bash
# Live LiteLLM gateway test: verify the SDK can route through a real gateway
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# ==============================================================================
# Configuration
# ==============================================================================

# Required
if [ -z "${LITELLM_API_KEY:-}" ]; then
  echo "Error: LITELLM_API_KEY is required"
  echo "Usage: LITELLM_API_KEY=sk-... $0"
  exit 1
fi

# Optional with defaults
LITELLM_API_BASE="${LITELLM_API_BASE:-https://litellm.chat.mq.edu.au/v1}"
# Normalize to /v1
LITELLM_API_BASE="${LITELLM_API_BASE%/}"
if [[ "$LITELLM_API_BASE" != */v1 ]]; then
  LITELLM_API_BASE="${LITELLM_API_BASE}/v1"
fi

LITELLM_MODEL="${LITELLM_MODEL:-azure/gpt-4o}"
HARNESS="${HARNESS:-pi-ai}"
PROMPT="${PROMPT:-Reply with exactly: harness-ok}"

echo "=== Live LiteLLM Gateway Test ==="
echo "Gateway: $LITELLM_API_BASE"
echo "Model: $LITELLM_MODEL"
echo "Harness: $HARNESS"
echo "Prompt: $PROMPT"
echo

# ==============================================================================
# 1. Check dependencies
# ==============================================================================

echo "Checking dependencies..."

if ! command -v node &> /dev/null; then
  echo "Error: Node.js not found"
  exit 1
fi

if ! command -v python3 &> /dev/null; then
  echo "Error: Python 3 not found"
  exit 1
fi

echo "✓ Node.js $(node --version)"
echo "✓ Python $(python3 --version)"
echo

# ==============================================================================
# 2. Ensure server dependencies
# ==============================================================================

echo "Ensuring server dependencies..."

if [ ! -d "src/sdk/server/node_modules" ]; then
  echo "Installing server dependencies..."
  npm install --prefix src/sdk/server
else
  echo "✓ Server dependencies already installed"
fi

echo

# ==============================================================================
# 3. Ensure Python SDK in venv
# ==============================================================================

echo "Ensuring Python SDK..."

VENV_PATH="$REPO_ROOT/.venv"

if [ ! -d "$VENV_PATH" ]; then
  echo "Creating virtual environment..."
  python3 -m venv "$VENV_PATH"
fi

# Activate venv
source "$VENV_PATH/bin/activate"

# Install SDK if not present
if ! python3 -c "import lite_harness" 2>/dev/null; then
  echo "Installing lite-harness Python SDK..."
  pip install -q -e src/sdk/python
else
  echo "✓ lite-harness Python SDK installed"
fi

echo

# ==============================================================================
# 4. Probe gateway /models endpoint
# ==============================================================================

echo "Probing gateway models endpoint..."

MODELS_URL="${LITELLM_API_BASE%/v1}/models"

python3 - <<EOF
import sys
import urllib.request
import json

# Browser-like headers for Cloudflare
headers = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
    "Accept": "application/json",
    "Authorization": "Bearer ${LITELLM_API_KEY}"
}

try:
    req = urllib.request.Request("${MODELS_URL}", headers=headers)
    with urllib.request.urlopen(req, timeout=10) as response:
        data = json.loads(response.read().decode())
        model_count = len(data.get("data", []))
        print(f"✓ Gateway reachable: {model_count} models available")
except Exception as e:
    print(f"✗ Gateway probe failed: {e}", file=sys.stderr)
    sys.exit(1)
EOF

if [ $? -ne 0 ]; then
  exit 1
fi

echo

# ==============================================================================
# 5. Run live test through SDK
# ==============================================================================

echo "Running live test through lite-harness SDK..."
echo

# Export env vars for the SDK
export LITELLM_API_BASE
export LITELLM_API_KEY
export LITELLM_MODEL

# Preload User-Agent fix for Cloudflare
export NODE_OPTIONS="--import $REPO_ROOT/scripts/ua-preload.mjs"

# Run Python SDK test
python3 - <<'PYEOF'
import sys
import os
import asyncio
from lite_harness import query, AgentOptions

async def main():
    harness = os.environ.get("HARNESS", "pi-ai")
    model = os.environ.get("LITELLM_MODEL", "azure/gpt-4o")
    prompt = os.environ.get("PROMPT", "Reply with exactly: harness-ok")
    
    try:
        assistant_content = []
        result_status = None
        
        async for message in query(
            prompt=prompt,
            options=AgentOptions(harness=harness, model=model)
        ):
            msg_type = message.get("type", "unknown")
            
            if msg_type == "assistant":
                content = message.get("message", {}).get("content", [])
                for block in content:
                    if block.get("type") == "text":
                        text = block.get("text", "")
                        assistant_content.append(text)
                        print(f"ASSISTANT: {text}")
            
            elif msg_type == "result":
                result_status = message.get("status", "unknown")
                print(f"RESULT: {result_status}")
        
        # Check success
        if result_status == "success" and assistant_content:
            print()
            print("✓ Test passed: received assistant response and success result")
            sys.exit(0)
        else:
            print()
            print(f"✗ Test failed: status={result_status}, content={'yes' if assistant_content else 'no'}")
            sys.exit(1)
    
    except Exception as e:
        print(f"✗ Test failed with exception: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
PYEOF

TEST_EXIT=$?

echo
if [ $TEST_EXIT -eq 0 ]; then
  echo "=== Live Gateway Test: SUCCESS ==="
  exit 0
else
  echo "=== Live Gateway Test: FAILED ==="
  exit 1
fi
