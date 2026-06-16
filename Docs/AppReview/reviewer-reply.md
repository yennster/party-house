# Draft reply to App Store Review — Submission 1fd2f8a9-4c1a-4209-ac29-58faa146e15c

Two pieces:
1. **Attachments / fields** to populate in App Store Connect → App Review
   Information (the documentation checklist below).
2. **The reply message** to paste into Resolution Center (and mirror in the
   "Notes" field).

Replace every `[bracketed]` placeholder before sending.

---

## 1. Documentation checklist — exactly what to provide

### Guideline 2.1 (required — this one is non-negotiable)
- [ ] **Demo video link** in the *App Review Information → Notes* (e.g. unlisted
      YouTube/Vimeo). Must show, on a **physical** iPhone/iPad (not simulator):
      the initial **pairing** (press the Hue bridge link button on camera → Pair
      in app) and the **full workflow** (lights load, toggle a zone, apply a
      gradient, Everything-Off).
- [ ] **Demo connection details** in the Notes so the reviewer could connect if
      they wish: for Home Assistant, a test `External URL` + long-lived token; for
      Hue, note that pairing needs the physical bridge (hence the video).

### Guideline 5.2.1 (attach what you have — none of these is a signed letter)
- [ ] **Hue — developer-program evidence (do get this; free, ~5 min):** register
      at developers.meethue.com, request local CLIP API access, and attach a
      **screenshot/PDF** of the confirmation, plus the Developer Terms clause
      granting the right "to create a product, app or service that operates with
      the Hue bridge." → Terms: https://developers.meethue.com/terms-of-use-and-conditions/
- [ ] **Home Assistant — open-source license:** link/attach the Apache-2.0 license
      (https://github.com/home-assistant/core/blob/dev/LICENSE.md). Your basis is
      that it's open-source software running on the **user's own** server. *(Optional
      bonus: any reply from partner@openhomefoundation.org.)*
- [ ] **LIFX — published protocol:** link the LAN-protocol docs, which LIFX
      publishes "for third-party developers creating client applications"
      (https://lan.developer.lifx.com/docs/introduction). *(Optional bonus: any
      reply from social@lifx.com.)*
- [ ] **Independent-client proof (screenshots):** the in-app non-affiliation
      disclaimer (Settings → About) and the same disclaimer in the App Store
      description.

### Not required before resubmitting
- Signed permission/authorization **letters** from Signify / OHF / LIFX. Send the
  email drafts (`email-*.md`) if you like, but **don't wait** on replies — the
  items above are sufficient documentary basis. Only chase letters if Apple
  rejects again and explicitly demands them.

### Before you resubmit — metadata hygiene (outside this repo)
- [ ] Re-render the `02-zone` screenshot (text reframed to "Mix any lights into
      one zone") and **re-upload** it — the brand list is still baked into the old
      image.
- [ ] In the App Store **description/keywords**, remove brand-as-marketing
      positioning, drop "LIFX" from keywords, and paste the disclaimer.

---

## 2. Reply message (paste into Resolution Center)

> Hello, and thank you for the review.
>
> Party House is a **free, open-source** app. It has **no accounts, no servers
> operated by us, no analytics, no ads, no purchases, and collects no user data**.
> It is an **independent, third-party** app and does not claim any affiliation with
> the companies named below.
>
> **Guideline 5.2.1.** The app controls only smart lights the **user already
> owns**, on the **user's own** local network, using credentials the **user**
> supplies. It connects through each manufacturer's **publicly published API** and
> bundles **no third-party logos or trademarks**:
>
> • **Philips Hue** — local CLIP v2 API. We are registered in the Philips Hue
>   Developer Program, whose Developer Terms grant the right to "create a product,
>   app or service that operates with the Hue bridge." Confirmation and the terms
>   are attached.
> • **Home Assistant** — open-source software (Apache 2.0) running on the user's
>   own server, accessed via its documented WebSocket API. License reference
>   attached.
> • **LIFX** — the LIFX LAN protocol, which LIFX publishes for third-party client
>   applications (link attached).
>
> The app's name is brand-neutral ("Party House: Smart Lights"), product names are
> used only descriptively to indicate compatibility, and a non-affiliation and
> trademark disclaimer appears both in the app (Settings → About) and in the App
> Store description (screenshots attached). We believe this constitutes the
> necessary authorization and lawful nominative use, and we have removed any
> brand-as-marketing positioning from the metadata. We're glad to provide anything
> further.
>
> **Guideline 2.1.** A demo video recorded on a physical device, showing the
> initial hardware pairing and the full in-app workflow, is linked in the App
> Review Information notes, along with demo connection details.
>
> Thank you for your time — please let us know if anything else would help.
>
> — [Your name]
