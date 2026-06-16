# Party House — Privacy Policy

**Effective: June 11, 2026**

Party House is built to be private by design.

## What we collect

Nothing. Party House has no accounts, no analytics, no advertising, no crash
reporting service, and no servers operated by the developer.

## Where your data lives

- **Connection settings** (bridge addresses, server URLs, zones, palettes) are stored
  on your device and synced between *your own* devices via Apple's iCloud
  Key-Value Storage, under your Apple Account. The developer cannot access them.
- **Secrets** (your Philips Hue application key, your Home Assistant access token)
  are stored in the Apple Keychain and synced via iCloud Keychain, end-to-end
  encrypted. The developer cannot access them.

## Network traffic

Party House talks directly to devices and services **you** configure:

- your Philips Hue Bridge on your local network,
- your Home Assistant server (local URL and, if you configure one, your own remote URL),
- LIFX bulbs on your local network,
- Philips' bridge discovery service (`discovery.meethue.com`) only while you are
  setting up a Hue Bridge and local discovery fails — the service sees only your
  public IP, as any website does.

No light state, usage data, or personal information is ever sent to the developer
or any third party.

## Contact

Questions? Open an issue at https://github.com/yennster/party-house/issues or email
jenny+partyhouse@jennyplunkett.me.

## Trademarks & disclaimer

Party House is an independent, third-party app and is not affiliated with, endorsed
by, or sponsored by Signify (Philips Hue), the Open Home Foundation or Nabu Casa
(Home Assistant), or LIFX / Feit Electric. "Philips Hue," "Home Assistant," "LIFX,"
and all other product and company names are trademarks of their respective owners,
used here only to describe compatibility.
