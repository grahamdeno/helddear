// Validates an order from the app. Pure, so it can be tested without network.
const STATES = new Set("AL AK AZ AR CA CO CT DE DC FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY PR".split(" "));

const clean = (s, max) => (typeof s === "string" ? s.trim().slice(0, max) : "");

function address(a, who) {
  const out = {
    firstName: clean(a?.firstName, 40),
    lastName: clean(a?.lastName, 40),
    address1: clean(a?.address1, 80),
    address2: clean(a?.address2, 80),
    city: clean(a?.city, 50),
    state: clean(a?.state, 2).toUpperCase(),
    zip: clean(a?.zip, 10),
  };
  if (!out.firstName) return { error: `${who} name is missing` };
  if (!out.address1 || !out.city) return { error: `${who} street and city are needed` };
  if (!STATES.has(out.state)) return { error: `${who} state should be a 2-letter US state` };
  if (!/^\d{5}(-\d{4})?$/.test(out.zip)) return { error: `${who} ZIP code looks wrong` };
  return { value: out };
}

/** Everything that can be checked without Handwrytten (Fable N9): checked first, so a bad order never reaches it.
 *  The card itself is checked after, against the cards the picker shows. */
export function validateOrder(body, cards = null) {
  const reference = clean(body?.reference, 64);
  if (!/^[A-Za-z0-9-]{8,64}$/.test(reference)) return { error: "Missing order reference" };
  const cardId = Number(body?.cardId);
  if (!Number.isInteger(cardId) || cardId <= 0) return { error: "That card isn't available" };
  let card = { id: cardId, characters: 1000 };
  if (cards) {
    card = cards.find((c) => c.id === cardId);
    if (!card) return { error: "That card isn't available" };
  }
  const message = clean(body?.message, 1000);
  if (!message) return { error: "The message is empty" };
  const wishes = clean(body?.wishes, 80);
  if (message.length + wishes.length > card.characters) return { error: "The message is too long for this card" };
  const recipient = address(body?.recipient, "Recipient");
  if (recipient.error) return recipient;
  const sender = address(body?.sender, "Return address");
  if (sender.error) return sender;
  const ap = body?.applePay ?? {};
  if (!ap.paymentData || !ap.transactionIdentifier) return { error: "Apple Pay details are missing" };
  let paymentData;
  try {
    paymentData = Buffer.from(String(ap.paymentData), "base64").toString("utf8");
    JSON.parse(paymentData);
  } catch {
    return { error: "Apple Pay details are unreadable" };
  }
  return {
    value: {
      reference, card, message, wishes,
      recipient: recipient.value, sender: sender.value,
      applePay: {
        paymentData,
        transactionIdentifier: clean(ap.transactionIdentifier, 200),
        network: clean(ap.network, 40),
        displayName: clean(ap.displayName, 80),
      },
    },
  };
}

// $7.99 (Graham, Nov 24, 2026): Handwrytten $4.57 with the stamp, Stripe about $0.50, leaving room for a resend.
export const retailCents = () => Number(process.env.RETAIL_CENTS) || 799;
