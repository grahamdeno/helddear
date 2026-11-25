import { test } from "node:test";
import assert from "node:assert/strict";
import { mailedCardsOpen, familyPagesOn, pausedReply, pagesOffReply } from "../lib/switches.js";
import { handle } from "../api/order.js";

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
function deps(over = {}) {
  const calls = { placed: 0, charged: 0, refunded: 0 };
  return {
    calls,
    d: {
      listCards: async () => [{ id: 101, name: "Balloons", characters: 120 }],
      tokenFromApplePay: async () => ({ id: "tok_1" }),
      charge: async () => { calls.charged++; return { id: "pi_1", status: "succeeded" }; },
      refund: async () => { calls.refunded++; },
      tagOrder: async () => {},
      placeOrder: async () => { calls.placed++; return 777; },
      isTestMode: () => false,
      pausedReply: () => null,
      findByReference: async () => ({ state: "none" }),
      markRefunded: async () => {},
      ...over,
    },
  };
}

test("paused: no charge, no order", async () => {
  const { d, calls } = deps({ pausedReply: () => pausedReply({}) });
  const res = fakeRes();
  await handle({ method: "POST", body }, res, d);
  assert.equal(res.code, 503);
  assert.equal(calls.charged + calls.placed, 0);
});

test("test mode never sends an order to Handwrytten (M2)", async () => {
  const { d, calls } = deps({ isTestMode: () => true });
  const res = fakeRes();
  await handle({ method: "POST", body }, res, d);
  assert.equal(res.code, 200);
  assert.equal(res.json.test, true);
  assert.match(res.json.orderId, /^test-/);
  assert.equal(calls.placed, 0);
});

test("live mode places the order after the payment succeeds", async () => {
  const { d, calls } = deps();
  const res = fakeRes();
  await handle({ method: "POST", body }, res, d);
  assert.equal(res.code, 200);
  assert.equal(calls.placed, 1);
  assert.equal(res.json.orderId, 777);
});

test("a failed order is refunded", async () => {
  const { d, calls } = deps({ placeOrder: async () => { throw new Error("down"); } });
  const res = fakeRes();
  await handle({ method: "POST", body }, res, d);
  assert.equal(res.code, 502);
  assert.equal(calls.refunded, 1);
});

test("M1: a retry of a paid order returns it without charging or mailing again", async () => {
  const { d, calls } = deps({ findByReference: async () => ({ state: "charged", orderId: "777" }) });
  const res = fakeRes();
  await handle({ method: "POST", body }, res, d);
  assert.equal(res.code, 200);
  assert.equal(res.json.repeat, true);
  assert.equal(calls.charged + calls.placed, 0);
});

test("M1: a refunded reference can't be charged again", async () => {
  const { d, calls } = deps({ findByReference: async () => ({ state: "refunded" }) });
  const res = fakeRes();
  await handle({ method: "POST", body }, res, d);
  assert.equal(res.code, 409);
  assert.equal(calls.charged, 0);
});

test("M1: if payments can't be checked, nothing is charged", async () => {
  const { d, calls } = deps({ findByReference: async () => { throw new Error("down"); } });
  const res = fakeRes();
  await handle({ method: "POST", body }, res, d);
  assert.equal(res.code, 502);
  assert.equal(calls.charged, 0);
});
