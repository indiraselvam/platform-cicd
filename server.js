const http = require("http");

const port = 8080;

const server = http.createServer((req, res) => {
    if (req.url === "/healthz" || req.url === "/readyz") {
        res.writeHead(200, { "Content-Type": "text/plain" });
        res.end("OK");
        return;
    }

    res.writeHead(200, { "Content-Type": "text/plain" });
    res.end("Hello from GitHub Actions + Argo CD + EKS!");
});

server.listen(port, "0.0.0.0", () => {
    console.log(`Application listening on port ${port}`);
});