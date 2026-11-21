// Handwrytten API (https://api.handwrytten.com/v2). The key lives only in Vercel env HANDWRYTTEN_API_KEY.
const BASE = "https://api.handwrytten.com/v2";

export async function hw(path, { method = "GET", body } = {}) {
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

export const pickList = (json, ...keys) => {
  for (const k of keys) if (Array.isArray(json?.[k])) return json[k];
  return [];
};

// Which Handwrytten category to show for each Held Dear occasion. Unknown occasions get birthday cards' fallback chain.
export const OCCASION_CATEGORY = {
  birthday: [/birthday/i],
  anniversary: [/anniversar/i, /love/i],
  christmas: [/christmas/i, /holiday/i],
  valentines: [/valentine/i, /love/i],
  mothersDay: [/mother/i, /everyday/i],
  fathersDay: [/father/i, /everyday/i],
  newBaby: [/baby/i, /congrat/i],
  graduation: [/graduat/i, /congrat/i],
  newHome: [/housewarm/i, /new home/i, /congrat/i],
  retirement: [/retire/i, /congrat/i],
  wedding: [/wedding/i, /congrat/i, /love/i],
  event: [/congrat/i],
  // A card for a reason, not a day (story 2.8). Keys match the app's CardReason raw values.
  justBecause: [/thinking/i, /blank/i, /friend/i, /everyday/i, /just for fun/i],
  getWell: [/get well/i, /feel better/i],
  thankYou: [/thank/i],
  thinkingOfYou: [/thinking/i, /friend/i, /everyday/i],
  congratulations: [/congrat/i],
  sympathy: [/sympathy/i, /condolence/i],
};

// Categories that aren't personal cards: photo templates, business, invitations (checked Nov 21, 2026 against
// Handwrytten's list: "Birthday (Photo Templates)" has 4 cards, "Birthday (Personal)" has 50).
const NOT_PERSONAL_CATEGORY = /photo template|business|customer|employee|donor|volunteer|real estate|homiversary|invitation|all categories|favorites/i;

export function pickCategory(cats, occasion) {
  const usable = cats.filter((c) => c.id > 0 && !NOT_PERSONAL_CATEGORY.test(c.name ?? ""));
  const patterns = [...(OCCASION_CATEGORY[occasion] ?? []), /blank/i, /everyday/i, /thinking/i, /general/i];
  for (const re of patterns) {
    const matches = usable.filter((c) => re.test(c.name ?? ""));
    const best = matches.find((c) => /personal/i.test(c.name ?? "")) ?? matches[0];
    if (best?.id) return best.id;
  }
  return null;
}

export async function categoryId(occasion = "birthday") {
  try {
    const cats = pickList(await hw("/categories/list"), "categories", "data", "items");
    const id = pickCategory(cats, occasion);
    if (id) return id;
  } catch {}
  return 7; // Handwrytten's documented Birthday category id
}

// Business cards (work anniversaries, employee thank-yous) share categories with personal ones; leave them out.
const BUSINESS = /work|employee|staff|team|client|customer|service|dedication|contribution|excellence|achievement|success|commitment|journey with us|hard work|business|company/i;
export const isPersonal = (name) => !BUSINESS.test(String(name ?? ""));

// Categories that suit any card ("More cards" in the app, Nov 21, 2026): blank, general, thinking of you, friendship.
export const ANY_OCCASION = [/blank/i, /^everyday/i, /just for fun/i, /general/i, /thinking/i, /friend/i, /any occasion/i];

/** Ids of the "any occasion" categories, other than the occasion's own. */
export function anyOccasionCategories(cats, excludeId) {
  const ids = [];
  for (const re of ANY_OCCASION) {
    for (const c of cats) {
      if (c.id > 0 && c.id !== excludeId && !NOT_PERSONAL_CATEGORY.test(c.name ?? "") && re.test(c.name ?? "") && !ids.includes(c.id)) ids.push(c.id);
    }
  }
  return ids.slice(0, 4);
}

/** More cards beyond the occasion's own: any-occasion designs, without the ones already shown. Up to 40. */
export async function listMoreCards(occasion = "birthday", shownIds = []) {
  let cats = [];
  try { cats = pickList(await hw("/categories/list"), "categories", "data", "items"); } catch { return []; }
  const own = await categoryId(occasion);
  const seen = new Set(shownIds);
  const more = [];
  for (const id of anyOccasionCategories(cats, own)) {
    try {
      for (const c of await cardsIn(id)) {
        if (!seen.has(c.id)) { seen.add(c.id); more.push(c); }
      }
    } catch {}
  }
  return more.slice(0, 40);
}

async function cardsIn(id) {
  const json = await hw(`/cards/list?category_id=${id}&with_images=1`);
  return pickList(json, "cards", "data", "items")
    .filter((c) => c.cover && c.id && isPersonal(c.name))
    .map((c) => ({
      id: Number(c.id),
      name: String(c.name ?? "Card"),
      cover: c.cover,
      inside: c.inside_image ?? null,
      characters: Number(c.characters) || 300,
      orientation: c.orientation ?? null,
    }));
}

/** Cards for an occasion with a cover image, as the app shows them. */
export async function listCards(occasion = "birthday") {
  const id = await categoryId(occasion);
  const json = await hw(`/cards/list?category_id=${id}&with_images=1`);
  return pickList(json, "cards", "data", "items")
    .filter((c) => c.cover && c.id && isPersonal(c.name))
    .map((c) => ({
      id: Number(c.id),
      name: String(c.name ?? "Card"),
      cover: c.cover,
      inside: c.inside_image ?? null,
      characters: Number(c.characters) || 300,
      orientation: c.orientation ?? null,
    }))
    .slice(0, 60);
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
