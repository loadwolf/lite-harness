// Transformation module: maps provider-specific events to canonical wire frames.
//
// Keep this pure (no network, no state) for testability. The runtime calls
// toFrames() for each event from your SDK and yields the resulting frames.

// ==============================================================================
// Frame Builders
// ==============================================================================

// Build an assistant message frame
function assistantFrame(sessionId, content, model) {
  return {
    type: "assistant",
    message: {
      model,
      content: Array.isArray(content) ? content : [{ type: "text", text: String(content) }],
    },
    parent_tool_use_id: null,
  };
}

// Build a stream event frame (for content deltas, tool use, thinking, etc.)
function streamEventFrame(sessionId, event) {
  return {
    type: "stream_event",
    session_id: sessionId,
    event,
  };
}

// ==============================================================================
// Transformation Function (REQUIRED EXPORT)
// ==============================================================================

/**
 * Convert a provider-specific event to an array of wire protocol frames.
 *
 * @param {object} providerEvent - Raw event from your SDK
 * @param {{ sessionId: string }} context - Session context
 * @returns {Array<object>} - Array of frames (may be empty)
 */
export function toFrames(providerEvent, { sessionId }) {
  // TODO: Replace this with your actual event-to-frame mapping
  //
  // Example patterns:
  //
  // 1. Content delta:
  //    if (providerEvent.type === "content_delta") {
  //      return [streamEventFrame(sessionId, {
  //        type: "content_block_delta",
  //        index: 0,
  //        delta: { type: "text_delta", text: providerEvent.text }
  //      })];
  //    }
  //
  // 2. Tool use:
  //    if (providerEvent.type === "tool_use") {
  //      return [streamEventFrame(sessionId, {
  //        type: "tool_use",
  //        id: providerEvent.tool_id,
  //        name: providerEvent.tool_name,
  //        input: providerEvent.input
  //      })];
  //    }
  //
  // 3. Complete message:
  //    if (providerEvent.type === "message_complete") {
  //      return [assistantFrame(sessionId, providerEvent.content, providerEvent.model)];
  //    }

  // Stub implementation: Pass through unknown events as stream_events
  // Replace this with structured mapping based on your SDK's event types
  if (providerEvent && typeof providerEvent === "object") {
    return [streamEventFrame(sessionId, providerEvent)];
  }

  return [];
}

// ==============================================================================
// Testing This Module
// ==============================================================================

// Pure function testing (no network needed):
//
// import { toFrames } from "./transformation.mjs";
//
// const frames = toFrames(
//   { type: "content_delta", text: "Hello" },
//   { sessionId: "test-session" }
// );
// console.log(frames);
// // Expected: [{ type: "stream_event", session_id: "test-session", event: { type: "content_delta", text: "Hello" } }]

// ==============================================================================
// Wire Protocol Frame Types Reference
// ==============================================================================

// assistant frame:
// {
//   type: "assistant",
//   message: {
//     model: string,
//     content: [{ type: "text", text: string }, ...],
//   },
//   parent_tool_use_id: string | null
// }

// stream_event frame:
// {
//   type: "stream_event",
//   session_id: string,
//   event: {
//     type: "content_block_delta" | "tool_use" | "thinking" | ...,
//     ...event-specific fields
//   }
// }

// See ../anthropic/transformation.mjs or ../codex/transformation.mjs for
// real-world examples of mapping SDK events to wire frames.
