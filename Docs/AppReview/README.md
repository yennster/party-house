# App Store review — resolution kit (Submission 1fd2f8a9…)

Working notes for clearing the 1.0.0 rejection (review date 2026-06-16). Two
guidelines were cited:

- **5.2.1 — Intellectual Property:** app "marketed to control external hardware
  from Hue, Home Assistant, and LIFX without the necessary authorization."
- **2.1 — Information Needed:** Apple wants a demo video of pairing + workflow on
  a *physical* device.

Nothing here is sent automatically — these are drafts for you to send / paste.

---

## Strategy: keep all three brands, supply authorization + look independent

Apple accepts either (a) documentary evidence of authorization **or** (b) removal
of the brand. We do a deliberate *both/and*, because reviewers sometimes reject
even with a letter if the app still reads as "the official X app":

1. **Authorization basis** — submit, per platform, the real basis that exists
   (developer-program terms / open-source license / published protocol) plus any
   permission email you get back. See the three `email-*.md` drafts.
2. **Independent-client signals** (already done in code/metadata):
   - Non-affiliation + trademark disclaimer in-app (Settings → About) and in the
     App Store description — single source of truth is `PartyLegal.disclaimer`
     (`Packages/PartyHouseKit/Sources/PartyUI/PartyLegal.swift`).
   - No third-party logos anywhere (app uses SF Symbols only). ✅
   - Brand-neutral app name ("Party House: Smart Lights"). ✅
   - Brand names used only descriptively, never as the app's identity. The
     screenshot title "Hue + Home Assistant + LIFX" was reframed to
     "Mix any lights into one zone."
   - Connects only to the user's **own** hardware/server with **their** credentials;
     free, open-source, no accounts, no data collection.

### The strongest single fact
The app is a bring-your-own-credentials client for hardware the **user already
owns**, using each vendor's **publicly published API**. It does not resell,
impersonate, or bundle anything from these vendors.

---

## Per-platform legal basis (what to claim + cite)

### Philips Hue / Signify — strongest
- Free, open **Hue Developer Program** (https://developers.meethue.com/register/).
  Its Developer Terms grant "a limited, revocable, non-transferable, non-exclusive
  right to access and use the API … **solely to create a product, app or service
  that operates with the Hue bridge.**" That is, in effect, authorization to build
  this app.
- **Do:** register, request local CLIP API access, save the confirmation email +
  that clause. "Friends of Hue" / "Works with Hue" is a *hardware* certification —
  not relevant.
- Trademark: nominative use of "Hue" is fine (no logos, disclaimer present).
  Precedent: iConnectHue, Hue Essentials ship this way.
- Terms: https://developers.meethue.com/terms-of-use-and-conditions/

### Home Assistant / Open Home Foundation — easiest (open source)
- Apache-2.0. No app developer program required to connect to the user's own
  server. Brand policy only restricts **commercial use of the logo/marks**
  ("anything designed to market or promote a product … that is for sale"); a free
  app arguably isn't even "commercial use" by their own definition, and we use no
  logo.
- **Do:** email partner@openhomefoundation.org for written confirmation (bonus
  evidence). Do **not** use the phrase "Works with Home Assistant" (that's a
  hardware certification mark).
- Policy: https://github.com/OpenHomeFoundation/brand-assets

### LIFX / Feit Electric — weakest; keep but de-emphasize
- LAN protocol is **officially published "for third-party developers creating
  client applications"** (https://lan.developer.lifx.com/docs/introduction), under
  LIFX Developer Terms (not an open license). No app partner program exists, so a
  signed letter is unlikely.
- Nominative use + disclaimer is how third-party LIFX apps (Lightbow, Light DJ)
  pass review.
- ⚠️ It's a **beta you cannot test on real hardware** and **cannot appear in the
  2.1 demo video**. It has been removed from marketing positioning (screenshot
  titles/keywords) and kept only as descriptive in-app text. Email
  social@lifx.com for permission, but don't block resubmission on it.

---

## App Review Information — reply note + documentation checklist

The send-ready reviewer reply and the exact "what to attach" checklist live in
**[`reviewer-reply.md`](reviewer-reply.md)**. Paste the reply into Resolution
Center (and mirror it in the Notes field), and attach the evidence it lists.

---

## Guideline 2.1 — demo video checklist
- Record on a **physical** iPhone/iPad (not the simulator). Screen-record + a
  second camera showing the hardware is ideal.
- Show the **initial pairing**: easiest with **Hue** — on camera, press the
  bridge link button, then tap Pair in the app within 30s.
- Show the **full workflow**: lights appearing, toggling a zone, applying a
  gradient, Everything-Off.
- **Do not** try to film LIFX (no bulbs / untested) — use Hue (and/or Home
  Assistant) as the "designated hardware."
- Upload (unlisted YouTube/Vimeo or a direct link) and put the URL in App Review
  Information. Include any demo account/token there too.
