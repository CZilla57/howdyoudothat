# How'd You Do That?

You broke a bone. The truth is boring — you tripped on a curb, you slipped in
the kitchen, you "moved a couch." **How'd You Do That?** takes the dull facts
and hands you back a short, spoken-sounding story worth retelling, plus a few
one-liners for the group chat and a designed image card ready to share.

A native iOS (SwiftUI) app with a privacy-first, three-tier story engine.

## Features

- **Eleven vibes** — Absurd, Heroic, Dramatic, Mysterious, Wholesome,
  Conspiracy, Fairytale, Sportscast, Corporate, True Crime, and Western.
- **Spice slider** — from squeaky-clean to cheeky (always kept tasteful).
- **Shareable cards** — every story comes with a designed image card.
- **Personal library** — save the keepers; they live only on your device.
- **Reroll / embellish** — reroll a take, make it wilder, or flip back.
- **Surprise Me** — roll everything at once.

## How stories get written

The app resolves each request through a fallback chain, preferring the most
private option available:

1. **Apple on-device intelligence** — on supported devices, stories are
   written locally: free, fast, offline, and details never leave the phone.
2. **Cloud proxy** ([`worker/`](worker/)) — an optional Cloudflare Worker that
   tries Groq, then Gemini, both constrained to structured JSON. The user
   chooses whether the app may use this fallback.
3. **Offline template engine** — always available; composes a story locally
   when nothing else returns one.

See [`worker/README.md`](worker/README.md) for the proxy request/response
contract and deployment.

## Project layout

| Path | What's there |
|------|--------------|
| [`HowdYouDoThat/`](HowdYouDoThat/) | SwiftUI app — Models, Views, ViewModels, and Engines |
| [`HowdYouDoThat/Engines/`](HowdYouDoThat/Engines/) | Engine fallback chain, resolver, content safety, output validation |
| [`HowdYouDoThatTests/`](HowdYouDoThatTests/) | Unit tests (template engine, proxy engine, resolver, content safety) |
| [`worker/`](worker/) | Cloudflare Worker story proxy (Groq → Gemini) |
| [`store/`](store/) | App Store listing copy, privacy policy, marketing screenshots |
| [`Config/`](Config/) | `Info.plist` and build config |

## Building the app

Requires Xcode and a recent iOS SDK.

```bash
open HowdYouDoThat.xcodeproj
```

Select the **HowdYouDoThat** scheme and run on a simulator or device. Run the
test suite with **⌘U**, or from the command line:

```bash
xcodebuild test -scheme HowdYouDoThat -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Privacy

No account, no ads, no tracking. Saved stories live only on the device. When
cloud fallback is left off, story details never leave the phone. See
[`store/PRIVACY_POLICY.md`](store/PRIVACY_POLICY.md).

---

Now go tell it right. (And break a leg — responsibly.)
