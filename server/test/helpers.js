// A Blob store kept in memory, for tests.
export function memStore() {
  const m = new Map();
  return {
    m,
    async getJSON(p) { return m.has(p) ? structuredClone(m.get(p)) : null; },
    async putJSON(p, o) { m.set(p, structuredClone(o)); },
    async listJSON(prefix) { return [...m].filter(([k]) => k.startsWith(prefix)).map(([, v]) => structuredClone(v)); },
  };
}
