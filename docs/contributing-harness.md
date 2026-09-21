# Adding a New Harness Provider

This guide shows how to add a new harness provider to the lite-harness SDK server.

> **Architecture Note:** This repo uses an **SDK server** architecture, not the older
> inline-adapter pattern. Providers are **auto-discovered** from `src/sdk/server/providers/`.
> No central registry edits needed.

---

## Quick Start

Use the example provider as a template:

```bash
# Copy the stub
cp -r src/sdk/server/providers/custom src/sdk/server/providers/my-harness

# Edit index.mjs and transformation.mjs (TODOs marked inline)
# Replace "custom" with your provider id

# Verify discovery
node -e "import('./src/sdk/server/providers/index.mjs').then(m => m.loadProviders().then(p => console.log([...p.keys()])))"
```

Your provider is now available by its `id` or any `aliases`.

---

## Provider Structure

A provider is a folder under `src/sdk/server/providers/` containing:

```
my-harness/
├── index.mjs           → Provider runtime (SDK integration)
├── transformation.mjs  → Event-to-frame mapping (pure, testable)
└── README.md           → Optional: usage notes
```

### `index.mjs` — Provider Runtime

**Required exports:**

```js
export const id = "my-harness";                    // Canonical identifier
export const aliases = ["my", "myharness"];        // Optional: alternate names
export const displayName = "My Harness";           // Optional: UI-friendly name

export function createRuntime({ model, permissionMode, cwd, env, diagnostics }) {
  // Initialize your SDK
  
  return {
    get model() { return currentModel; },
    setModel(next) { /* update model */ },
    setPermissionMode(next) { /* update permission mode */ },
    interrupt() { /* abort turn */ },
    
    async *runTurn({ prompt, session }) {
      // Run agent turn, yield frames
      for await (const event of yourSDK.stream(prompt)) {
        for (const frame of toFrames(event, { sessionId: session.sessionId })) {
          yield frame;
        }
      }
    }
  };
}
```

### `transformation.mjs` — Event Mapping

Keep this **pure** (no network, no state) for testability:

```js
export function toFrames(providerEvent, { sessionId }) {
  // Map SDK events to wire frames
  if (providerEvent.type === "delta") {
    return [{
      type: "stream_event",
      session_id: sessionId,
      event: {
        type: "content_block_delta",
        delta: { type: "text_delta", text: providerEvent.text }
      }
    }];
  }
  return [];
}
```

---

## Auto-Discovery

The registry (`providers/index.mjs`) scans each subfolder for:

1. An `index.mjs` file
2. Exports: `id` (string) and `createRuntime` (function)

When both are present, the provider is registered by `id` and all `aliases`.

**No other files need changes.** Adding a provider = dropping a folder.

### External Providers

Load providers from outside this repo:

```bash
export LITE_HARNESS_PROVIDERS_DIR=/path/to/my-providers
# Both src/sdk/server/providers/ and your directory are scanned
```

---

## Session and Runtime Lifecycle

### Session Immutability

Each `Session` instance holds:

- **One provider** (set at creation, never changed)
- **One model** (can change via `setModel()`)
- **Permission mode** (can change via `setPermissionMode()`)

**Switching harnesses requires creating a new session.**

### Runtime Interface

Your `createRuntime()` returns an object with:

| Member | Type | Purpose |
|--------|------|---------|
| `model` | getter | Returns current model string |
| `setModel(next)` | method | Updates model mid-session |
| `setPermissionMode(next)` | method | Updates permission mode |
| `interrupt()` | method | Aborts current turn |
| `runTurn({ prompt, session })` | async generator | Yields frames for one turn |

### Frame Types

Your `runTurn()` yields:

- **assistant**: Complete agent response messages
- **stream_event**: Streaming deltas (text, tool use, thinking, etc.)

**Do not yield `result` frames** — the `Session` class appends them automatically
with success/error/cancelled status.

---

## Wire Protocol Frames

### Assistant Frame

```js
{
  type: "assistant",
  message: {
    model: "your-model-name",
    content: [
      { type: "text", text: "Response text" },
      // ... more content blocks
    ],
  },
  parent_tool_use_id: null
}
```

### Stream Event Frame

```js
{
  type: "stream_event",
  session_id: "ses_abc123",
  event: {
    type: "content_block_delta",  // or "tool_use", "thinking", etc.
    index: 0,
    delta: { type: "text_delta", text: "incremental text" }
  }
}
```

See [src/sdk/PROTOCOL.md](../src/sdk/PROTOCOL.md) for the complete specification.

---

## Testing Your Provider

### 1. Pure Transformation (no network)

```js
import { toFrames } from "./providers/my-harness/transformation.mjs";

const frames = toFrames(
  { type: "delta", text: "Hello" },
  { sessionId: "test-session" }
);
console.log(frames);
```

### 2. Provider Discovery

```bash
node -e "import('./src/sdk/server/providers/index.mjs').then(m => m.loadProviders().then(p => console.log([...p.keys()])))"
# Should include your provider id and aliases
```

### 3. Integration Test (Python SDK)

```python
from lite_harness import query, AgentOptions
import asyncio

async def test():
    async for message in query(
        prompt="test",
        options=AgentOptions(harness="my-harness", model="test-model")
    ):
        print(message)

asyncio.run(test())
```

### 4. Unit Tests

Add tests to `tests/src/sdk/server/providers/my-harness/transformation.test.mjs`:

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { toFrames } from "../../../../../src/sdk/server/providers/my-harness/transformation.mjs";

test("toFrames: content delta", () => {
  const frames = toFrames({ type: "delta", text: "hi" }, { sessionId: "s" });
  assert.equal(frames.length, 1);
  assert.equal(frames[0].type, "stream_event");
});
```

Run with:

```bash
node --test "tests/src/sdk/server/**/*.test.mjs"
```

---

## LiteLLM Gateway Support

If your provider calls an LLM API, support routing through LiteLLM:

```js
function applyLiteLlmEnv(env) {
  if (!env.LITELLM_API_BASE || !env.LITELLM_API_KEY) return;
  
  // Route SDK to LiteLLM gateway
  yourSDK.baseURL = env.LITELLM_API_BASE.replace(/\/v1$/, "");
  yourSDK.apiKey = env.LITELLM_API_KEY;
}

export function createRuntime({ env, ...opts }) {
  applyLiteLlmEnv(env);
  // ... rest of runtime
}
```

Users can then set:

```bash
export LITELLM_API_BASE=https://litellm.your-company.com/v1
export LITELLM_API_KEY=sk-litellm-...
```

And your provider routes through the gateway automatically (with budgets, logs, fallbacks, etc.).

---

## Checklist

- [ ] Created `src/sdk/server/providers/<name>/index.mjs` with required exports
- [ ] Implemented `createRuntime()` with full runtime interface
- [ ] Created `transformation.mjs` with pure `toFrames()` function
- [ ] Provider discovered in registry (test with node -e command above)
- [ ] Frames match wire protocol (assistant, stream_event)
- [ ] Added unit tests under `tests/src/sdk/server/providers/<name>/`
- [ ] Tested with Python or TypeScript SDK
- [ ] Optional: Added LiteLLM gateway support

---

## Examples

For production implementations, see:

- [`src/sdk/server/providers/anthropic/`](../src/sdk/server/providers/anthropic/) — Drives @anthropic-ai/claude-agent-sdk
- [`src/sdk/server/providers/codex/`](../src/sdk/server/providers/codex/) — Drives @openai/codex-sdk  
- [`src/sdk/server/providers/custom/`](../src/sdk/server/providers/custom/) — Minimal stub template

---

## Architecture References

- [SDK Backend README](../src/sdk/server/README.md) — Server architecture overview
- [SDK AGENTS.md](../src/sdk/AGENTS.md) — Client SDK constraints and hard rules
- [Wire Protocol](../src/sdk/PROTOCOL.md) — Full protocol specification
