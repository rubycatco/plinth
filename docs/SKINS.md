# Skin format

English · [简体中文](SKINS.zh-Hans.md)

This is the reference for Plinth skins: which files a skin may contain, how Plinth reads them, and how it draws and animates them. It describes the behaviour of `Skin.load` in [`Sources/PlinthCore/Skin.swift`](../Sources/PlinthCore/Skin.swift) and `SpriteFish` in [`Sources/PlinthCore/Sprites.swift`](../Sources/PlinthCore/Sprites.swift). Where this document and the code disagree, the code is right and this document needs fixing.

## Where skins live

Plinth reads your skins from:

```
~/Library/Application Support/Plinth/Skins/
```

Plinth creates the folder on first launch. **Settings → Skins → Open Skins Folder** opens it, and **Add Skins…** beside it copies images, folders or `.plinthskin` files into it. Dropping one on the fish, or opening a `.plinthskin` file, does the same. Copying replaces any skin of the same name that is already there.

Each entry in the folder is one skin, either a single image or a folder. Plinth lists them after the twenty-one built-in skins, sorted by file name. Entries it can't read, such as a folder without `idle.png` or a stray `.DS_Store`, are skipped without a message.

A skin's identity is its file or folder name. Plinth remembers the skin you wear by that name, so renaming a skin you're wearing switches you back to the ink fish.

## Sharing a skin: .plinthskin

A `.plinthskin` file is a folder skin in a zip archive, to share as one file. Double-click it, drop it on the fish, or pick it in **Add Skins…**: Plinth unpacks it into the skins folder and wears it.

The archive holds either the skin folder itself, which names the skin, or the skin's files at its top level, in which case the skin is named after the archive. An archive with anything else in it, with no `idle.png`, with a symbolic link, or that would unpack to more than 64 MB is refused.

To make one, right-click a skin of your own in **Settings → Skins** and choose **Export as .plinthskin…**, or run:

```sh
ditto -c -k --keepParent my-skin my-skin.plinthskin
```

Finder's **Compress** works too; rename the `.zip` to `.plinthskin`.

## Single-image skins

Any image file macOS can open (PNG, JPEG, HEIC, TIFF, and so on) is a skin on its own. It has an idle frame only: no blink, no hit, the shared mallet and burst, the default strike point, and the wooden knock. Its name in Settings is the file name without the extension.

## Folder skins

```
my-skin/
├── idle.png       resting frame                                   required
├── blink.png      frame shown when the figure blinks               optional
├── hit.png        frame shown when the mallet lands                optional
├── mallet.png     this skin's mallet                               optional
├── impact.png     this skin's burst where the mallet lands         optional
└── skin.json      name, strike point, and knock                    optional
```

Folder skins read PNG files only, by these exact lowercase names. A folder without `idle.png` isn't a skin.

### Frame sequences

`blink` and `hit` can each be a sequence instead of a single frame: `blink-1.png`, `blink-2.png`, and so on.

- A single `blink.png` takes precedence. If it exists, Plinth ignores `blink-1.png` and the rest. The same holds for `hit`.
- Numbering starts at 1 and must be continuous. Plinth stops at the first missing number, so with `hit-1.png`, `hit-2.png`, and `hit-4.png`, it uses the first two.
- A blink plays from idle toward its last frame (eyes shut) and back to idle. A hit plays toward its last frame, holds there, and settles back to idle.
- Between frames, Plinth cross-fades at the display's frame rate. Two or three frames move smoothly; you don't need more.

### Frames

| Property | Requirement |
| --- | --- |
| Shape | Square. Plinth draws every frame into a square and doesn't preserve the aspect ratio, so a non-square image is stretched. |
| Size | 512 × 512 px is recommended, and is what the built-in skins use. The largest fish is 300 pt, which is 600 px on a Retina display, so use 600 px or more if you want it sharp at that size. |
| Background | Transparent. The menu bar icon is the idle frame cropped to its visible pixels (alpha above 24 of 255); an opaque background makes the icon a solid square. |
| Alignment | All frames of a skin share one canvas. Keep the base of the figure in the same place in every frame, or it jumps when the frames change. |

## skin.json

```json
{ "name": "My Skin", "strike": [0.6, 0.3], "voice": "jade" }
```

| Key | Type | Default | Meaning |
| --- | --- | --- | --- |
| `name` | string | file name | The skin's name in Settings. |
| `strike` | array of two numbers | `[0.6, 0.3]` | Where the centre of the mallet's head lands, as fractions of the frame's width and height, measured from the top-left corner. Keep both within 0 to 1. |
| `voice` | string | `"wood"` | Which knock the skin makes. See [Voices](#voices). |
| `glow` | string | none | The colour of the pedestal's neon, as `#RRGGBB`, for a skin whose base lights up. The incense censer beside the fish catches it on its near side. Leave it out when the base has no light. |
| `raise` | number | `25` | How many degrees above its landing angle the mallet rests. Raise it for a figure struck on its face under a crossbar, so the mallet rests clear of the frame; the built-in hanging skins use `45`. |

All keys are optional. Plinth ignores keys it doesn't know. A few rules to watch:

- If the file isn't valid JSON, or a known key has the wrong type (for example `"strike": "0.6, 0.3"`), Plinth ignores the whole file and every key falls back to its default.
- A `strike` that doesn't hold exactly two numbers falls back to `[0.6, 0.3]`; `name` and `voice` still apply.
- An unknown `voice`, including one in the wrong case such as `"Jade"`, plays the wooden knock.
- A `glow` that isn't `#` and six hex digits is ignored, and the censer stays unlit.
- A `raise` is kept between 0 and 80.

### Voices

Plinth has no sound files. It synthesizes the knock for the voice you name when you put the skin on.

| Voice | Sound |
| --- | --- |
| `wood` | The hollow wooden fish. The default. |
| `lacquer` | The same hollow fish, higher, with a sharper click. |
| `ink` | The wooden knock, low and soft, as if heard through paper. |
| `cartoon` | A small, light fish: round and short, with almost no grit. |
| `pixel` | Stiff harmonic partials and a grainy attack, with no hollow body. |
| `jade` | Solid jade, closer to a stone chime than to a hollow block. |
| `bowl` | A struck bronze bowl: a long hum with a slow beat. |
| `key` | A key bottoming out: a low plastic thud and a short, bright click. |
| `bamboo` | A hollow bamboo tube, more air than wood. |
| `stone` | Dull and gritty, with the ring soaked up. |
| `piston` | Steel on steel: a short clack. |
| `crt` | A plastic case and a faint tick. |
| `bead` | Rosewood beads knocked together: a small, dry clack. |
| `plate` | A flat bronze plate under a leather mallet: a soft, long, slightly clashing ring. |
| `porcelain` | Thin glazed porcelain: high, bright, and clean. |
| `bell` | An almond-shaped bronze bell: two notes a minor third apart, damped sooner than a round bell. |
| `stamp` | A stone seal pressed onto paper: a short, dull thud. |
| `chime` | A thin slab of hanging stone: a long, soft-edged ring. |
| `board` | The long wooden fish that hangs outside the hall: lower and longer than `wood`. |
| `ceramic` | A spoon on the rim of a full mug: a bright ting, damped by the coffee. |
| `temple` | A big old temple fish under a cloth-wrapped mallet: the lowest of the wooden fishes, a long hollow ring, and a soft *dok* where the click was. |

Every knock is synthesized as the mallet falls, louder and brighter the harder it lands, and with more of the shell and less of the hollow the further from the strike point. Each voice is tuned at a medium blow on the strike point. Every knock rings on in the same wooden room, whose size the listener picks under Settings → Knocking → Space, from a small meditation room to a great hall. The longer the quiet before a knock, from 0.8 seconds up to 20 seconds, the more of the hall rings with it.

The hour and season temper the same voice, rather than replacing it. Morning contact is shorter and clearer. Night contact softens, upper shell modes and mallet noise recede, and voices with a hollow body give it a little more weight and sustain; this deepens smoothly at `warmth > 0.7`. The reference voice at `warmth == 0` is unchanged. Hurried typing separately eases force and high frequencies. **Heard, not seen** blends less direct sound with more of the same chosen hall.

Ritual force is independent of the skin: a call uses 0.38, 0.56, then 0.78, with 1.6 and 2.4 seconds between swings. A fifteen-knock **Quickening** round begins at 0.68, 0.66, 0.64, eases from 0.58 to 0.28 through the accelerating roll, then closes at 0.78 after half an extra beat. These are Plinth's adaptations, not prescribed historical measurements. Ordinary knocks retain their responsive, slightly varying touch.

## The mallet

Without `mallet.png`, a skin uses the shared [`App/Resources/mallet.png`](../App/Resources/mallet.png). A skin's own mallet must be laid out the same way, because Plinth positions it by fixed points in the image:

| Property | Value |
| --- | --- |
| Canvas | Square, transparent. The shared mallet is 512 × 512 px. Plinth draws it at 0.6 × the frame's side. |
| Orientation | Horizontal, head on the left, grip at the right edge. |
| Head centre | (0.169, 0.505) of the mallet image. This point lands on `strike`. |
| Grip | (0.964, 0.505) of the mallet image. The mallet rotates around this point. |

At the moment of impact the handle rises 15° above horizontal toward the grip. At rest, the mallet is raised a further 25°, or `raise` degrees when `skin.json` sets it. A knock from typing skips the small lift before the swing.

The mallet rests on the wood for 0.42 seconds, then lifts over 0.85 seconds without bouncing (压槌) on: the 108th auto-knock with **Stop after 108**; a rested knock by hand (more than 90% bloom); the fifteenth **Quickening** knock; the incense's opening knock; and the long-typing bell. Ordinary and typed knocks keep their rebound. A new knock interrupts the hold; a drag before impact still cancels the swing. This uses the same mallet and strike point, with no extra skin files or keys, and remains bounce-free with Reduce Motion.

The third call knock doesn't lift at all: it leaves the mallet lying on the wood. A key or a click that answers the call lifts it over the same 0.85 seconds. If no one answers, it lies there until the next knock of any kind, which lifts it only 60% of the way to rest before it swings. Meanwhile the menu bar icon shows the mallet lying on the figure, placed by the same `strike`, so the figure in it is a little smaller. A skin needs nothing more for any of this.

Lighting incense hushes typed knocks for about 15 seconds and pauses auto-knock until the closing call is over and the spent stick has gone, or until the incense is put out early. A pause preserves auto-knock's enabled setting and its round; cancelled swings do not count as landings. The long-typing bell waits three quiet seconds before its held knock, followed by about 15 quiet seconds. Hand knocks and settings previews remain available.

## The burst

Without `impact.png`, a skin uses the shared neon burst, [`App/Resources/impact.png`](../App/Resources/impact.png). Plinth screen-blends the shared burst, which can only brighten what is under it. It draws a skin's own `impact.png` as is, so a skin's burst can be dark, like the ink fish's splash.

- Canvas: square and transparent. The built-in bursts are 256 × 256 px.
- Position: centred under the mallet's head, at `strike` moved down by 0.078 × the frame's side.
- Size: 0.26 × the frame's side at full strength. Each knock grows from 0.4 to 1.15 times that, and fades out over about a third of a second.
- Strength: after a long quiet the burst opens fully. A rushed knock scales the burst to 45% and its opacity to 50%.

## Animation

Plinth composes all motion from the frames above.

- **Waiting.** The idle frame. If the skin has blink frames, it blinks at a random interval of 3 to 6 seconds, but never within 0.8 seconds of a knock.
- **Knock with hit frames.** The hit sequence plays when the mallet lands. With *n* hit frames it takes 0.03 + 0.02 × *n* seconds to reach the last frame, holds it for 0.14 seconds, and returns to idle over 0.2 + 0.05 × *n* seconds.
- **Knock without hit frames.** The figure gives a little under the mallet: 2% shorter and 0.8% wider, anchored at the bottom, then it springs back.
- **Blink timing.** With *n* blink frames it takes 0.06 × *n* seconds to close, holds for 0.05 seconds, and opens over 0.08 × *n* seconds.

The wooden fishes have no blink or hit frames, on purpose: a fish never closes its eyes (鱼昼夜常醒), not even when struck.

## Editing a skin while Plinth runs

Plinth watches the skins folder. Adding, removing, or renaming a skin shows up within about half a second. Plinth also watches the skin you're wearing, so replacing one of its files updates the fish. Most image editors save by replacing the file. A tool that writes into an existing file in place may go unnoticed in a folder skin until something else changes in the folder.

If you change a skin you aren't wearing, Plinth picks it up the next time the folder changes or the app starts. If the skin you're wearing disappears, Plinth switches to the ink fish.

## Built-in skins

The built-in skins live in [`App/Resources/Skins`](../App/Resources/Skins), one folder each, in the same format. Their names come from `skin.json` in English and from [`Skins.strings`](../App/Resources/zh-Hans.lproj/Skins.strings), keyed by folder name, in other languages. The ink fish, worn by default, is listed first and the rest follow by folder name.

| Folder | Name | 中文名 | Voice | Strike | Hit frame | Mallet | Burst |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `ink-fish` | Ink Fish | 水墨鱼 | `ink` | 0.625, 0.289 | no | own | own |
| `abacus` | Abacus | 算盘 | `bead` | 0.5, 0.325 | yes | own | own |
| `bamboo-block` | Bamboo Block | 竹节 | `bamboo` | 0.52, 0.485 | no | own | own |
| `bianzhong` | Bianzhong | 编钟 | `bell` | 0.56, 0.66 | yes | own | own |
| `cartoon-fish` | Cartoon Fish | 卡通鱼 | `cartoon` | 0.625, 0.296 | no | own | own |
| `cloud-gong` | Cloud Gong | 云板 | `plate` | 0.56, 0.6 | yes | own | own |
| `crt-terminal` | CRT Terminal | CRT 终端 | `crt` | 0.52, 0.395 | yes | own | own |
| `fish-board` | Fish Board | 鱼板 | `board` | 0.56, 0.69 | no | own | shared |
| `jade-fish` | Jade Fish | 玉鱼 | `jade` | 0.625, 0.304 | no | own | own |
| `moss-stone` | Moss Stone | 苔石 | `stone` | 0.52, 0.375 | no | own | own |
| `mug` | Mug | 马克杯 | `ceramic` | 0.56, 0.36 | no | own | own |
| `piston` | Piston | 活塞 | `piston` | 0.52, 0.39 | yes | own | own |
| `pixel-fish` | Pixel Fish | 像素鱼 | `pixel` | 0.625, 0.326 | no | own | own |
| `porcelain-fish` | Porcelain Fish | 青花瓷鱼 | `porcelain` | 0.625, 0.31 | no | own | own |
| `red-lacquer` | Red Lacquer | 朱漆 | `lacquer` | 0.625, 0.306 | no | own | own |
| `seal` | Seal | 印章 | `stamp` | 0.55, 0.39 | no | own | own |
| `singing-bowl` | Singing Bowl | 铜磬 | `bowl` | 0.625, 0.39 | no | own | own |
| `space-key` | Space Key | 空格键 | `key` | 0.52, 0.515 | yes | own | own |
| `stone-chime` | Stone Chime | 石磬 | `chime` | 0.52, 0.65 | yes | own | own |
| `temple-fish` | Temple Fish | 古木鱼 | `temple` | 0.58, 0.298 | no | own | own |
| `wooden-fish` | Wooden Fish | 木鱼 | `wood` | 0.625, 0.316 | no | shared | shared |

None of the built-in skins has blink frames. To add a built-in skin, add its folder here and its Chinese name to `Skins.strings`. If its art is new, credit it in [CREDITS.md](../CREDITS.md).

## Checklist

- [ ] `idle.png` exists, is square, and has a transparent background.
- [ ] Every frame is the same size, with the figure's base in the same place.
- [ ] Sequences are numbered from 1 without gaps, and there is no single `blink.png` or `hit.png` beside them.
- [ ] `skin.json` is valid JSON, and `strike` is two numbers between 0 and 1.
- [ ] `voice` is one of the twenty-one names, in lowercase.
- [ ] A custom `mallet.png` is square, with the head centre at (0.169, 0.505) and the grip at (0.964, 0.505).
- [ ] Knock a few times at each fish size: the mallet head meets the figure, and the burst sits where it lands.
