import { routes } from "./routing.ts";

const responseHeaders = {
  "content-type": "application/json; charset=utf-8",
};

Deno.serve((req) => {
  const url = new URL(req.url);
  for (const { method, pattern, capture, authenticate, handle } of routes) {
    if (method != req.method) {
      continue;
    }
    const match = pattern.exec(url.pathname);
    if (match === null) {
      continue;
    }
    if (!authenticate(req)) {
      return new Response(JSON.stringify({ message: "UNAUTHORIZED" }), {
        status: 401,
        headers: responseHeaders,
      });
    }
    return handle(req, capture(match));
  }
  return new Response(JSON.stringify({ message: "NOT FOUND" }), {
    status: 404,
    headers: responseHeaders,
  });
});
