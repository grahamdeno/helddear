// Family pages: a page for one person's day that family can add notes to, and a link for that person.
// No accounts. Three random keys per page (owner, invite, gift); only their hashes are stored.
// Everything is deleted 30 days after the day. Pure logic plus a store that is passed in, so it tests offline.
import { createHash, randomBytes, timingSafeEqual } from "node:crypto";

export const LIMITS = { name: 40, message: 600, note: 500, notes: 60, photoBytes: 700_000, keepDays: 30 };
export const OCCASIONS = new Set([
  "birthday", "anniversary", "christmas", "valentines", "mothersDay", "fathersDay",
  "newBaby", "graduation", "newHome", "retirement",
]);

export const newKey = () => randomBytes(16).toString("base64url");
export const hash = (s) => createHash("sha256").update(String(s ?? "")).digest("hex");
const validId = (id) => typeof id === "string" && /^[A-Za-z0-9_-]{16,32}$/.test(id);

export function keyMatches(given, storedHash) {
  if (typeof given !== "string" || !given || typeof storedHash !== "string") return false;
  const a = Buffer.from(hash(given), "hex");
  const b = Buffer.from(storedHash, "hex");
  return a.length === b.length && timingSafeEqual(a, b);
}

const clean = (s, max) => (typeof s === "string" ? s.replace(/\s+/g, " ").trim().slice(0, max) : "");
const cleanText = (s, max) => (typeof s === "string" ? s.replace(/\r\n?/g, "\n").replace(/\n{3,}/g, "\n\n").trim().slice(0, max) : "");
const DAY = 86_400_000;

export function validatePage(body, now = Date.now()) {
  const firstName = clean(body?.firstName, LIMITS.name);
  if (!firstName) return { error: "The name is missing" };
  const occasion = OCCASIONS.has(body?.occasion) ? body.occasion : "birthday";
  const date = clean(body?.date, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return { error: "The date looks wrong" };
  const t = Date.parse(date + "T12:00:00Z");
  if (Number.isNaN(t) || t < now - 2 * DAY || t > now + 400 * DAY) return { error: "The date should be within the next year" };
  const fromName = clean(body?.fromName, LIMITS.name);
  if (!fromName) return { error: "Your name is missing" };
  const message = cleanText(body?.message, LIMITS.message);
  let photo = null;
  if (body?.photo) {
    try { photo = Buffer.from(String(body.photo), "base64"); } catch { return { error: "The photo is unreadable" }; }
    if (photo.length > LIMITS.photoBytes) return { error: "The photo is too large" };
    if (photo[0] !== 0xff || photo[1] !== 0xd8) return { error: "The photo should be a JPEG" };
  }
  return { value: { firstName, occasion, date, fromName, message, photo } };
}

export function validateNote(body) {
  const name = clean(body?.name, LIMITS.name);
  if (!name) return { error: "Add your name" };
  const text = cleanText(body?.text, LIMITS.note);
  if (!text) return { error: "Write a note" };
  const consent = body?.consent === true || body?.consent === "on" || body?.consent === "true";
  if (!consent) return { error: "Check the box to share your note" };
  return { value: { name, text } };
}

export const expiresAt = (date) => Date.parse(date + "T12:00:00Z") + LIMITS.keepDays * DAY;
export const isExpired = (page, now = Date.now()) => !page || now > page.expiresAt;
const pagePath = (id) => `pages/${id}/page.json`;
const notesPrefix = (id) => `pages/${id}/notes/`;

const publicPage = (p) => ({
  id: p.id, firstName: p.firstName, occasion: p.occasion, date: p.date, fromName: p.fromName,
  message: p.message, photoURL: p.photoURL ?? null, expiresAt: p.expiresAt,
});
const publicNote = (n) => ({ id: n.id, name: n.name, text: n.text, createdAt: n.createdAt });

async function load(store, id) {
  if (!validId(id)) return null;
  return store.getJSON(pagePath(id));
}

async function notesOf(store, id) {
  const notes = await store.listJSON(notesPrefix(id));
  return notes.filter((n) => n && n.id).sort((a, b) => a.createdAt - b.createdAt);
}

/** Creates a page. Returns the three keys once; they are never stored in the clear. */
export async function createPage(store, body, baseURL, now = Date.now()) {
  const checked = validatePage(body, now);
  if (checked.error) return { status: 400, body: { error: checked.error } };
  const { photo, ...v } = checked.value;
  const id = newKey(), owner = newKey(), invite = newKey(), gift = newKey();
  const page = { ...v, id, ownerHash: hash(owner), inviteHash: hash(invite), giftHash: hash(gift),
                 createdAt: now, expiresAt: expiresAt(v.date), photoURL: null };
  if (photo) page.photoURL = await store.putJPEG(`pages/${id}/photo.jpg`, photo);
  await store.putJSON(pagePath(id), page);
  return { status: 200, body: {
    id, ownerKey: owner, expiresAt: page.expiresAt,
    inviteURL: `${baseURL}/p/${id}/${invite}`, giftURL: `${baseURL}/g/${id}/${gift}`,
  } };
}

export async function ownerView(store, id, key, now = Date.now()) {
  const page = await load(store, id);
  if (!page || !keyMatches(key, page.ownerHash)) return { status: 404, body: { error: "Not found" } };
  if (isExpired(page, now)) return { status: 410, body: { error: "This page has ended" } };
  return { status: 200, body: { page: publicPage(page), notes: (await notesOf(store, id)).map(publicNote) } };
}

export async function deletePage(store, id, key) {
  const page = await load(store, id);
  if (!page || !keyMatches(key, page.ownerHash)) return { status: 404, body: { error: "Not found" } };
  await store.delPrefix(`pages/${id}/`);
  return { status: 200, body: { deleted: true } };
}

export async function addNote(store, body, now = Date.now()) {
  const page = await load(store, body?.id);
  if (!page || !keyMatches(body?.k, page.inviteHash)) return { status: 404, body: { error: "This link isn't valid" } };
  if (isExpired(page, now)) return { status: 410, body: { error: "This page has ended" } };
  const checked = validateNote(body);
  if (checked.error) return { status: 400, body: { error: checked.error } };
  const existing = await notesOf(store, page.id);
  if (existing.length >= LIMITS.notes) return { status: 409, body: { error: "This page is full" } };
  const note = { id: newKey(), ...checked.value, createdAt: now };
  await store.putJSON(`${notesPrefix(page.id)}${note.id}.json`, note);
  return { status: 200, body: { note: publicNote(note) } };
}

export async function removeNote(store, id, key, noteId) {
  const page = await load(store, id);
  if (!page || !keyMatches(key, page.ownerHash) || !validId(noteId)) return { status: 404, body: { error: "Not found" } };
  await store.del(`${notesPrefix(id)}${noteId}.json`);
  return { status: 200, body: { deleted: true } };
}

/** What a web visitor sees: the invite page (family) or the gift page (the person). */
export async function visitorView(store, mode, id, key, now = Date.now()) {
  const page = await load(store, id);
  const want = mode === "gift" ? page?.giftHash : page?.inviteHash;
  if (!page || !keyMatches(key, want)) return { status: 404 };
  if (isExpired(page, now)) return { status: 410 };
  const notes = await notesOf(store, id);
  return { status: 200, page: publicPage(page), notes: mode === "gift" ? notes.map(publicNote) : [], count: notes.length };
}

export async function cleanup(store, now = Date.now()) {
  const pages = await store.listJSON("pages/", (path) => path.endsWith("/page.json"));
  let removed = 0;
  for (const p of pages) {
    if (p?.id && isExpired(p, now)) { await store.delPrefix(`pages/${p.id}/`); removed++; }
  }
  return removed;
}

/** An in-memory store with the same shape as the Blob store. For tests. */
export function memoryStore() {
  const m = new Map();
  return {
    m,
    async putJSON(path, obj) { m.set(path, JSON.parse(JSON.stringify(obj))); },
    async putJPEG(path) { m.set(path, "jpeg"); return `https://example.public.blob.vercel-storage.com/${path}`; },
    async getJSON(path) { return m.has(path) ? m.get(path) : null; },
    async listJSON(prefix, filter = (p) => p.endsWith(".json")) {
      return [...m.entries()].filter(([k]) => k.startsWith(prefix) && filter(k)).map(([, v]) => v);
    },
    async del(path) { m.delete(path); },
    async delPrefix(prefix) { for (const k of [...m.keys()]) if (k.startsWith(prefix)) m.delete(k); },
  };
}
