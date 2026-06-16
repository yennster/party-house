import Foundation

/// Trademark / non-affiliation text shown in-app (Settings → About) and intended
/// to be mirrored verbatim in the App Store description and App Review notes.
///
/// Party House is an independent client that talks to the user's *own* hardware
/// over each vendor's publicly published API. It ships no third-party logos and
/// uses brand names only descriptively (nominative fair use). This disclaimer is
/// the standard non-affiliation notice third-party smart-home apps carry to
/// satisfy App Store Guideline 5.2.1.
public enum PartyLegal {
    public static let disclaimer = """
    Party House is an independent, third-party app. It is not affiliated with, \
    endorsed by, or sponsored by Signify (Philips Hue), the Open Home Foundation \
    or Nabu Casa (Home Assistant), or LIFX / Feit Electric. “Philips Hue,” \
    “Home Assistant,” “LIFX,” and all other product and company names are \
    trademarks of their respective owners, used here only to describe compatibility.
    """
}
