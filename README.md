# Livepal

**Livepal** is a **Mac-first**, **free-for-users** live-caption overlay for calls. It captures **incoming (system) audio** from a window you pick (Zoom, Meet, a browser tab, etc.), runs **on-device** speech recognition, and shows **two caption sections** — one for each language you configure (for example **English** on top and **Spanish** below). This build supports **10** spoken languages; you choose **two** for the two sections.

There is **no translation step** and **no paid cloud API** in the default design: captions are **only** what was said, routed into the correct section using Apple’s **Natural Language** framework together with **two** Speech-framework recognizers.

## How the two sections work

1. **Two recognizers** (`SFSpeechRecognizer`), each tuned to one of your chosen locales, both receive the **same** audio.
2. For each update, **`NLLanguageRecognizer`** scores how strongly the text looks like language A vs language B.
3. The UI shows **live text in the matching section** — still in the **original spoken language**, not translated.

**Turn-taking (expected use):** the logic assumes **one remote speaker at a time** (English, then Spanish, etc.), not everyone talking over each other. Only **one** section gets a **live partial** at once; the other section keeps the last **final** caption until that language speaks again.

**Limits:** this is **not** true speaker diarization. Short phrases, code-switching, noise, or similar languages can confuse routing. Pick the **two** locales that match your bilingual call.

On-device recognition is preferred when supported (`requiresOnDeviceRecognition`); if a locale does not support on-device recognition on your Mac, Speech may fall back per Apple’s rules.

## Requirements

- macOS 14+
- **Screen Recording** permission (ScreenCaptureKit)
- **Speech Recognition** permission

## Build & run

```bash
cd macos
swift build
./scripts/package_app.sh
open Livepal.app
```

The packaged `Livepal.app` includes `Info.plist` usage descriptions so macOS can show the privacy prompts.

## Landing page (Vercel)

Static site lives in `landing/`. Edit `landing/index.html`: set **Download for macOS** `href` to your DMG/ZIP (for example a GitHub Release asset), and fix the GitHub link.

Deploy on Vercel:

1. Push this repo to GitHub.
2. **New Project** → import the repo → set **Root Directory** to `landing`.
3. Framework preset **Other** (no build command). Output is static `index.html`.

Optional: pass a download URL without editing HTML: `https://your-site.vercel.app/?dl=https%3A%2F%2Fexample.com%2FLivepal.zip`

### macOS download (GitHub Releases)

The landing page button points at:

`https://github.com/voicelinelsweb/Livepal/releases/latest/download/Livepal-macos.zip`

Publishing a new zip is done by pushing a version tag (see `.github/workflows/release-macos.yml`):

```bash
git tag v0.1.2
git push origin v0.1.2
```

Prebuilt zips from GitHub Actions are **Apple Silicon (arm64)**. On Intel Macs, build locally with `swift build -c release` and `./scripts/package_app.sh`.

Manual run (artifact only, no Release): **Actions → Release macOS app → Run workflow**.

This repo’s Vercel deploy for `landing/` may be: `https://landing-r516lrvd5-voicelinelswebs-projects.vercel.app` — add a custom domain in the Vercel dashboard if you prefer.

## GitHub from the CLI

```bash
git init
git add -A
git commit -m "Initial commit"
gh auth login
gh repo create Livepal --public --source=. --remote=origin --push
```

If you do not use GitHub CLI, create an empty repo in the browser, then:

```bash
git remote add origin https://github.com/YOUR_USER/Livepal.git
git branch -M main
git push -u origin main
```

## Repository layout

- `macos/` — SwiftPM app (SwiftUI + ScreenCaptureKit + Speech + NaturalLanguage)

## License

ISC (see `package.json`).
