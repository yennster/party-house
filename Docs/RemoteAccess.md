# Controlling your lights from anywhere

Party House talks to your Philips Hue bridge and LIFX bulbs **directly on your home
network** — those simply aren't reachable from outside. **Home Assistant is the path
to worldwide control**: give your Home Assistant Green a public URL, enter it as the
*External URL* in Party House, and the app automatically fails over to it whenever
the internal URL isn't reachable (exactly like the official Home Assistant app).

Once that's set up, every light Home Assistant can see — including Tuya, Govee, WiZ,
and even your Hue lights via the Hue integration — works from anywhere, widgets
included.

## How Party House picks a URL

1. **Internal URL** (e.g. `http://homeassistant.local:8123`) is tried first.
2. If it doesn't answer within a few seconds, the **External URL** is used.

Set both in **Settings → Home Assistant**.

---

## Option 1 — Home Assistant Cloud / Nabu Casa (easiest, paid)

The official, zero-config option (~$6.50/month, funds Home Assistant development).

1. In Home Assistant: **Settings → Voice assistants & Cloud → Home Assistant Cloud**.
2. Sign up / sign in, then enable **Remote Control**.
3. Copy the remote URL (`https://<random>.ui.nabu.casa`).
4. In Party House: **Settings → Home Assistant → External URL** → paste it.

No router changes, TLS certificate included, works behind CGNAT.

## Option 2 — Cloudflare Tunnel (free, needs a domain)

No open ports; traffic rides Cloudflare's network to your Green.

1. Buy/own a domain and add it to a free Cloudflare account.
2. In Home Assistant, install the **Cloudflared** add-on
   (Settings → Add-ons → Add-on Store → search "Cloudflared").
3. Follow the add-on docs to create a tunnel and route e.g. `ha.yourdomain.com`.
4. Add `ha.yourdomain.com` to `http: trusted_proxies` per the add-on instructions.
5. In Party House, set **External URL** to `https://ha.yourdomain.com`.

## Option 3 — Tailscale (free, most private)

Your Green and your devices join a private WireGuard mesh; nothing is exposed
publicly at all.

1. In Home Assistant, install the **Tailscale** add-on and sign in.
2. Install the Tailscale app on your iPhone and Mac, same account.
3. Find the Green's Tailscale hostname (e.g. `homeassistant.tail1234.ts.net`).
4. In Party House, set **External URL** to `http://homeassistant.tail1234.ts.net:8123`.

Caveat: lights respond only while the Tailscale VPN toggle is on, and widget taps
need the VPN up too. Tailscale's iOS app can keep the tunnel up on demand.

## Which one?

| | Nabu Casa | Cloudflare Tunnel | Tailscale |
|---|---|---|---|
| Cost | ~$6.50/mo | Free (domain ~$10/yr) | Free |
| Setup time | 5 min | 30–45 min | 15 min |
| Open ports | None | None | None |
| Works without client app | ✅ | ✅ | ❌ (VPN must be on) |
| Supports HA project | ✅ | — | — |

If you just want it to work: **Nabu Casa**. If you like tinkering and own a domain:
**Cloudflare Tunnel**. If you want nothing public at all: **Tailscale**.

## A note on tokens

Party House authenticates with a **long-lived access token** (create it in Home
Assistant under your profile → **Security → Long-lived access tokens**). The token is
stored in iCloud Keychain (end-to-end encrypted) and synced to your other devices —
treat it like a password; you can revoke it in the same place at any time.
