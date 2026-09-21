# Fork Information

This is [@loadwolf](https://github.com/loadwolf)'s fork of [LiteLLM-Labs/lite-harness](https://github.com/LiteLLM-Labs/lite-harness).

## Fork Goals

Make this fork a solid base for **Agentic Harness development** on LiteLLM while maintaining upstream compatibility:

1. **Keep upstream compatibility**: Stay aligned with LiteLLM-Labs/lite-harness protocol and architecture
2. **Improve local DX**: Better documentation, clearer setup, reliable installation
3. **Enable extensibility**: Make it easier to add custom harness providers

## What's Different from Upstream

### Documentation Improvements

1. **Enhanced README.md**
   - Fork relationship and upstream sync instructions
   - Clearer setup steps with explicit npm/pip commands
   - Environment variable placeholders (no secrets committed)
   - Structured sections for better navigation

2. **Updated Contributing Guide** ([docs/contributing-harness.md](./docs/contributing-harness.md))
   - Reflects current SDK server architecture (not outdated harnesses/ pattern)
   - Step-by-step provider creation guide
   - Clear registration points and immutability rules

3. **This Document** (FORK.md)
   - Fork-specific changes and rationale
   - Extension guidance
   - Merge considerations

### Extensibility Improvements

1. **Example Custom Provider** ([src/sdk/server/providers/custom/](./src/sdk/server/providers/custom/))
   - Minimal working stub provider showing the structure
   - Inline TODOs marking extension points
   - Demonstrates the auto-discovery registration pattern

2. **Smoke Test Script** ([scripts/smoke-test.sh](./scripts/smoke-test.sh))
   - Verifies setup without requiring live API keys
   - Tests provider discovery and basic runtime initialization
   - Useful for CI or post-install verification

3. **Live Gateway Test** ([scripts/live-gateway-test.sh](./scripts/live-gateway-test.sh))
   - End-to-end test against real LiteLLM gateway instances
   - Verified against https://litellm.chat.mq.edu.au
   - Includes Cloudflare User-Agent workaround ([scripts/ua-preload.mjs](./scripts/ua-preload.mjs))
   - Creates `.venv` and installs Python SDK automatically

## Cloudflare User-Agent Requirement

Some LiteLLM gateways (including https://litellm.chat.mq.edu.au) sit behind Cloudflare, which returns error 1010 when Node.js's default `fetch()` User-Agent is detected. The fork includes `scripts/ua-preload.mjs` to inject a browser-like User-Agent automatically.

When testing against Cloudflare-protected gateways:

```bash
export NODE_OPTIONS="--import $PWD/scripts/ua-preload.mjs"
# Now all fetch() calls include browser-like headers
```

The live gateway test script applies this automatically.

## How to Extend This Fork

### Adding a Custom Harness Provider

The SDK server uses **auto-discovery** for providers. Adding a new one requires only dropping a folder—no central registry edits.

#### 1. Create Provider Structure

```bash
mkdir -p src/sdk/server/providers/my-harness
cd src/sdk/server/providers/my-harness
```

Create two files:

**`index.mjs`** — Provider runtime

```js
// Required exports
export const id = "my-harness";                    // Canonical identifier
export const aliases = ["my", "myharness"];        // Optional alternate names
export const displayName = "My Harness";           // UI-friendly name

export function createRuntime({ model, permissionMode, cwd, env, diagnostics }) {
  // Initialize your harness SDK or client
  
  return {
    get model() { return currentModel; },
    setModel(next) { /* update model */ },
    setPermissionMode(next) { /* update permission mode */ },
    interrupt() { /* abort current request */ },
    
    async *runTurn({ prompt, session }) {
      // Run the agent turn
      // Yield frames using toFrames() from transformation.mjs
      // Frame types: assistant, stream_event, result
    }
  };
}
```

**`transformation.mjs`** — Map provider events to canonical frames

```js
export function toFrames(providerEvent, { sessionId }) {
  // Convert provider-specific events to wire protocol frames
  // Return array of frames with types: assistant, stream_event
  return [];
}
```

#### 2. Provider Discovery

The registry scans `src/sdk/server/providers/` automatically. Your provider becomes available immediately by `id` or any `aliases`.

#### 3. Session Immutability

Each `Session` instance holds:
- One provider (set at creation, never changed)
- One model (can change via `setModel()`)
- Permission mode (can change via `setPermissionMode()`)

Switching harnesses requires creating a new session.

#### 4. Testing Your Provider

```bash
# Test transformation logic (pure, no network)
node --test "tests/src/sdk/server/providers/my-harness/transformation.test.mjs"

# Test provider registration
node -e "import('./src/sdk/server/providers/index.mjs').then(m => m.loadProviders().then(p => console.log([...p.keys()])))"

# Smoke test (optional, no API keys needed for structure validation)
bash scripts/smoke-test.sh
```

#### 5. LiteLLM Gateway Support (Optional)

If your provider calls an LLM API, support routing through LiteLLM:

```js
function applyLiteLlmEnv(env) {
  if (!env.LITELLM_API_BASE || !env.LITELLM_API_KEY) return;
  // Override provider endpoint to use LiteLLM gateway
  // Example: process.env.PROVIDER_BASE_URL = env.LITELLM_API_BASE
}
```

### External Provider Directory

For testing or private providers, use `LITE_HARNESS_PROVIDERS_DIR`:

```bash
export LITE_HARNESS_PROVIDERS_DIR=/path/to/my/providers
# Now src/sdk/server/providers/ + /path/to/my/providers are both scanned
```

## Merging Upstream Changes

When syncing from [LiteLLM-Labs/lite-harness](https://github.com/LiteLLM-Labs/lite-harness):

```bash
git fetch upstream
git merge upstream/main
```

### Potential Conflict Areas

1. **README.md**: Fork info section at top, setup section, docs section at bottom
2. **docs/contributing-harness.md**: We updated this to match SDK server architecture
3. **src/sdk/server/providers/custom/**: New example provider (upstream won't have this)
4. **scripts/smoke-test.sh**: New smoke test script
5. **FORK.md**: This file (fork-only)

### Resolution Strategy

- **Keep fork additions**: FORK.md, custom provider example, smoke test
- **Merge documentation**: Accept upstream updates, then re-apply fork-specific sections
- **Protocol/architecture changes**: Upstream wins—update our extensions to match

## Upstream Compatibility

This fork intentionally maintains:

- **Wire protocol compatibility**: Client SDKs work with both upstream and fork servers
- **Provider interface**: `createRuntime()` signature matches upstream conventions
- **Session semantics**: Immutability rules, control requests, turn lifecycle
- **Auto-discovery pattern**: Mirrors litellm-rust `providers/mod.rs` scan-based registry

Additions are **purely additive**—we don't modify existing providers or core protocol logic.

## Contributing Back to Upstream

If you develop a generally-useful provider or improvement:

1. Test it works in this fork
2. Verify it doesn't break upstream compatibility (check protocol.mjs, session.mjs)
3. Submit a PR to [LiteLLM-Labs/lite-harness](https://github.com/LiteLLM-Labs/lite-harness)

This fork is a **proving ground**, not a permanent divergence.

## Questions or Issues

- **Fork issues**: Open on [loadwolf/lite-harness](https://github.com/loadwolf/lite-harness/issues)
- **Upstream issues**: Open on [LiteLLM-Labs/lite-harness](https://github.com/LiteLLM-Labs/lite-harness/issues)
- **LiteLLM Discord**: [![Discord](https://img.shields.io/badge/Discord-Chat-5865F2?logo=discord&logoColor=white)](https://discord.gg/Nkxw3rm3EE)
