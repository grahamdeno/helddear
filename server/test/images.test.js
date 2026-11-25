import { test } from "node:test";
import assert from "node:assert/strict";
import { allowedImage } from "../api/card-image.js";
import { toAppCard } from "../lib/handwrytten.js";

test("M6: card pictures point at Held Dear's server", () => {
  const c = toAppCard({ id: 1, name: "Gold Cross", cover: "https://d3e924qpzqov0g.cloudfront.net/cardimages/a.jpg", inside_image: null });
  assert.match(c.cover, /^\/_vercel\/image\?url=https%3A%2F%2Fd3e924qpzqov0g\.cloudfront\.net%2Fcardimages%2Fa\.jpg&w=480&q=75$/);
  assert.equal(c.inside, null);
});

test("M6: the picture endpoint only fetches Handwrytten's card images", () => {
  assert.ok(allowedImage("https://d3e924qpzqov0g.cloudfront.net/cardimages/a.jpg"));
  assert.equal(allowedImage("https://example.com/cardimages/a.jpg"), null);
  assert.equal(allowedImage("http://d3e924qpzqov0g.cloudfront.net/cardimages/a.jpg"), null);
  assert.equal(allowedImage("https://d3e924qpzqov0g.cloudfront.net/other/a.jpg"), null);
  assert.equal(allowedImage("https://d3e924qpzqov0g.cloudfront.net.evil.com/cardimages/a.jpg"), null);
  assert.equal(allowedImage("not a url"), null);
});

test("the image service only fetches Handwrytten's card folder", async () => {
  const { readFile } = await import("node:fs/promises");
  const cfg = JSON.parse(await readFile(new URL("../vercel.json", import.meta.url)));
  assert.deepEqual(cfg.images.remotePatterns, [{ protocol: "https", hostname: "d3e924qpzqov0g.cloudfront.net", pathname: "/cardimages/**" }]);
  assert.deepEqual(cfg.images.sizes, [480]);
});
