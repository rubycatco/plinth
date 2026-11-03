# Plinth

English · [简体中文](README.zh-Hans.md)

A tiny wooden fish that lives on your Mac's desktop. Click it to knock and hear a soft *tok*. That's all. You earn no merit (功德) for it.

![Plinth's twelve built-in skins, each on its pedestal with its mallet raised: the wooden fish, a cartoon fish, an ink-wash fish, a jade fish, a pixel-art fish, a red lacquer fish, a singing bowl, a space key, a bamboo block, a moss stone, a piston, and a CRT terminal](docs/skins.png)

The wooden fish (*muyu*) is a hollow temple block that Buddhist monks strike to keep time while chanting. Old monastic rules say it is shaped like a fish because a fish never closes its eyes, so its knock keeps the drowsy awake. Plinth puts one on a small neon pedestal next to your windows.

Many wooden-fish apps float "功德 +1" ("merit +1") over every knock and keep a running score. Plinth doesn't. When Emperor Wu listed the temples he had built and asked Bodhidharma how much merit he had earned, the answer was 「并无功德」: none at all. Your first knock gets the same answer, and no score is ever kept.

## Contents

- [Features](#features)
- [Install](#install)
- [Usage](#usage)
- [Skins](#skins)
- [Languages](#languages)
- [Building from source](#building-from-source)
- [Project layout](#project-layout)
- [License](#license)

## Features

- **Knock it.** Click the fish. A mallet swings, the wood gives a little, and it sounds. The longer the quiet before a knock, the more it rings.
- **Auto-knock.** Let it keep a steady rhythm (every 0.4 to 4 seconds), with an option to stop after 108 knocks, one full turn of a mala.
- **Knock as you type.** Optional: each key you press, in any app, knocks once. Pause to think, and the next key rings. It needs no special permission: Plinth only notices *when* a key goes down, never which key.
- **A few words.** The fish has a few things to say, and says each of them once.
- **Stays out of the way.** No Dock icon. Float it above your windows or sink it onto the desktop. Drag it anywhere.
- **Skins.** Twelve ship with the app, each with its own mallet and knock, and most with their own burst: the wooden fish, a jade fish, a red lacquer fish, a singing bowl, a pixel-art fish, a cartoon fish, an ink-wash fish, a space key, a bamboo block, a moss stone, a piston, and a CRT terminal. The space key presses down and springs back; it doesn't type anything. The piston compresses and rebounds; the CRT briefly flashes a waveform, without running commands. Or swap in anything: a folder of sprite frames, or a single image.

What little the fish says is in the original Chinese, as you would hear it in a temple. Menus and settings follow your Mac's language: Simplified Chinese when that is your language, English otherwise.

## Install

Plinth runs on macOS 14 Sonoma or later, on Apple silicon and Intel.

1. Download `Plinth-x.y.z.dmg` from [Releases](https://github.com/rubycatco/plinth/releases).
2. Open it and drag Plinth into Applications.
3. If an older Plinth is running, quit it first: right-click the fish and choose **Quit Plinth**.

Releases are signed with a Developer ID and notarized by Apple, so Plinth opens without a Gatekeeper warning. To build it yourself instead, see [Building from source](#building-from-source).

## Usage

Click the fish to knock, and drag it to move it. Right-click the fish, or click its icon in the menu bar, for the menu. The menu bar icon wears the same skin as the fish.

| Menu item | What it does |
| --- | --- |
| Knock | Knocks once. |
| Auto-Knock | Knocks on its own, at the **Pace** you pick: every 2, 1, or 0.5 seconds. |
| Knock as You Type | Knocks once for each key you press, in any app. |
| Placement | **Above windows** floats the fish over other apps; **On the desktop** keeps it under them. |
| Skin | Picks a skin, adds your own, or opens the skins folder. |
| Settings… | Opens Settings. |
| Quit Plinth | Quits. |

Settings has three tabs:

| Tab | Settings |
| --- | --- |
| Knocking | Volume; knock as you type; auto-knock at any interval from 0.4 to 4 seconds, optionally stopping after 108 knocks. Under Display: the fish's size (Small, Medium, or Large: 150, 210, or 300 points), its placement, and whether Plinth opens when you log in. |
| Skins | Every skin as a picture to choose from, and buttons to add your own or open the skins folder. |
| Why a Fish | The line from the old monastic rules on why the block is a fish. |

To knock as you type, Plinth asks macOS how long ago a key last went down, the same counter that idle timers use. It never learns which key, so it needs no Accessibility or Input Monitoring permission.

## Skins

A skin is a single image, or a folder with an `idle.png` and, optionally, blink and hit frames, its own mallet and burst, and a `skin.json` for its name, where the mallet lands, and which knock it makes:

```
my-skin/
├── idle.png
├── hit.png
└── skin.json   { "name": "My Skin", "strike": [0.6, 0.3], "voice": "jade" }
```

Put skins in `~/Library/Application Support/Plinth/Skins/`, or use **Skin → Add Skins…**. Plinth picks up changes while it runs.

The [skin format](docs/SKINS.md) has the full specification: every file and key, the twelve knock voices, how the mallet and burst are positioned, animation timing, and the built-in skins.

## Languages

The interface strings live in [`App/Resources/zh-Hans.lproj`](App/Resources/zh-Hans.lproj): `Localizable.strings` for the menus and settings, `Skins.strings` for the names of the built-in skins. To add a language, copy that folder to `<language>.lproj`, translate the values, and add the language to `CFBundleLocalizations` in [`App/Info.plist`](App/Info.plist).

## Building from source

You need macOS 14 or later and Xcode 15 or later.

```sh
git clone https://github.com/rubycatco/plinth.git
cd plinth
./scripts/build_app.sh
open build/Plinth.app
```

The script builds a universal binary (Apple silicon and Intel), assembles `build/Plinth.app`, and signs it ad hoc. To keep it, drag `build/Plinth.app` into `/Applications`. `./scripts/make_dmg.sh` packages it as a disk image; [docs/RELEASING.md](docs/RELEASING.md) covers signing, notarization, and releases.

For a quick run during development, `swift run` works too, but the fish won't find its images outside the app bundle, so use the script to see the real thing.

## Project layout

```
Sources/Plinth/     SwiftUI + AppKit source; KnockSynth.swift synthesizes the knocks
App/                Info.plist, app icon, and bundled resources (skins, mallet, burst, strings)
scripts/            build and disk-image scripts
docs/               skin format, release process, and the README image
.github/workflows/  the release workflow
tools/              skin impact drawings (Python: NumPy, Pillow)
```

## License

Code: [MIT](LICENSE). Art: CC0. The knocks are synthesized by the app. See [CREDITS.md](CREDITS.md).
