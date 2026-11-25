import { test } from "node:test";
import assert from "node:assert/strict";
import { mailedCardsOpen, familyPagesOn, pausedReply, pagesOffReply } from "../lib/switches.js";
import { handle } from "../api/order.js";
import { makeOrders } from "../lib/orders.js";
import { memStore } from "./helpers.js";

test("switches start off", () => {
  assert.equal(mailedCardsOpen({}), false);
  assert.equal(familyPagesOn({}), false);
  assert.equal(mailedCardsOpen({ MAILED_CARDS: "true" }), false);
  assert.equal(mailedCardsOpen({ MAILED_CARDS: "open" }), true);
  assert.equal(familyPagesOn({ FAMILY_PAGES: "on" }), true);
});

test("paused cards answer 503 and say nobody was charged", () => {
  const r = pausedReply({});
  assert.equal(r.status, 503);
  assert.equal(r.body.paused, true);
  assert.match(r.body.error, /weren't charged/);
  assert.equal(pausedReply({ MAILED_CARDS: "open" }), null);
});

test("family pages off: 404, but deleting still works", () => {
  assert.equal(pagesOffReply("POST", {}).status, 404);
  assert.equal(pagesOffReply("GET", {}).status, 404);
  assert.equal(pagesOffReply("DELETE", {}), null);
  assert.equal(pagesOffReply("POST", { FAMILY_PAGES: "on" }), null);
});

const addr = { firstName: "Ada", lastName: "D", address1: "1 Main St", city: "Springfield", state: "il", zip: "62701" };
const body = {
  reference: "abc12345-0000", cardId: 101, message: "Happy birthday, Ada!", wishes: "Love, Ben",
  recipient: addr, sender: { ...addr, firstName: "Ben" },
  applePay: { paymentData: Buffer.from('{"data":"x"}').toString("base64"), transactionIdentifier: "T1", network: "Visa", displayName: "Visa 1234" },
};
function fakeRes() {
  return { code: 0, json: null, status(c) { this.code = c; return this; }, json(j) { this.json = j; return this; } };
}
function deps(over = {}, seed = null) {
  const calls = { placed: 0, charged: 0, refunded: 0, tokens: 0 };
  const orders = makeOrders(memStore(), "live");
  return {
    calls,
    orders,
    seed: async () => { if (seed) await orders.put(body.reference, seed); },
    d: {
      pickerCards: async () => [{ id: 101, name: "Balloons", characters: 120 }, { id: 202, name: "From a section", characters: 300 }],
      tokenFromApplePay: async () => { calls.tokens++; return { id: "tok_1", card: { fingerprint: "fpA" } }; },
      charge: async () => { calls.charged++; return { id: "pi_1", status: "succeeded" }; },
      refund: async () => { calls.refunded++; },
      tagOrder: async () => {},
      placeOrder: async () => { calls.placed++; return 777; },
      isTestMode: () => false,
      pausedReply: () => null,
      orders,
      ...over,
    },
  };
}

async function run(over = {}, seed = null, b = body) {
  const x = deps(over, seed);
  await x.seed();
  const res = fakeRes();
  await handle({ method: "POST", body: b }, res, x.d);
  return { ...x, res, rec: await x.orders.get(b.reference) };
}

test("paused: no charge, no order", async () => {
  const { res, calls } = await run({ pausedReply: () => pausedReply({}) });
  assert.equal(res.code, 503);
  assert.equal(calls.charged + calls.placed, 0);
});

test("test mode never sends an order to Handwrytten (M2)", async () => {
  const { res, calls, rec } = await run({ isTestMode: () => true });
  assert.equal(res.code, 200);
  assert.equal(res.json.test, true);
  assert.match(res.json.orderId, /^test-/);
  assert.equal(calls.placed, 0);
  assert.equal(rec.state, "placed");
});

test("live mode places the order after the payment succeeds, and records each step", async () => {
  const { res, calls, rec } = await run();
  assert.equal(res.code, 200);
  assert.equal(calls.placed, 1);
  assert.equal(res.json.orderId, 777);
  assert.equal(rec.state, "placed");
  assert.equal(rec.orderNumber, "777");
  assert.equal(rec.paymentId, "pi_1");
});

test("a failed order is refunded, and says so only after the refund", async () => {
  const { res, calls, rec } = await run({ placeOrder: async () => { throw new Error("down"); } });
  assert.equal(res.code, 502);
  assert.equal(res.json.refunded, true);
  assert.equal(calls.refunded, 1);
  assert.equal(rec.state, "refunded");
});

test("N4: a failed refund never says refunded; it's marked for the daily check", async () => {
  const { res, rec } = await run({
    placeOrder: async () => { throw new Error("down"); },
    refund: async () => { throw new Error("stripe down"); },
  });
  assert.equal(res.code, 502);
  assert.notEqual(res.json.refunded, true);
  assert.equal(res.json.attention, true);
  assert.match(res.json.error, /support@tangomike\.app/);
  assert.doesNotMatch(res.json.error, /refunded/);
  assert.equal(rec.state, "attention");
});

test("M1/N1: a retry of a placed order returns it without charging or mailing again", async () => {
  const { res, calls } = await run({}, { state: "placed", orderNumber: "777" });
  assert.equal(res.code, 200);
  assert.equal(res.json.repeat, true);
  assert.equal(calls.charged + calls.placed + calls.tokens, 0);
});

test("N2: paid with no order number: places it without a new token or charge", async () => {
  const { res, calls, rec } = await run({}, { state: "charged", paymentId: "pi_1" });
  assert.equal(res.code, 200);
  assert.equal(calls.tokens + calls.charged, 0);
  assert.equal(calls.placed, 1);
  assert.equal(rec.state, "placed");
});

test("N2: if the last try may have reached Handwrytten, refund rather than mail twice", async () => {
  const { res, calls, rec } = await run({}, { state: "placing", paymentId: "pi_1" });
  assert.equal(calls.tokens + calls.charged + calls.placed, 0);
  assert.equal(calls.refunded, 1);
  assert.equal(res.json.refunded, true);
  assert.equal(rec.state, "refunded");
});

test("N2: Stripe's reused-key error is 'still being confirmed', never a 402", async () => {
  const { res, rec } = await run({ charge: async () => { const e = new Error("Stripe 400"); e.type = "idempotency_error"; throw e; } },
                                 { state: "started", cardPrint: "fpA" });
  assert.equal(res.code, 409);
  assert.equal(res.json.pending, true);
  assert.equal(rec.state, "started");
});

test("N3: a charge that times out is 'still being confirmed', never declined", async () => {
  const { res, rec } = await run({ charge: async () => { const e = new Error("t"); e.timedOut = true; throw e; } });
  assert.equal(res.code, 409);
  assert.equal(rec.state, "started");
});

test("a declined card is recorded as declined, and a new card can try", async () => {
  const { res, rec } = await run({ charge: async () => { const e = new Error("Stripe 402 card_error"); e.type = "card_error"; e.status = 402; throw e; } });
  assert.equal(res.code, 402);
  assert.equal(rec.state, "declined");
});

test("M1: a refunded reference can't be charged again", async () => {
  const { res, calls } = await run({}, { state: "refunded" });
  assert.equal(res.code, 409);
  assert.equal(calls.charged, 0);
});

test("M1: if the record can't be read, nothing is charged", async () => {
  const x = deps();
  x.d.orders = { ...x.orders, get: async () => { throw new Error("down"); } };
  const res = fakeRes();
  await handle({ method: "POST", body }, res, x.d);
  assert.equal(res.code, 502);
  assert.equal(x.calls.charged, 0);
});

test("M8: a threatening message is refused before any charge", async () => {
  const { res, calls } = await run({}, null, { ...body, message: "I know where you live." });
  assert.equal(res.code, 400);
  assert.equal(calls.charged, 0);
});

test("N9: a bad order is refused before Handwrytten is asked for cards", async () => {
  let asked = 0;
  const { res } = await run({ pickerCards: async () => { asked++; return []; } }, null, { ...body, recipient: { ...addr, zip: "1" } });
  assert.equal(res.code, 400);
  assert.equal(asked, 0);
});

test("N5: any card the picker shows can be ordered; others can't", async () => {
  const ok = await run({}, null, { ...body, cardId: 202 });
  assert.equal(ok.res.code, 200);
  const bad = await run({}, null, { ...body, cardId: 999 });
  assert.equal(bad.res.code, 400);
  assert.equal(bad.calls.charged, 0);
});

test("N7: one payment card can send ten cards a day, counted from the records", async () => {
  const x = deps();
  for (let i = 0; i < 10; i++) await x.orders.notePrint("fpA", `ref-${i}xxxxxxx`);
  const res = fakeRes();
  await handle({ method: "POST", body }, res, x.d);
  assert.equal(res.code, 429);
  assert.equal(x.calls.charged, 0);
});

test("N7: no fingerprint, no charge", async () => {
  const { res, calls } = await run({ tokenFromApplePay: async () => ({ id: "tok_1", card: {} }) });
  assert.equal(res.code, 402);
  assert.equal(calls.charged, 0);
});
