// Vercel Blob storage for family pages. Needs BLOB_READ_WRITE_TOKEN (set when the Blob store is connected).
// Paths hold a 128-bit random id, and the stored JSON keeps only key hashes.
import { del, list, put } from "@vercel/blob";

const opts = (contentType) => ({ access: "public", addRandomSuffix: false, allowOverwrite: true, contentType, cacheControlMaxAge: 60 });
const fresh = (url) => `${url}${url.includes("?") ? "&" : "?"}v=${Date.now()}`;

async function all(prefix) {
  const out = [];
  let cursor;
  do {
    const r = await list({ prefix, cursor, limit: 1000 });
    out.push(...r.blobs);
    cursor = r.hasMore ? r.cursor : undefined;
  } while (cursor);
  return out;
}

export const blobStore = {
  async putJSON(path, obj) { await put(path, JSON.stringify(obj), opts("application/json")); },
  async putJPEG(path, buf) { return (await put(path, buf, opts("image/jpeg"))).url; },
  async getJSON(path) {
    const b = (await list({ prefix: path, limit: 5 })).blobs.find((x) => x.pathname === path);
    if (!b) return null;
    const r = await fetch(fresh(b.url));
    return r.ok ? r.json() : null;
  },
  async listJSON(prefix, filter = (p) => p.endsWith(".json")) {
    const blobs = (await all(prefix)).filter((b) => filter(b.pathname));
    const rows = await Promise.all(blobs.map((b) => fetch(fresh(b.url)).then((r) => (r.ok ? r.json() : null)).catch(() => null)));
    return rows.filter(Boolean);
  },
  async del(path) {
    const b = (await list({ prefix: path, limit: 5 })).blobs.find((x) => x.pathname === path);
    if (b) await del(b.url);
  },
  async delPrefix(prefix) {
    const blobs = await all(prefix);
    if (blobs.length) await del(blobs.map((b) => b.url));
  },
};

export const baseURL = () => process.env.PUBLIC_BASE_URL || "https://helddear-mail.vercel.app";
