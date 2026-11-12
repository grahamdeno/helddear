import { isTestMode } from "../lib/stripe.js";

export default function handler(req, res) {
  res.status(200).json({
    ok: true,
    testMode: isTestMode(),
    handwryttenKey: Boolean(process.env.HANDWRYTTEN_API_KEY),
    stripeKey: Boolean(process.env.STRIPE_SECRET_KEY),
  });
}
