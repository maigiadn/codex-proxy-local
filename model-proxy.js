const http = require("http");
const https = require("https");
const { URL } = require("url");

// ============================================================
// Codex Model Alias Proxy
// A lightweight local proxy that remaps model names before
// forwarding requests to the actual OpenAI-compatible provider.
//
// This solves the issue where Codex CLI/Extension sends bare
// model slugs (e.g. "gpt-5.5") but the provider expects
// prefixed names (e.g. "cx/gpt-5.5").
// ============================================================

// Configuration - can be overridden via environment variables
const TARGET = process.env.PROXY_TARGET || "https://apikey.maivangia.com";
const PORT = parseInt(process.env.PROXY_PORT || "18080", 10);

// Model alias mapping: incoming model name -> actual model name on provider
// Add or modify entries as needed
const MODEL_ALIASES = {
  "gpt-5.5": "cx/gpt-5.5",
  "gpt-5.4": "cx/gpt-5.4",
  "gpt-5.3-codex": "cx/gpt-5.3-codex",
};

const server = http.createServer((req, res) => {
  let body = [];
  req.on("data", (chunk) => body.push(chunk));
  req.on("end", () => {
    let rawBody = Buffer.concat(body);
    const contentType = req.headers["content-type"] || "";

    // Replace model name in JSON body
    if (contentType.includes("json") && rawBody.length > 0) {
      try {
        const json = JSON.parse(rawBody.toString());
        if (json.model && MODEL_ALIASES[json.model]) {
          console.log(
            `[proxy] Model alias: ${json.model} -> ${MODEL_ALIASES[json.model]}`
          );
          json.model = MODEL_ALIASES[json.model];
        }
        rawBody = Buffer.from(JSON.stringify(json));
      } catch (e) {
        // not JSON, pass through
      }
    }

    const targetUrl = new URL(req.url, TARGET);
    const options = {
      hostname: targetUrl.hostname,
      port: 443,
      path: targetUrl.pathname + targetUrl.search,
      method: req.method,
      headers: {
        ...req.headers,
        host: targetUrl.hostname,
        "content-length": rawBody.length,
      },
    };

    const proxyReq = https.request(options, (proxyRes) => {
      res.writeHead(proxyRes.statusCode, proxyRes.headers);
      proxyRes.pipe(res);
    });

    proxyReq.on("error", (e) => {
      console.error("[proxy] Error:", e.message);
      res.writeHead(502);
      res.end("Proxy error");
    });

    proxyReq.write(rawBody);
    proxyReq.end();
  });
});

server.listen(PORT, "127.0.0.1", () => {
  console.log(`[proxy] Model alias proxy running on http://127.0.0.1:${PORT}`);
  console.log(`[proxy] Forwarding to ${TARGET}`);
  console.log(`[proxy] Aliases:`, MODEL_ALIASES);
});
