import { test } from "node:test";
import assert from "node:assert/strict";
import { addNote, cleanup, createPage, deletePage, keyMatches, memoryStore, ownerView, removeNote, visitorView } from "../lib/pages.js";
import { giftPage, invitePage } from "../lib/html.js";

const NOW = Date.parse("2026-11-12T12:00:00Z");
const base = "https://helddear-mail.vercel.app";
const body = { firstName: "Mom", occasion: "birthday", date: "2026-12-09", fromName: "Graham", message: "Write a line for Mom." };
const parts = (url) => url.split("/").slice(-2);

test("create, add notes, owner and gift views, keys are hashed", async () => {
  const s = memoryStore();
  const c = await createPage(s, body, base, NOW);
  assert.equal(c.status, 200);
  const [id, invite] = parts(c.body.inviteURL);
  const [, gift] = parts(c.body.giftURL);
  const stored = JSON.stringify([...s.m.values()]);
  for (const k of [c.body.ownerKey, invite, gift]) assert.ok(!stored.includes(k), "raw key stored");

  assert.equal((await addNote(s, { id, k: invite, name: "Jo", text: "Love you", consent: "on" }, NOW)).status, 200);
  assert.equal((await addNote(s, { id, k: invite, name: "Jo", text: "No consent" }, NOW)).status, 400);
  assert.equal((await addNote(s, { id, k: gift, name: "X", text: "wrong key", consent: true }, NOW)).status, 404);

  const o = await ownerView(s, id, c.body.ownerKey, NOW);
  assert.equal(o.body.notes.length, 1);
  assert.equal(o.body.page.ownerHash, undefined);
  assert.equal((await ownerView(s, id, invite, NOW)).status, 404);

  const inv = await visitorView(s, "invite", id, invite, NOW);
  assert.equal(inv.count, 1);
  assert.deepEqual(inv.notes, [], "family can't read others' notes");
  const g = await visitorView(s, "gift", id, gift, NOW);
  assert.equal(g.notes[0].text, "Love you");
  assert.equal((await visitorView(s, "gift", id, invite, NOW)).status, 404);

  assert.equal((await removeNote(s, id, c.body.ownerKey, o.body.notes[0].id)).status, 200);
  assert.equal((await ownerView(s, id, c.body.ownerKey, NOW)).body.notes.length, 0);
  assert.equal((await deletePage(s, id, c.body.ownerKey)).status, 200);
  assert.equal(s.m.size, 0);
});

test("pages end 30 days after the day and cleanup removes them", async () => {
  const s = memoryStore();
  const c = await createPage(s, body, base, NOW);
  const [id, invite] = parts(c.body.inviteURL);
  const later = Date.parse("2027-01-09T13:00:00Z");
  assert.equal((await visitorView(s, "invite", id, invite, later)).status, 410);
  assert.equal(await cleanup(s, NOW), 0);
  assert.equal(await cleanup(s, later), 1);
  assert.equal(s.m.size, 0);
});

test("rejects bad input", async () => {
  const s = memoryStore();
  assert.equal((await createPage(s, { ...body, date: "2029-01-01" }, base, NOW)).status, 400);
  assert.equal((await createPage(s, { ...body, firstName: " " }, base, NOW)).status, 400);
  assert.equal((await createPage(s, { ...body, photo: Buffer.from("GIF89a").toString("base64") }, base, NOW)).status, 400);
  assert.equal((await visitorView(s, "invite", "../../etc", "x", NOW)).status, 404);
  assert.equal(keyMatches("", "abc"), false);
});

test("pages escape untrusted text", () => {
  const page = { firstName: "<b>Mom</b>", occasion: "christmas", date: "2026-12-25", fromName: "G", message: "", photoURL: null };
  const html = giftPage({ page, notes: [{ name: "<script>", text: "x\"><img src=x onerror=alert(1)>" }] });
  assert.ok(!html.includes("<script>"));
  assert.ok(!html.includes("<img src=x"));
  assert.ok(html.includes("Merry Christmas, &lt;b&gt;Mom&lt;/b&gt;"));
  assert.ok(invitePage({ page, count: 0, id: "a", key: "b" }).includes("deleted 30 days after the day"));
});
