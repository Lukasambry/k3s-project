const express = require("express");
const { pool } = require("../db");

const router = express.Router();

router.get("/", async (_req, res, next) => {
  try {
    const { rows } = await pool.query(
      "SELECT id, title, done, created_at FROM todos ORDER BY id DESC"
    );
    res.json(rows);
  } catch (err) { next(err); }
});

router.post("/", async (req, res, next) => {
  try {
    const { title } = req.body;
    if (!title || typeof title !== "string") {
      return res.status(400).json({ error: "title is required" });
    }
    const { rows } = await pool.query(
      "INSERT INTO todos(title) VALUES($1) RETURNING id, title, done, created_at",
      [title.trim()]
    );
    res.status(201).json(rows[0]);
  } catch (err) { next(err); }
});

router.put("/:id", async (req, res, next) => {
  try {
    const id = parseInt(req.params.id, 10);
    const { done } = req.body;
    const { rows } = await pool.query(
      "UPDATE todos SET done=$1 WHERE id=$2 RETURNING id, title, done, created_at",
      [!!done, id]
    );
    if (rows.length === 0) return res.status(404).json({ error: "not found" });
    res.json(rows[0]);
  } catch (err) { next(err); }
});

router.delete("/:id", async (req, res, next) => {
  try {
    const id = parseInt(req.params.id, 10);
    const { rowCount } = await pool.query("DELETE FROM todos WHERE id=$1", [id]);
    if (rowCount === 0) return res.status(404).json({ error: "not found" });
    res.status(204).end();
  } catch (err) { next(err); }
});

module.exports = router;
