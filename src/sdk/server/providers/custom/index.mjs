// Example custom provider — a minimal stub showing the structure.
//
// This provider demonstrates:
// 1. Required exports (id, createRuntime)
// 2. Optional exports (aliases, displayName, harnessId)
// 3. Runtime interface (model, setModel, setPermissionMode, interrupt, runTurn)
// 4. Frame generation using the transformation module
//
// To use this as a template:
// 1. Copy this folder to a new name (e.g., providers/my-harness/)
// 2. Update id, aliases, and displayName below
// 3. Implement your harness SDK integration in createRuntime
// 4. Update transformation.mjs to map your SDK's events to wire frames
// 5. No other files need changes — auto-discovery handles registration

import { toFrames } from "./transformation.mjs";

// ==============================================================================
// Provider Metadata (REQUIRED)
// ==============================================================================

export const id = "custom";
export const aliases = ["example", "stub"]; // Optional: alternate names
export const harnessId = "custom"; // Optional: maps to harness field in responses
export const displayName = "Custom Example"; // Optional: UI-friendly name

// ==============================================================================
// Runtime Factory (REQUIRED)
// ==============================================================================

export function createRuntime({ model, permissionMode, cwd, env = process.env, diagnostics = () => {} }) {
  // TODO: Initialize your harness SDK or client here
  // Example: const client = new MyHarnessSDK({ apiKey: env.MY_API_KEY });

  // Optional: Support LiteLLM routing
  // if (env.LITELLM_API_BASE && env.LITELLM_API_KEY) {
  //   client.baseURL = env.LITELLM_API_BASE;
  //   client.apiKey = env.LITELLM_API_KEY;
  // }

  let currentModel = model || env.LITELLM_DEFAULT_MODEL || "default-model-name";
  let mode = permissionMode || "default";
  let controller = null;

  return {
    // Getter for current model (REQUIRED)
    get model() {
      return currentModel;
    },

    // Update model mid-session (REQUIRED)
    setModel(next) {
      if (next) currentModel = next;
    },

    // Update permission mode mid-session (REQUIRED)
    setPermissionMode(next) {
      mode = next || "default";
      // TODO: Apply permission mode to your SDK if supported
    },

    // Abort the current turn (REQUIRED)
    interrupt() {
      controller?.abort();
      // TODO: Call your SDK's cancellation method if available
    },

    // Run one agent turn (REQUIRED)
    // Yields wire protocol frames: assistant, stream_event, result
    async *runTurn({ prompt, session }) {
      controller = new AbortController();

      try {
        // TODO: Replace this with your actual SDK call
        // Example: const stream = client.chat({ prompt, model: currentModel, signal: controller.signal });

        // Example stub: Yield a simple response
        diagnostics(`custom: running turn with prompt="${prompt}" model="${currentModel}"\n`);

        // TODO: Stream your SDK's events and transform them to frames
        // Example pattern:
        // for await (const event of stream) {
        //   for (const frame of toFrames(event, { sessionId: session.sessionId })) {
        //     yield frame;
        //   }
        // }

        // Stub response (replace with real SDK integration):
        yield {
          type: "assistant",
          message: {
            model: currentModel,
            content: [
              {
                type: "text",
                text: `Custom provider stub response. Replace this with your SDK integration.\n\nPrompt received: ${prompt}\n\nImplement your harness logic in src/sdk/server/providers/custom/index.mjs`,
              },
            ],
          },
          parent_tool_use_id: null,
        };

        // Session automatically appends a result frame, so don't yield one here
      } catch (err) {
        if (controller.signal.aborted) {
          diagnostics("custom: turn interrupted\n");
          return; // Session emits the cancelled result
        }
        diagnostics(`custom runtime error: ${err?.message ?? err}\n`);
        throw err;
      } finally {
        controller = null;
      }
    },
  };
}

// ==============================================================================
// Notes for Extension
// ==============================================================================

// 1. Auto-Discovery: This provider is registered automatically by scanning
//    src/sdk/server/providers/. The registry maps `id` and all `aliases` to
//    this module.
//
// 2. Session Immutability: Each Session holds one provider (set at creation).
//    Model and permission mode can change mid-session; switching harnesses
//    requires a new session.
//
// 3. Frame Types:
//    - assistant: Agent response messages
//    - stream_event: Content deltas, tool use, thinking, etc.
//    - result: Turn completion (yielded by Session, not the runtime)
//
// 4. Testing:
//    - Pure transformation: node --test tests/.../custom/transformation.test.mjs
//    - Provider discovery: node -e "import('./src/sdk/server/providers/index.mjs').then(m => m.loadProviders().then(p => console.log([...p.keys()])))"
//    - Integration: Use the Python or TypeScript SDK with options.harness = "custom"
//
// 5. Dependencies: If your SDK needs npm packages, add them to
//    src/sdk/server/package.json (this is the only package.json for the server).
