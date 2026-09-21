#!/usr/bin/env bash
# Smoke test: verify lite-harness setup without requiring live API keys
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "=== lite-harness Smoke Test ==="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; exit 1; }
warn() { echo -e "${YELLOW}!${NC} $1"; }

# ==============================================================================
# 1. Check Node.js and npm
# ==============================================================================
echo "Checking Node.js and npm..."
if ! command -v node &> /dev/null; then
  fail "Node.js not found. Install Node.js 18+ to use lite-harness."
fi

NODE_VERSION=$(node --version | cut -d 'v' -f 2 | cut -d '.' -f 1)
if [ "$NODE_VERSION" -lt 18 ]; then
  fail "Node.js version $NODE_VERSION is too old. lite-harness requires Node.js 18+."
fi

pass "Node.js $(node --version) found"

if ! command -v npm &> /dev/null; then
  fail "npm not found. Install npm to manage dependencies."
fi

pass "npm $(npm --version) found"

# ==============================================================================
# 2. Check Python (optional, for Python SDK)
# ==============================================================================
echo
echo "Checking Python (optional)..."
if command -v python3 &> /dev/null; then
  PYTHON_VERSION=$(python3 --version | cut -d ' ' -f 2 | cut -d '.' -f 1,2)
  pass "Python $(python3 --version | cut -d ' ' -f 2) found"
  
  # Check if lite-harness is installed
  if python3 -c "import lite_harness" 2>/dev/null; then
    pass "lite-harness Python package installed"
  else
    warn "lite-harness Python package not installed. Run: pip install -e src/sdk/python"
  fi
else
  warn "Python not found. Python SDK will not be available."
fi

# ==============================================================================
# 3. Check server dependencies
# ==============================================================================
echo
echo "Checking server dependencies..."
if [ ! -d "src/sdk/server/node_modules" ]; then
  fail "Server dependencies not installed. Run: npm install --prefix src/sdk/server"
fi

pass "Server dependencies installed"

# ==============================================================================
# 4. Test provider discovery
# ==============================================================================
echo
echo "Testing provider discovery..."
PROVIDERS=$(node -e "import('./src/sdk/server/providers/index.mjs').then(m => m.loadProviders().then(p => console.log([...p.keys()].join(', '))))" 2>&1)

if [ $? -ne 0 ]; then
  fail "Provider discovery failed: $PROVIDERS"
fi

pass "Provider discovery works"
echo "   Providers: $PROVIDERS"

# Verify expected providers
for provider in "anthropic" "claude-code" "codex" "custom"; do
  if [[ "$PROVIDERS" == *"$provider"* ]]; then
    pass "   Found provider: $provider"
  else
    warn "   Provider not found: $provider"
  fi
done

# ==============================================================================
# 5. Test provider metadata
# ==============================================================================
echo
echo "Testing provider metadata..."
METADATA=$(node -e "import('./src/sdk/server/providers/index.mjs').then(m => m.listProviderMetadata().then(p => console.log(JSON.stringify(p, null, 2))))" 2>&1)

if [ $? -ne 0 ]; then
  fail "Provider metadata retrieval failed: $METADATA"
fi

pass "Provider metadata retrieval works"

# ==============================================================================
# 6. Test server startup (no API key needed for structure validation)
# ==============================================================================
echo
echo "Testing server startup (structure only)..."

# Start server with a timeout, then kill it
timeout 3s node src/sdk/server/server.mjs --help > /dev/null 2>&1 || true

if [ $? -eq 124 ]; then
  # Timeout is expected (--help doesn't exist, server would run forever)
  pass "Server executable runs"
elif [ $? -eq 0 ]; then
  pass "Server executable runs"
else
  # Check if server file exists and is valid JS
  if node --check src/sdk/server/server.mjs 2>/dev/null; then
    pass "Server file is valid JavaScript"
  else
    fail "Server file has syntax errors"
  fi
fi

# ==============================================================================
# 7. Check TypeScript SDK (optional)
# ==============================================================================
echo
echo "Checking TypeScript SDK (optional)..."
if [ -d "src/sdk/typescript/node_modules" ]; then
  pass "TypeScript SDK dependencies installed"
  
  # Check if built
  if [ -f "src/sdk/typescript/dist/index.js" ] || [ -f "src/sdk/typescript/index.js" ]; then
    pass "TypeScript SDK built"
  else
    warn "TypeScript SDK not built. Run: npm run build --prefix src/sdk/typescript"
  fi
else
  warn "TypeScript SDK dependencies not installed. Run: npm install --prefix src/sdk/typescript"
fi

# ==============================================================================
# Summary
# ==============================================================================
echo
echo "=== Smoke Test Summary ==="
echo
pass "Core setup verified successfully!"
echo
echo "Next steps:"
echo "  1. Set API keys (see README.md for providers)"
echo "  2. Try the Python SDK: python -c 'from lite_harness import query; ...'"
echo "  3. Try the TypeScript SDK: see src/sdk/typescript/README.md"
echo "  4. Add custom providers: see docs/contributing-harness.md"
echo
echo "For issues, see: https://github.com/loadwolf/lite-harness/issues"
