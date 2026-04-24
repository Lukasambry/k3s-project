import { useEffect, useState } from "react";

export default function App() {
  const [todos, setTodos] = useState([]);
  const [title, setTitle] = useState("");
  const [err, setErr] = useState(null);

  async function load() {
    try {
      const r = await fetch("/api/todos");
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      setTodos(await r.json());
      setErr(null);
    } catch (e) { setErr(String(e)); }
  }

  async function add(e) {
    e.preventDefault();
    if (!title.trim()) return;
    await fetch("/api/todos", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title }),
    });
    setTitle("");
    load();
  }

  async function toggle(t) {
    await fetch(`/api/todos/${t.id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ done: !t.done }),
    });
    load();
  }

  async function remove(t) {
    await fetch(`/api/todos/${t.id}`, { method: "DELETE" });
    load();
  }

  useEffect(() => { load(); }, []);

  return (
    <div className="container">
      <h1>Todo — cluster k3s</h1>
      <form onSubmit={add}>
        <input
          value={title}
          onChange={e => setTitle(e.target.value)}
          placeholder="Nouvelle tâche…"
        />
        <button type="submit">Ajouter</button>
      </form>
      {err && <p className="error">Erreur : {err}</p>}
      <ul>
        {todos.map(t => (
          <li key={t.id} className={t.done ? "done" : ""}>
            <label>
              <input type="checkbox" checked={t.done} onChange={() => toggle(t)} />
              {t.title}
            </label>
            <button onClick={() => remove(t)}>×</button>
          </li>
        ))}
      </ul>
      <footer>pod : {location.hostname}</footer>
    </div>
  );
}
