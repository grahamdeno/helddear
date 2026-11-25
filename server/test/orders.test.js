import { test } from "node:test";
import assert from "node:assert/strict";
import { makeOrders, standingOf, needsAttention } from "../lib/orders.js";
import { checkOrders } from "../lib/order-check.js";
import { handle as status } from "../api/order-status.js";
import { isLiveKey, isTestMode, alreadyPaying } from "../lib/stripe.js";
import { within } from "../lib/timeout.js";
import { memStore } from "./helpers.js";

test("N1: a record holds no names, addresses or message, and paths hide the reference", async () => {
  const store = memStore();
  const orders = makeOrders(store, "live");
  const s = orders.session("ref-12345678", null);
  await s.write({ state: "started", cardPrint: "fpA" });
  await s.write({ state: "charged", paymentId: "pi_1" });
  const [path] = [...store.m.keys()];
  assert.ok(!path.includes("ref-12345678"));
  const rec = await orders.get("ref-12345678");
  assert.equal(rec.state, "charged");
  assert.equal(rec.cardPrint, "fpA");
  assert.deepEqual(Object.keys(rec).sort(), ["cardPrint", "created", "paymentId", "ref", "reference", "state", "updated"]);
});

test("N1: test and live records are kept apart", async () => {
  const store = memStore();
  await makeOrders(store, "test").put("ref-12345678", { state: "placed" });
  assert.equal(await makeOrders(store, "live").get("ref-12345678"), null);
});

test("N1: what the app is told", () => {
  assert.equal(standingOf(null).state, "none");
  assert.equal(standingOf({ state: "declined" }).state, "none");
  assert.equal(standingOf({ state: "started" }).state, "pending");
  assert.deepEqual(standingOf({ state: "placed", orderNumber: "777" }), { state: "charged", orderId: "777" });
  assert.equal(standingOf({ state: "placing" }).state, "charged");
  assert.equal(standingOf({ state: "refunded" }).state, "refunded");
  assert.equal(standingOf({ state: "attention" }).state, "attention");
});

test("N1: order-status reads the record, not Stripe", async () => {
  const store = memStore();
  const orders = makeOrders(store, "live");
  await orders.put("ref-12345678", { state: "placed", orderNumber: "777" });
  const res = { code: 0, body: null, status(c) { this.code = c; return this; }, json(j) { this.body = j; return this; } };
  await status({ method: "GET", query: { reference: "ref-12345678" } }, res, { pausedReply: () => null, orders });
  assert.equal(res.code, 200);
  assert.deepEqual(res.body, { state: "charged", orderId: "777" });
});

test("N7: the daily count comes from the records, per payment card, for 24 hours", async () => {
  const store = memStore();
  const orders = makeOrders(store, "live");
  for (let i = 0; i < 3; i++) await orders.notePrint("fpA", `ref-a${i}xxxxxx`);
  await orders.notePrint("fpB", "ref-bxxxxxxx");
  assert.equal(await orders.countToday("fpA"), 3);
  assert.equal(await orders.countToday("fpA", Date.now() + 2 * 86400000), 0);
});

test("N3: the daily check finds stuck and failed orders, and only those", async () => {
  const old = new Date(Date.now() - 20 * 60000).toISOString();
  const fresh = new Date().toISOString();
  const rows = [
    { ref: "a", state: "charged", updated: old },
    { ref: "b", state: "charged", updated: fresh },
    { ref: "c", state: "placed", updated: old },
    { ref: "d", state: "attention", why: "refund failed", updated: fresh },
    { ref: "e", state: "placing", updated: old },
    { ref: "f", state: "refunded", updated: old },
  ];
  assert.deepEqual(needsAttention(rows).map((r) => r.ref), ["a", "d", "e"]);
  const store = memStore();
  const orders = makeOrders(store, "live");
  await orders.put("ref-12345678", { state: "started", cardPrint: "fpA" });
  const rec = await orders.get("ref-12345678");
  store.m.set([...store.m.keys()][0], { ...rec, updated: old });
  const found = await checkOrders(orders, { searchByReference: async () => ({ state: "none" }) });
  assert.equal(found.open.length, 0);
  assert.equal(found.settled[0].to, "declined");
  assert.equal((await orders.get("ref-12345678")).state, "declined");
});

test("R3: writes never re-read the store; a stale store can't undo a step", async () => {
  const store = memStore();
  let reads = 0;
  const stale = { ...store, getJSON: async () => { reads++; return null; } };
  const orders = makeOrders(stale, "live");
  const s = orders.session("ref-12345678", null);
  await s.write({ state: "started", cardPrint: "fpA" });
  await s.write({ state: "charged", paymentId: "pi_1" });
  await s.write({ state: "placed", orderNumber: "777" });
  assert.equal(reads, 0);
  const saved = [...store.m.values()].find((v) => v.state);
  assert.equal(saved.state, "placed");
  assert.equal(saved.cardPrint, "fpA");
  assert.equal(saved.paymentId, "pi_1");
});

test("R4: a person resolves an order in Stripe; the daily check settles it and lists only what's left", async () => {
  const old = new Date(Date.now() - 20 * 60000).toISOString();
  const store = memStore();
  const orders = makeOrders(store, "live");
  const put = async (ref, fields) => {
    const rec = await orders.put(ref, fields);
    store.m.set([...store.m.entries()].find(([, v]) => v.reference === ref)[0], { ...rec, updated: old });
  };
  await put("ref-aaaaaaaa", { state: "attention", why: "refund failed", paymentId: "pi_a" });
  await put("ref-bbbbbbbb", { state: "charged", paymentId: "pi_b" });
  await put("ref-cccccccc", { state: "placing", paymentId: "pi_c" });
  await put("ref-dddddddd", { state: "attention", why: "refund failed", paymentId: "pi_d" });
  const stripe = {
    paymentStanding: async (id) => ({
      pi_a: { refunded: false, resolved: "refunded", orderNumber: null },
      pi_b: { refunded: true, resolved: null, orderNumber: null },
      pi_c: { refunded: false, resolved: null, orderNumber: "888" },
      pi_d: { refunded: false, resolved: null, orderNumber: null },
    })[id],
  };
  const r = await checkOrders(orders, stripe);
  assert.deepEqual(r.open.map((o) => o.paymentId), ["pi_d"]);
  assert.equal(r.settled.length, 3);
  assert.deepEqual(standingOf(await orders.get("ref-aaaaaaaa")), { state: "refunded", orderId: null });
  assert.deepEqual(standingOf(await orders.get("ref-cccccccc")), { state: "charged", orderId: "888" });
  const again = await checkOrders(orders, stripe);
  assert.deepEqual(again.open.map((o) => o.paymentId), ["pi_d"], "resolved orders aren't listed again");
});

test("N6: only sk_live_ and rk_live_ keys are live", () => {
  assert.equal(isLiveKey("sk_live_x"), true);
  assert.equal(isLiveKey("rk_live_x"), true);
  for (const k of ["sk_test_x", "rk_test_x", "", undefined, "pk_live_x", "live"]) {
    assert.equal(isLiveKey(k), false, String(k));
    assert.equal(isTestMode(k), true, String(k));
  }
});

test("N2: Stripe's reused-key errors read as already paying", () => {
  assert.equal(alreadyPaying({ type: "idempotency_error" }), true);
  assert.equal(alreadyPaying({ code: "idempotency_key_in_use" }), true);
  assert.equal(alreadyPaying({ type: "card_error", code: "card_declined", status: 402 }), false);
});

test("N3: calls give up at their time limit", async () => {
  const slow = (signal) => new Promise((ok, no) => {
    const t = setTimeout(ok, 500);
    signal.addEventListener("abort", () => { clearTimeout(t); no(signal.reason); });
  });
  await assert.rejects(within(20, "slow", slow), (e) => e.timedOut === true);
});

test("N6: Handwrytten never gets an order without a live payments key", async () => {
  const { placeOrder } = await import("../lib/handwrytten.js");
  for (const k of ["sk_test_x", "", undefined]) {
    await assert.rejects(placeOrder({ cardId: 1, recipient: {}, sender: {} }, k), /only placed with live payments/);
  }
});
