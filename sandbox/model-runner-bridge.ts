const TARGET = "host.docker.internal:1234";

Bun.serve({
  port: 54321,
  hostname: "127.0.0.1",
  async fetch(req) {
    const url = `http://${TARGET}${new URL(req.url).pathname}${new URL(req.url).search}`;
    return fetch(url, {
      method: req.method,
      headers: { ...Object.fromEntries(req.headers), host: TARGET },
      body: req.body,
    });
  },
});

console.log("Bridge running on 127.0.0.1:54321 → LM Studio at", TARGET);
