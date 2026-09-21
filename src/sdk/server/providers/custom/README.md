# Custom Provider Example

This is a **stub provider** demonstrating the structure for adding a new harness to lite-harness.

## Purpose

Use this as a template when creating your own provider. It shows:

- Required and optional exports
- Runtime interface implementation
- Frame generation pattern
- Inline TODOs marking extension points

## Using This Template

1. **Copy this folder** to a new name:
   ```bash
   cp -r src/sdk/server/providers/custom src/sdk/server/providers/my-harness
   ```

2. **Update metadata** in `index.mjs`:
   - Change `id`, `aliases`, `displayName`
   - Update `createRuntime()` to integrate your SDK

3. **Implement transformation** in `transformation.mjs`:
   - Map your SDK's events to wire protocol frames
   - Keep it pure for testability

4. **Test**:
   ```bash
   # Verify auto-discovery
   node -e "import('./src/sdk/server/providers/index.mjs').then(m => m.loadProviders().then(p => console.log([...p.keys()])))"
   
   # Use from Python SDK
   python -c "
   from lite_harness import query, AgentOptions
   import asyncio
   async def test():
       async for msg in query('test', options=AgentOptions(harness='my-harness')):
           print(msg)
   asyncio.run(test())
   "
   ```

5. **No other files need changes** — auto-discovery handles registration.

## Structure

```
custom/
├── index.mjs           → Provider runtime (SDK integration)
├── transformation.mjs  → Event-to-frame mapping (pure)
└── README.md           → This file
```

## Integration Points

### `index.mjs`

- `export const id` — Canonical identifier
- `export const aliases` — Alternate names (optional)
- `export function createRuntime()` — Factory returning runtime interface

### `transformation.mjs`

- `export function toFrames(event, { sessionId })` — Pure event mapper

## Wire Protocol

The runtime yields frames matching these types:

- **assistant**: Complete agent response messages
- **stream_event**: Streaming deltas (text, tool use, thinking, etc.)
- **result**: Turn outcome (handled by Session, don't yield this)

See [src/sdk/PROTOCOL.md](../../PROTOCOL.md) for the full wire specification.

## Real Examples

For production implementations, see:

- [`../anthropic/`](../anthropic/) — Drives @anthropic-ai/claude-agent-sdk
- [`../codex/`](../codex/) — Drives @openai/codex-sdk
- [`../pi-ai/`](../pi-ai/) — Drives @earendil-works/pi-ai

## External Providers

To load providers from outside this repo, use `LITE_HARNESS_PROVIDERS_DIR`:

```bash
export LITE_HARNESS_PROVIDERS_DIR=/path/to/my-providers
# Both src/sdk/server/providers/ and /path/to/my-providers are now scanned
```
