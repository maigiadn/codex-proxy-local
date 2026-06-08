const http = require("http");
const https = require("https");
const { URL } = require("url");

// Configuration - overridden via environment variables or hardcoded values
const TARGET = process.env.PROXY_TARGET || "https://apikey.maivangia.com";
const PORT = parseInt(process.env.PROXY_PORT || "18080", 10);

// Model alias mapping: incoming model name -> actual model name on provider
const MODEL_ALIASES = {
  "gpt-5.4-mini": "cx/gpt-5.4-mini",
  "gpt-5.5": "cx/gpt-5.5",
  "claude-sonnet-4.5": "kr/claude-sonnet-4.5",
  "gemini-3-flash-preview": "gc/gemini-3-flash-preview",
  "gemini-3.1-flash-lite": "gc/gemini-3.1-flash-lite",
  "deepseek-v4-pro": "nv/deepseek-ai/deepseek-v4-pro",
  "deepseek-ai/deepseek-v4-pro": "nv/deepseek-ai/deepseek-v4-pro",
};

const server = http.createServer((req, res) => {
  let body = [];
  req.on("data", (chunk) => body.push(chunk));
  req.on("end", () => {
    let rawBody = Buffer.concat(body);
    const contentType = req.headers["content-type"] || "";

    console.log(`[proxy] Request: ${req.method} ${req.url} (Size: ${rawBody.length} bytes)`);

    // Replace model name in JSON body if an alias matches
    if (contentType.includes("json") && rawBody.length > 0) {
      try {
        const bodyStr = rawBody.toString();
        
        // Fast-path: check if any alias key is present in the raw body string
        let needsReplacement = false;
        for (const alias in MODEL_ALIASES) {
          if (bodyStr.includes(`"${alias}"`)) {
            needsReplacement = true;
            break;
          }
        }

        if (needsReplacement) {
          const json = JSON.parse(bodyStr);
          if (json.model && MODEL_ALIASES[json.model]) {
            console.log(
              `[proxy] Model alias: ${json.model} -> ${MODEL_ALIASES[json.model]}`
            );
            json.model = MODEL_ALIASES[json.model];
            rawBody = Buffer.from(JSON.stringify(json));
          }
        }
      } catch (e) {
        console.error(`[proxy] Failed to parse/modify JSON:`, e.message);
      }
    }

    const targetUrl = new URL(req.url, TARGET);
    const isHttps = targetUrl.protocol === "https:";
    const requester = isHttps ? https : http;

    const options = {
      hostname: targetUrl.hostname,
      port: targetUrl.port || (isHttps ? 443 : 80),
      path: targetUrl.pathname + targetUrl.search,
      method: req.method,
      headers: {
        ...req.headers,
        host: targetUrl.hostname,
        "content-length": rawBody.length,
      },
    };

    const isModelsRequest = (targetUrl.pathname === "/v1/models" || targetUrl.pathname === "/models") && req.method === "GET";

    const proxyReq = requester.request(options, (proxyRes) => {
      if (isModelsRequest && proxyRes.statusCode === 200) {
        let resBody = [];
        proxyRes.on("data", (chunk) => resBody.push(chunk));
        proxyRes.on("end", () => {
          try {
            const rawResBody = Buffer.concat(resBody).toString();
            const json = JSON.parse(rawResBody);
            if (json && Array.isArray(json.data)) {
              // Add short names
              const shortNames = Object.keys(MODEL_ALIASES);
              // Add full names that might not be in the list
              const fullNames = Object.values(MODEL_ALIASES);
              
              const allModels = [...new Set([...shortNames, ...fullNames])];
              
              allModels.forEach((modelId) => {
                if (!json.data.some((m) => m.id === modelId)) {
                  json.data.push({
                    id: modelId,
                    object: "model",
                    owned_by: modelId.split('/')[0] || "custom"
                  });
                }
              });
            }
            const modifiedBody = JSON.stringify(json);
            const headers = { ...proxyRes.headers };
            headers["content-length"] = Buffer.byteLength(modifiedBody);
            delete headers["transfer-encoding"];
            res.writeHead(proxyRes.statusCode, headers);
            res.end(modifiedBody);
          } catch (e) {
            console.error("[proxy] Failed to parse /models response:", e.message);
            res.writeHead(proxyRes.statusCode, proxyRes.headers);
            res.end(Buffer.concat(resBody));
          }
        });
      } else {
        res.writeHead(proxyRes.statusCode, proxyRes.headers);
        proxyRes.pipe(res);
      }
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
