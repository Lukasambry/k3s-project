const express = require("express");
const { migrate, ping } = require("./db");
const todosRouter = require("./routes/todos");

const app = express();
app.use(express.json());

app.get("/health", async (_req, res) => {
  try {
    await ping();
    res.status(200).json({ status: "ok" });
  } catch (_e) {
    res.status(503).json({ status: "db unreachable" });
  }
});

app.use("/api/todos", todosRouter);

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: "internal" });
});

const PORT = parseInt(process.env.BACKEND_PORT || "3000", 10);

(async () => {
  let ready = false;
  for (let i = 0; i < 30 && !ready; i++) {
    try { await migrate(); ready = true; }
    catch (e) {
      console.log(`DB not ready (${e.code || e.message}), retry ${i + 1}/30 in 2s…`);
      await new Promise(r => setTimeout(r, 2000));
    }
  }
  if (!ready) { console.error("DB never became ready, exiting"); process.exit(1); }
  app.listen(PORT, () => console.log(`backend listening on :${PORT}`));
})();
