<img src="App/AppIcon.png" width="96" alt="Plinth">

# Plinth

English · [简体中文](README.zh-Hans.md) · [plinth.fish](https://plinth.fish)

A small wooden fish that lives on your Mac's desktop. Click it and it goes *tok*, nothing more. Knocking earns no merit (功德).

![Under 「并无功德」 ("No merit at all"), Plinth's twenty-one built-in skins, each on its pedestal with its mallet raised: an ink-wash fish, the neon wooden fish, a cartoon fish, a jade fish, a pixel-art fish, a red lacquer fish, a singing bowl, a space key, a bamboo block, a moss stone, a piston, a CRT terminal, an abacus, a cloud gong, a blue-and-white porcelain fish, a bianzhong bell, a seal, a stone chime, a fish board, a mug, and an old temple fish](docs/skins.png)

The wooden fish (*muyu*) is a hollow temple block that Buddhist monks strike to keep time while chanting. Baizhang's monastic rules say why it is a fish: 「鱼昼夜常醒，刻木象形击之，所以警昏惰也。」 The fish is awake day and night, so wood is carved in its shape and struck, to rouse the drowsy and the slack. Plinth puts one, brushed in ink, on a small pedestal next to your windows.

Many wooden-fish apps float "功德 +1" ("merit +1") over every knock and keep a running score. Plinth keeps none. When Emperor Wu listed the temples he had built and asked Bodhidharma how much merit he had earned, the answer was 「并无功德」, none at all. Your first knock gets the same answer. Focus timers pin every passing second to the screen and habit apps turn rest into another streak to keep; Plinth keeps no count and shows no clock. It speaks fourteen lines from the Chan records, one a day, ending with Vimalakirti's silence; after that, it only knocks.

Computers used to assume your eyes were fixed on the active window. Now long builds and coding agents work in the background while you read, think, or step away, and another banner or badge only crowds an already crowded screen. For centuries, a Chan hall has coordinated dozens of monks in silence without words or clocks, using only the struck wood and bronze of its instruments (*jianchui*, 犍槌): one knock to enter stillness as the incense is lit, three to leave it when the stick burns out. Plinth works the same way. It stores no recordings, synthesizing every strike as the mallet falls, and asks macOS for no permissions—neither watching which keys you type nor opening a microphone. It simply sits at the corner of your desk, keeping time with your breath, or striking three clear knocks when your work needs you back.

## Install

Plinth runs on macOS 14 Sonoma or later, on Apple silicon and Intel.

1. Download Plinth from [plinth.fish](https://plinth.fish), or `Plinth-x.y.z.dmg` from [Releases](https://github.com/rubycatco/plinth/releases).
2. Open it and drag Plinth into Applications.
3. If an older Plinth is running, quit it first: right-click the fish and choose **Quit Plinth**.

Releases are signed with a Developer ID and notarized by Apple, so Plinth opens without a Gatekeeper warning. Once a day, Plinth asks GitHub whether there is a newer version and asks you before installing it; you can turn this off in Settings. To build it yourself instead, see [Building from source](#building-from-source).

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

## The Fish

Click the fish to knock, and drag it to move it. Right-click the fish, or click its icon in the menu bar, for the menu and **Settings…**. The menu holds only what the fish can be asked to do: knock, knock on its own, light incense. How it knocks, where it sits, and what it wears are in Settings. The menu bar icon wears the same skin as the fish.

- **A living knock.** Each knock is synthesized as the mallet falls. No two are alike: a firmer press lands harder and brighter, a knock off the top sounds more of the shell, and the wood and the hall follow the hour and the season. The 4 a.m. morning board has a shorter, clearer contact; late at night the shell's highs and the attack soften, with a little more of the low hollow body. The longer the silence before a knock, the longer it rings. After a long quiet, a knock by hand rests the mallet on the wood briefly, then lifts it slowly (压槌), leaving the sound to fade. It sounds from where the fish sits across your displays, in a **Space** you choose in Settings, from a meditation room to a great hall; on headphones you can hear where. A run of knocks rings on together. On a Force Touch trackpad, you feel the mallet land.
- **Auto-Knock.** Knocks on its own at the **Pace** you set in Settings, from a knock every 0.4 seconds to one every 8; toward the tortoise, at one knock to each breath out, it keeps time with your own breath. Settings shows no seconds: the fish is knocking as you set it, and the ear sets the pace. It knocks in the **Rhythm** you pick: **Steady**, **Quickening**, or **Natural** (each gap a little long or short, like a hand keeping time). **Quickening** (起板) has fifteen knocks: three slow, firm knocks, then an accelerating, progressively lighter roll; half a beat's pause before the firm fifteenth knock, a held mallet, and a rest before the next round. It can stop after 108 knocks, one turn of a mala: the last three knocks slow down (煞板) and the 108th rings out in full, with the mallet resting on the wood before rising slowly into silence. An hour after the screens go to sleep, auto-knock rests too, so the Mac can sleep.
- **Light Incense.** Choose **Half a stick**, **One stick**, or **Long incense**: about 25, 45, and 60 minutes. These are approximate incense periods, not exact timers, and the menu names no minutes: each stick's burning time varies naturally by up to ±2%, chosen once when lit. A stick stands in an ash bowl beside the fish. Lighting it sounds one full knock with a held mallet (止静); typed knocks keep quiet for three breaths, about 15 seconds. Auto-knock rests throughout the sitting and the three closing knocks (开静), keeping its setting and its place in the round, and resumes once the call is over and the spent stick has gone. No clock, no count. **Put Out the Incense** ends it early without a signal and lets auto-knock resume if it was enabled.
- **Knock as You Type.** Optional, in Settings. Each key you press, in any app, knocks once. As keys hurry together, the knocks gradually grow softer and warmer, with less force and fewer sharp highs; a pause lets them open again and ring longer. Plinth only asks macOS how long ago a key last went down—the same counter that idle timers use—and never learns which key, so it needs no Accessibility or Input Monitoring permission.
- **Knock after long typing.** Optional, in Settings. After half an hour of typing with no three-minute rest, the fish falls quiet for three seconds, knocks once with a held mallet, and lets it ring as the mallet rises slowly. Typed knocks and auto-knock stay quiet for three more breaths, about 15 seconds. Nothing is counted or kept.
- **Mallet key.** Optional, in Settings. Map a key on a one-key keypad, a foot pedal, or a Stream Deck button to the mallet: press it in any app and it knocks by hand, without moving the mouse or needing any permission. An F-key can be the mallet alone; any other key needs two modifiers, one of them ⌘ or ⌃, so everyday shortcuts such as ⌘C and ⌃C keep working.
- **Quiet in calls.** While another app listens to a microphone, typed knocks, auto-knocks, the incense, and knocks from scripts and Shortcuts still swing the mallet but make no sound; only a knock by hand sounds. Plinth asks macOS which apps are reading a microphone and never opens one itself, so this needs no microphone permission. On by default (macOS 14.2 or later).
- **A few words.** On the first knock by hand each day (a temple's day, beginning at 4 a.m.), the fish has a few things to say in the original Chinese, from Bodhidharma's *no merit* to Vimalakirti's silence, and says each of them once, on a slip of rice paper under the fish, in the ink and the Song face of the scroll in Settings. The seventh is from Sengcan's *Xinxin Ming*: 「至道无难，唯嫌拣择。但莫憎爱，洞然明白。」 "The supreme Way is not difficult; it only shuns picking and choosing. Just do not hate or love, and it is wide open and clear." The fourteenth first shows Manjusri's question about entering nonduality; the question and its source then fade, leaving the slip empty for a moment before it too disappears. Silence is not written out. After that, it only knocks. In Settings, **Why a Fish** sets Baizhang's line on why the block is a fish as an ink-wash hanging scroll; click the painted fish there and it knocks too.
- **Placement.** Plinth has no Dock icon. Size and placement are in Settings. The fish comes in three sizes, Small, Medium, or Large (150, 210, or 300 points). Keep it **Above windows**, rest it **On the desktop**, or choose **Heard, not seen**: the fish leaves the screen and its knock blends more into the surrounding hall, with less direct sound from a single point. Your chosen **Space** stays the same. The menu bar icon stays, and it keeps its words until it is seen again.

When Dongshan came to see that the insentient preach the Dharma, he wrote: 「也大奇！也大奇！无情说法不思议，若将耳听终难会，眼处闻声方得知。」 "How marvelous! How marvelous! The insentient preach the Dharma, past all thinking. Listen with the ears and you will never get it; hear the sound with the eyes, and you will know." *Heard, not seen* leaves the fish to the ears alone.

## Calling You Back

Scripts and other apps can knock too. `open -g plinth://knock` knocks once (`-g` keeps the app you're in at the front). `open -g plinth://call` calls you back, so the fish can tell you when a long build or a test run is done:

```sh
make test; open -g plinth://call
```

A call is three knocks, as when a stick of incense goes out: the first gentle, the second even, the third firm, holding the mallet on the wood before lifting it slowly. The last gap opens half a beat longer than the first. Auto-knock and typed knocks keep quiet for it, and the three come after a short quiet, so you hear them over whatever the fish was doing. A knock by hand ends a call early, and so does a key or a click anywhere once its first knock has sounded: you are back. If Plinth isn't running, either URL opens it, and the fish knocks once it is on screen.

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

In Shortcuts, Plinth adds a **Knock** action. Shortcuts runs it only in a signed release; in a build of your own, use the URL. Like auto-knock, these knocks are never answered.

## Skins

Twenty-one skins ship with Plinth, each with its own mallet and synthesized voice. The fish starts in ink, as on its icon; the neon wooden fish and the rest are in **Settings → Skins**. The abacus keeps no count, the seal leaves a 空 (empty) where it lands, and the mug splashes without spilling.

A skin of your own is a single image, or a folder with an `idle.png` and, optionally, blink and hit frames, its own mallet and burst, and a `skin.json` for its name, where the mallet lands, and which knock it makes:

```
my-skin/
├── idle.png
├── hit.png
└── skin.json   { "name": "My Skin", "strike": [0.6, 0.3], "voice": "jade" }
```

Put skins in `~/Library/Application Support/Plinth/Skins/`, or use **Settings → Skins → Add Skins…**. To share a skin, send it as a `.plinthskin` file, which installs with a double-click or a drop on the fish. More skins, made by other people, are in the [community gallery](https://github.com/rubycatco/plinth-skins) (**Settings → Skins → Browse More Skins…**). Plinth picks up changes while it runs.

The [skin format](docs/SKINS.md) has the full specification: every file and key, the twenty-one knock voices, how the mallet and burst are positioned, animation timing, and the built-in skins.

## Building from source

You need macOS 14 or later and Xcode 16.3 or later.

```sh
git clone https://github.com/rubycatco/plinth.git
cd plinth
./scripts/build_app.sh
open build/Plinth.app
```

The script builds a universal binary (Apple silicon and Intel), assembles `build/Plinth.app`, and signs it ad hoc. A build of your own doesn't update itself. To keep it, drag `build/Plinth.app` into `/Applications`. `./scripts/make_dmg.sh` packages it as a disk image; [docs/RELEASING.md](docs/RELEASING.md) covers signing, notarization, and releases. For a quick run during development, `swift run` works too, but outside the app bundle the fish can't find its images.

Menus and settings follow your Mac's language: Simplified Chinese when that is your language, English otherwise. The interface strings live in [`App/Resources/zh-Hans.lproj`](App/Resources/zh-Hans.lproj) (`Localizable.strings` for menus and settings, `Skins.strings` for built-in skin names); to add a language, copy that folder to `<language>.lproj`, translate the values, and add the language to `CFBundleLocalizations` in [`App/Info.plist`](App/Info.plist).

```
Sources/Plinth/     the Mac app: SwiftUI + AppKit source
Sources/PlinthCore/ what doesn't need a Mac: KnockSynth.swift synthesizes the knocks, KnockSound.swift plays them, Sprites.swift draws the fish in its skin
App/                Info.plist, app icon, disk image background, and bundled resources (skins, mallet, burst, strings)
iOS/                the iPhone app, just begun: open iOS/Plinth.xcodeproj in Xcode 27.1 or later and run the Plinth iOS scheme
scripts/            build, disk-image, and update-feed scripts
docs/               skin format, release process, and the README image
.github/workflows/  the release workflow
tools/              app icon, skin impact, and disk image drawings, the skins picture, the show-off video (Python: NumPy, SciPy, Pillow)
```

## License

Code: [MIT](LICENSE). Art: CC0. The knocks are synthesized by the app. See [CREDITS.md](CREDITS.md).
