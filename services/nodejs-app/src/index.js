const express = require("express");
const promClient = require("prom-client");
const { Pool } = require("pg");

// DB connection — reads credentials from environment variables.
// Those env vars come from AWS Secrets Manager via the CSI driver.
const pool = new Pool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASS,
    database: process.env.DB_NAME || "appdb",
    port: 5432,
    ssl: { rejectUnauthorized: false },
    max: 10,
});

const app = express();
app.use(express.json());

// Prometheus metrics
promClient.collectDefaultMetrics();
const httpRequests = new promClient.Counter({
    name: "http_requests_total",
    help: "Total HTTP requests",
    labelNames: ["method", "route", "status"],
});
const latency = new promClient.Histogram({
    name: "http_request_duration_seconds",
    help: "HTTP latency in seconds",
    labelNames: ["method", "route"],
    buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1, 2],
});

app.use((req, res, next) => {
    const end = latency.startTimer({ method: req.method, route: req.path });
    res.on("finish", () => {
        httpRequests.inc({ method: req.method, route: req.path, status: res.statusCode });
        end();
    });
    next();
});

// Health check — Kubernetes calls this to know the app is alive
app.get("/health", (req, res) => {
    res.json({ status: "ok", service: "nodejs-app" });
});

// List all items from the database
app.get("/api/items", async (req, res) => {
    try {
        const { rows } = await pool.query(
            "SELECT * FROM items ORDER BY created_at DESC LIMIT 100"
        );
        res.json({ items: rows, count: rows.length });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Create a new item
app.post("/api/items", async (req, res) => {
    const { name, value } = req.body;
    try {
        const { rows } = await pool.query(
            "INSERT INTO items(name, value) VALUES($1, $2) RETURNING *",
            [name, value]
        );
        res.status(201).json(rows[0]);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Prometheus metrics endpoint
app.get("/metrics", async (req, res) => {
    res.set("Content-Type", promClient.register.contentType);
    res.end(await promClient.register.metrics());
});

// Create the database table on startup if it does not exist
async function init() {
    await pool.query(`
    CREATE TABLE IF NOT EXISTS items (
      id         SERIAL PRIMARY KEY,
      name       TEXT NOT NULL,
      value      TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW()
    )
  `);
    console.log("Database table ready");
}

init()
    .then(() => app.listen(3000, () => console.log("Node.js app running on port 3000")))
    .catch(err => { console.error("Startup failed:", err); process.exit(1); });
