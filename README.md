# Plinth

English · [简体中文](README.zh-Hans.md) · [plinth.fish](https://plinth.fish)

A small wooden fish that lives on your Mac's desktop. Click it and it goes *tok*, nothing more. Knocking earns no merit (功德).

![Under 「并无功德」 ("No merit at all"), Plinth's twenty-one built-in skins, each on its pedestal with its mallet raised: the wooden fish, a cartoon fish, an ink-wash fish, a jade fish, a pixel-art fish, a red lacquer fish, a singing bowl, a space key, a bamboo block, a moss stone, a piston, a CRT terminal, an abacus, a cloud gong, a blue-and-white porcelain fish, a bianzhong bell, a seal, a stone chime, a fish board, a mug, and an old temple fish](docs/skins.png)

The wooden fish (*muyu*) is a hollow temple block that Buddhist monks strike to keep time while chanting. Baizhang's monastic rules say why it is a fish: 「鱼昼夜常醒，刻木象形击之，所以警昏惰也。」 The fish is awake day and night, so wood is carved in its shape and struck, to rouse the drowsy and the slack. Plinth puts one on a small neon pedestal next to your windows.

Many wooden-fish apps float "功德 +1" ("merit +1") over every knock and keep a running score. Plinth keeps none. When Emperor Wu listed the temples he had built and asked Bodhidharma how much merit he had earned, the answer was 「并无功德」, none at all. Your first knock gets the same answer.

## Contents

- [Features](#features)
- [Install](#install)
- [Uninstall](#uninstall)
- [Usage](#usage)
- [Skins](#skins)
- [Languages](#languages)
- [Building from source](#building-from-source)
- [Project layout](#project-layout)
- [License](#license)

## Features

- **Knock it.** Click the fish and the mallet falls. No two knocks are alike: a firmer press lands harder and brighter, and a knock off the top sounds more of the shell. The longer the silence before a knock, the longer it rings. It sounds from where the fish sits, in a room you choose, from a meditation room to a great hall; on headphones you can hear where. A run of knocks rings on together. On a Force Touch trackpad, you feel the mallet land.
- **Auto-knock.** Every 0.4 to 8 seconds, slow enough to follow a breath: steady, quickening (起板), or natural. It can stop at 108, one turn of a mala. An hour after the screens go to sleep, it rests too, so the Mac can sleep.
- **A stick of incense.** 25, 45, or 60 minutes. One knock to light it, three when it goes out, silence between. No clock, no count.
- **Knock as you type.** Optional. Each key, in any app, knocks once; after a pause, the knock rings longer. Plinth never learns which key.
- **A knock to pause.** Optional. After half an hour of typing with no rest, the fish knocks once: stop, and take three breaths. Nothing is counted.
- **A few words.** The fish has a few things to say, and says each of them once.
- **Out of the way.** No Dock icon. Above your windows or on the desktop, wherever you put it, or not on screen at all: heard, not seen.
- **Updates.** Checks GitHub once a day and asks before installing. You can turn this off.
- **Skins.** Twenty-one, each with its own mallet and knock. The abacus keeps no count, the seal leaves a 空 (empty) where it lands, and the mug splashes without spilling. You can also make your own from a single image or a folder of frames.

What little the fish says is in the original Chinese, as you would hear it in a temple. Menus and settings follow your Mac's language: Simplified Chinese when that is your language, English otherwise.

## Install

Plinth runs on macOS 14 Sonoma or later, on Apple silicon and Intel.

1. Download Plinth from [plinth.fish](https://plinth.fish), or `Plinth-x.y.z.dmg` from [Releases](https://github.com/rubycatco/plinth/releases).
2. Open it and drag Plinth into Applications.
3. If an older Plinth is running, quit it first: right-click the fish and choose **Quit Plinth**.

Releases are signed with a Developer ID and notarized by Apple, so Plinth opens without a Gatekeeper warning. From 1.4.0 on, Plinth updates itself. To build it yourself instead, see [Building from source](#building-from-source).

## Uninstall

「雁无遗踪之意，水无留影之心。」 The geese mean to leave no trace, and the water means to keep no reflection. Plinth keeps your settings, the day's saying, and where the fish sits in its preferences; your own skins in `~/Library/Application Support/Plinth`; and what macOS caches for its update checks. The Mac App Store build keeps all of this in its container instead. Nothing else. If **Launch at login** is on, turn it off in Settings first, then run this in Terminal to remove the app and everything it left:

```sh
osascript -e 'quit app "Plinth"'
defaults delete dev.rubycat.plinth
rm -rf /Applications/Plinth.app \
  ~/Library/Preferences/dev.rubycat.plinth.plist \
  ~/Library/"Application Support"/Plinth \
  ~/Library/Caches/dev.rubycat.plinth \
  ~/Library/HTTPStorages/dev.rubycat.plinth \
  ~/Library/HTTPStorages/dev.rubycat.plinth.binarycookies \
  ~/Library/Containers/dev.rubycat.plinth \
  ~/Library/"Application Scripts"/dev.rubycat.plinth \
  "$(getconf DARWIN_USER_CACHE_DIR)dev.rubycat.plinth"
```

Your own skins go too; copy them out first if you want to keep them.

## Usage

Click the fish to knock, and drag it to move it. Right-click the fish, or click its icon in the menu bar, for the menu. The menu bar icon wears the same skin as the fish.

| Menu item | What it does |
| --- | --- |
| Knock | Knocks once. |
| Auto-Knock | Knocks on its own, at the **Pace** you pick (every 6 seconds, with the breath, or every 2, 1, or 0.5 seconds), in the **Rhythm** you pick: Steady, Quickening, or Natural. |
| Knock as You Type | Knocks once for each key you press, in any app. |
| Light Incense | Lights a stick for 25, 45, or 60 minutes: one knock now, three when it burns out. While it burns, **Put Out the Incense** ends it early, without a knock. |
| Placement | **Above windows** floats the fish over other apps; **On the desktop** keeps it under them. **Heard, not seen** leaves only its knock and the menu bar icon, and the fish keeps its words to itself. |
| Skin | Picks a skin, adds your own, opens the skins folder, or browses the community gallery. |
| Check for Updates… | Asks GitHub for a newer Plinth now. It reads **Update Available…** when one is waiting. |
| Settings… | Opens Settings. |
| Quit Plinth | Quits. |

When Dongshan came to see that the insentient preach the Dharma, he wrote: 「也大奇！也大奇！无情说法不思议，若将耳听终难会，眼处闻声方得知。」 "How marvelous! How marvelous! The insentient preach the Dharma, past all thinking. Listen with the ears and you will never get it; hear the sound with the eyes, and you will know." *Heard, not seen* leaves the fish to the ears alone.

Settings has three tabs:

| Tab | Settings |
| --- | --- |
| Knocking | Volume; space, from a meditation room to a great hall; knock as you type; a knock when it's time to pause; quiet while a microphone is in use; auto-knock at any interval from 0.4 to 8 seconds, in any rhythm, optionally stopping after 108 knocks. Under Display: the fish's size (Small, Medium, or Large: 150, 210, or 300 points), its placement, and whether Plinth opens when you log in. Under Updates: whether to check for updates once a day. |
| Skins | Every skin as a picture to choose from, and buttons to add your own or open the skins folder. |
| Why a Fish | Baizhang's line on why the block is a fish, set as an ink-wash hanging scroll. |

To knock as you type, Plinth asks macOS how long ago a key last went down, the same counter that idle timers use. It never learns which key, so it needs no Accessibility or Input Monitoring permission.

Scripts and other apps can knock too. `open -g plinth://knock` knocks once (`-g` keeps the app you're in at the front). `open -g plinth://call` calls you back, so the fish can tell you when a long build or a test run is done:

```sh
make test; open -g plinth://call
```

A call is three knocks, as when a stick of incense goes out. Auto-knock and typed knocks keep quiet for it, and the three come after a short quiet, so you hear them over whatever the fish was doing. A knock by hand ends a call early.

In the *Gateless Gate*, Master Ruiyan called to himself every day, 「主人公」 ("Master!"), and answered himself, 「诺」 ("Yes?"). Then: "Wide awake! Yes. Some other day, don't let anyone fool you! Yes, yes." The fish only calls; answering is up to you.

A coding agent can call you when it can't go on without you. In Claude Code, add this hook to `~/.claude/settings.json` (into its `hooks`, if it has one already). The fish calls you when Claude stops to ask your permission. It doesn't call at the end of every reply, since you are often there to read it:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "permission_prompt",
        "hooks": [{ "type": "command", "command": "open -g plinth://call" }]
      }
    ]
  }
}
```

In Codex, add this to `~/.codex/hooks.json`, then trust it once under `/hooks`. The fish calls you when Codex asks for approval:

```json
{
  "hooks": {
    "PermissionRequest": [
      { "hooks": [{ "type": "command", "command": "open -g plinth://call" }] }
    ]
  }
}
```

If Plinth isn't running, either URL opens it, and the fish knocks once it is on screen.

In Shortcuts, Plinth adds a **Knock** action. Shortcuts runs it only in a signed release; in a build of your own, use the URL. Like auto-knock, these knocks are never answered.

In a call, only a knock by hand sounds. While another app listens to a microphone, typed knocks, auto-knocks, the incense, and knocks from scripts and Shortcuts still swing the mallet but make no sound. Plinth asks macOS which apps are reading a microphone and never opens one itself, so this needs no microphone permission. It is on by default, and needs macOS 14.2 or later; on earlier versions the setting doesn't appear.

## Skins

A skin is a single image, or a folder with an `idle.png` and, optionally, blink and hit frames, its own mallet and burst, and a `skin.json` for its name, where the mallet lands, and which knock it makes:

```
my-skin/
├── idle.png
├── hit.png
└── skin.json   { "name": "My Skin", "strike": [0.6, 0.3], "voice": "jade" }
```

Put skins in `~/Library/Application Support/Plinth/Skins/`, or use **Skin → Add Skins…**. To share a skin, send it as a `.plinthskin` file, which installs with a double-click or a drop on the fish. More skins, made by other people, are in the [community gallery](https://github.com/rubycatco/plinth-skins) (**Skin → Browse More Skins…**). Plinth picks up changes while it runs.

The [skin format](docs/SKINS.md) has the full specification: every file and key, the twenty-one knock voices, how the mallet and burst are positioned, animation timing, and the built-in skins.

## Languages

The interface strings live in [`App/Resources/zh-Hans.lproj`](App/Resources/zh-Hans.lproj): `Localizable.strings` for the menus and settings, `Skins.strings` for the names of the built-in skins. To add a language, copy that folder to `<language>.lproj`, translate the values, and add the language to `CFBundleLocalizations` in [`App/Info.plist`](App/Info.plist).

## Building from source

You need macOS 14 or later and Xcode 16.3 or later.

```sh
git clone https://github.com/rubycatco/plinth.git
cd plinth
./scripts/build_app.sh
open build/Plinth.app
```

The script builds a universal binary (Apple silicon and Intel), assembles `build/Plinth.app`, and signs it ad hoc. A build of your own doesn't update itself. To keep it, drag `build/Plinth.app` into `/Applications`. `./scripts/make_dmg.sh` packages it as a disk image; [docs/RELEASING.md](docs/RELEASING.md) covers signing, notarization, and releases.

For a quick run during development, `swift run` works too, but outside the app bundle the fish can't find its images. Build with the script to see it as it ships.

## Project layout

```
Sources/Plinth/     SwiftUI + AppKit source; KnockSynth.swift synthesizes the knocks
App/                Info.plist, app icon, disk image background, and bundled resources (skins, mallet, burst, strings)
scripts/            build, disk-image, and update-feed scripts
docs/               skin format, release process, and the README image
.github/workflows/  the release workflow
tools/              skin impact and disk image drawings, the skins picture, the show-off video (Python: NumPy, SciPy, Pillow)
```

## License

Code: [MIT](LICENSE). Art: CC0. The knocks are synthesized by the app. See [CREDITS.md](CREDITS.md).
