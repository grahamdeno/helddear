// Handwrytten API (https://api.handwrytten.com/v2). The key lives only in Vercel env HANDWRYTTEN_API_KEY.
const BASE = "https://api.handwrytten.com/v2";

async function hw(path, { method = "GET", body } = {}) {
  const r = await fetch(BASE + path, {
    method,
    headers: {
      Authorization: process.env.HANDWRYTTEN_API_KEY ?? "",
      Accept: "application/json",
      "Content-Type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await r.json().catch(() => ({}));
  if (!r.ok || json.status === "error" || (json.httpCode && json.httpCode >= 400)) {
    const err = new Error(json.message || `Handwrytten ${r.status}`);
    err.status = r.status;
    throw err;
  }
  return json;
}

const pickList = (json, ...keys) => {
  for (const k of keys) if (Array.isArray(json?.[k])) return json[k];
  return [];
};

export async function birthdayCategoryId() {
  try {
    const cats = pickList(await hw("/categories/list"), "categories", "data", "items");
    const match = cats.find((c) => /birthday/i.test(c.name ?? ""));
    if (match?.id) return match.id;
  } catch {}
  return 7; // Handwrytten's documented Birthday category id
}

/** Birthday cards with a cover image, as the app shows them. */
export async function listBirthdayCards() {
  const id = await birthdayCategoryId();
  const json = await hw(`/cards/list?category_id=${id}&with_images=1`);
  return pickList(json, "cards", "data", "items")
    .filter((c) => c.cover && c.id)
    .map((c) => ({
      id: Number(c.id),
      name: String(c.name ?? "Birthday card"),
      cover: c.cover,
      inside: c.inside_image ?? null,
      characters: Number(c.characters) || 300,
      orientation: c.orientation ?? null,
    }))
    .slice(0, 30);
}

export async function fontLabel() {
  if (process.env.HANDWRYTTEN_FONT) return process.env.HANDWRYTTEN_FONT;
  try {
    const fonts = pickList(await hw("/fonts/list"), "fonts", "data", "items");
    const f = fonts.find((x) => x.label || x.name);
    if (f) return f.label ?? f.name;
  } catch {}
  return "Chill Charity"; // Handwrytten's documented example label
}

/** Places one card, pen-written and mailed with the sender's return address. Returns Handwrytten's order id. */
export async function placeOrder(o) {
  const json = await hw("/orders/singleStepOrder", {
    method: "POST",
    body: {
      font_label: await fontLabel(),
      card_id: o.cardId,
      message: o.message,
      wishes: o.wishes,
      recipient_first_name: o.recipient.firstName,
      recipient_last_name: o.recipient.lastName,
      recipient_address1: o.recipient.address1,
      recipient_address2: o.recipient.address2 || undefined,
      recipient_city: o.recipient.city,
      recipient_state: o.recipient.state,
      recipient_zip: o.recipient.zip,
      sender_first_name: o.sender.firstName,
      sender_last_name: o.sender.lastName,
      sender_address1: o.sender.address1,
      sender_address2: o.sender.address2 || undefined,
      sender_city: o.sender.city,
      sender_state: o.sender.state,
      sender_zip: o.sender.zip,
      validate_address: true,
      client_metadata: o.reference,
    },
  });
  return json.order_id ?? json.id ?? null;
}
