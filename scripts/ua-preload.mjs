// Some LiteLLM gateways sit behind Cloudflare, which rejects bare Node fetch
// with error 1010 unless a browser-like User-Agent is present.
const UA =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36";

const orig = globalThis.fetch.bind(globalThis);
globalThis.fetch = (input, init = {}) => {
  const headers = new Headers(init.headers || {});
  if (!headers.has("user-agent")) headers.set("user-agent", UA);
  if (!headers.has("accept")) headers.set("accept", "application/json");
  return orig(input, { ...init, headers });
};
