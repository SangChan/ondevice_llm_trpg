// 의존성 없는 정적 서버. `.wasm`을 `application/wasm`으로 내려주지 않으면
// `WebAssembly.compileStreaming`이 거부하고, ESM/워커는 file:// 로는 뜨지 않는다.

import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import { createServer } from "node:http";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = fileURLToPath(new URL(".", import.meta.url));
const PORT = Number(process.env.PORT ?? 4173);

const CONTENT_TYPES = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".wasm": "application/wasm",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
};

createServer(async (request, response) => {
  const url = new URL(request.url, `http://${request.headers.host}`);
  const relative = normalize(decodeURIComponent(url.pathname)).replace(/^([/\\])+/, "");
  const target = relative === "" ? "index.html" : relative;
  const path = join(ROOT, target);

  // 루트 밖으로 나가는 경로는 거절한다.
  if (!path.startsWith(ROOT)) {
    response.writeHead(403).end("Forbidden");
    return;
  }

  try {
    const info = await stat(path);
    const file = info.isDirectory() ? join(path, "index.html") : path;
    response.writeHead(200, {
      "content-type": CONTENT_TYPES[extname(file)] ?? "application/octet-stream",
      "cache-control": "no-cache",
    });
    createReadStream(file).pipe(response);
  } catch {
    response.writeHead(404, { "content-type": "text/plain; charset=utf-8" }).end("Not found");
  }
}).listen(PORT, () => {
  console.log(`on-device-llm-trpg web → http://localhost:${PORT}`);
});
