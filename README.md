# lite-harness

Call all agent harnesses using the Claude Agent SDK format.

lite-harness manages:

- One TypeScript and Python interface for multiple agent harnesses
- Harness switching with `harness`, model switching with `model`
- Claude Agent SDK-compatible streaming messages and errors

> **Fork Note:** This is [@loadwolf](https://github.com/loadwolf)'s fork of [LiteLLM-Labs/lite-harness](https://github.com/LiteLLM-Labs/lite-harness), 
> extended for agentic use cases. See [FORK.md](./FORK.md) for fork-specific changes and extension guidance.

> Preview: the SDK is not published to npm or PyPI yet. Clone this repo to try
> it. If you want a packaged release, please
> [file an issue](https://github.com/LiteLLM-Labs/lite-harness/issues).

[![Discord](https://img.shields.io/badge/Discord-Chat-5865F2?logo=discord&logoColor=white)](https://discord.gg/Nkxw3rm3EE)

## Setup

### 1. Clone and Install

```bash
# Clone this fork
git clone https://github.com/loadwolf/lite-harness.git
cd lite-harness

# Install the backend server's dependencies (required)
npm install --prefix src/sdk/server

# Optional: Install Python SDK in editable mode (if using Python)
pip install -e src/sdk/python

# Optional: Build TypeScript SDK (if using TypeScript)
npm install --prefix src/sdk/typescript
npm run build --prefix src/sdk/typescript
```

### 2. Configure API Keys

Pick a model and set the corresponding provider key:

```bash
# For Claude-based harnesses ("claude-code", "anthropic")
export ANTHROPIC_API_KEY=sk-ant-YOUR_KEY_HERE

# For OpenAI-based harnesses ("codex")
export OPENAI_API_KEY=sk-YOUR_KEY_HERE

# Optional: Route through LiteLLM AI Gateway
export LITELLM_API_BASE=https://litellm.your-company.com/v1
export LITELLM_API_KEY=sk-litellm-YOUR_KEY_HERE
```

**Important:** Never commit real API keys to the repository.

## TypeScript Usage

```bash
npm install --prefix src/sdk/typescript && npm run build --prefix src/sdk/typescript
```

```ts
import { query } from "@lite-harness/sdk";

const prompt = "Fix the failing test";

// Claude Code harness
for await (const message of query({
  prompt,
  options: { harness: "claude-code", model: "claude-opus-4-8" },
})) {
  console.log(message);
}

// Codex harness
for await (const message of query({
  prompt,
  options: { harness: "codex", model: "gpt-5.5" },
})) {
  console.log(message);
}
```

## Python Usage

```bash
pip install -e src/sdk/python      # editable install of the client (Python 3.10+)
```

```python
from lite_harness import query, AgentOptions

prompt = "Fix the failing test"

# Claude Code harness
async for message in query(
    prompt=prompt,
    options=AgentOptions(harness="claude-code", model="claude-opus-4-8"),
):
    print(message)

# Codex harness
async for message in query(
    prompt=prompt,
    options=AgentOptions(harness="codex", model="gpt-5.5"),
):
    print(message)
```

## Supported Harnesses

See [`src/sdk/server/providers/`](src/sdk/server/providers/) for the full list.

- `claude-code`: Claude Agent SDK / Claude Code behavior.
  Upstream: [Python](https://github.com/anthropics/claude-agent-sdk-python),
  [TypeScript](https://github.com/anthropics/claude-agent-sdk-typescript).
- `codex`: OpenAI Codex CLI behavior.
  Upstream: [openai/codex](https://github.com/openai/codex).
- `pi-ai`: Pi AI behavior.

## With LiteLLM AI Gateway

Add LiteLLM AI Gateway when you want central keys, budgets, logs, fallbacks, and
provider routing.

```bash
export LITELLM_API_BASE=https://litellm.your-company.com/v1
export LITELLM_API_KEY=sk-litellm-...
```

```ts
import { query } from "@lite-harness/sdk";

for await (const message of query({
  prompt: "Debug this production trace",
  options: {
    harness: "codex",
    model: "anthropic/claude-opus-4-8",
  },
})) {
  console.log(message);
}
```

## Syncing from Upstream

This fork tracks [LiteLLM-Labs/lite-harness](https://github.com/LiteLLM-Labs/lite-harness). To sync upstream changes:

```bash
# Add upstream remote (first time only)
git remote add upstream https://github.com/LiteLLM-Labs/lite-harness.git

# Fetch and merge upstream changes
git fetch upstream
git merge upstream/main

# Resolve any conflicts, then push
git push origin main
```

See [FORK.md](./FORK.md) for details on fork-specific extensions that may need attention during merges.

## Docs

- [SDK Documentation](src/sdk/README.md)
- [Fork-Specific Changes](FORK.md)
- [Contributing a New Harness Provider](docs/contributing-harness.md)

## License

MIT
