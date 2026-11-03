# Skin format

English · [简体中文](SKINS.zh-Hans.md)

This is the reference for Plinth skins: which files a skin may contain, how Plinth reads them, and how it draws and animates them. It describes the behaviour of `SkinPack.load` and `SpriteFish` in [`Sources/Plinth/Sprites.swift`](../Sources/Plinth/Sprites.swift). Where this document and the code disagree, the code is right and this document needs fixing.

## Where skins live

Plinth reads your skins from:

```
~/Library/Application Support/Plinth/Skins/
```

Plinth creates the folder on first launch. **Skin → Open Skins Folder** opens it, and **Skin → Add Skins…** copies images or folders into it. Copying replaces any skin of the same name that is already there.

Each entry in the folder is one skin, either a single image or a folder. Plinth lists them after the twelve built-in skins, sorted by file name. Entries it can't read, such as a folder without `idle.png` or a stray `.DS_Store`, are skipped without a message.

A skin's identity is its file or folder name. Plinth remembers the skin you wear by that name, so renaming a skin you're wearing switches you back to the wooden fish.

## Single-image skins

Any image file macOS can open (PNG, JPEG, HEIC, TIFF, and so on) is a skin on its own. It has an idle frame only: no blink, no hit, the shared mallet and burst, the default strike point, and the wooden knock. Its name in the menus is the file name without the extension.

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
| `name` | string | file name | The skin's name in the menus and in Settings. |
| `strike` | array of two numbers | `[0.6, 0.3]` | Where the centre of the mallet's head lands, as fractions of the frame's width and height, measured from the top-left corner. Keep both within 0 to 1. |
| `voice` | string | `"wood"` | Which knock the skin makes. See [Voices](#voices). |

All keys are optional. Plinth ignores keys it doesn't know. A few rules to watch:

- If the file isn't valid JSON, or a known key has the wrong type (for example `"strike": "0.6, 0.3"`), Plinth ignores the whole file and every key falls back to its default.
- A `strike` that doesn't hold exactly two numbers falls back to `[0.6, 0.3]`; `name` and `voice` still apply.
- An unknown `voice`, including one in the wrong case such as `"Jade"`, plays the wooden knock.

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

Every voice is heard in the same wooden hall. The longer the quiet before a knock, from 0.8 seconds up to 20 seconds, the more of the hall rings with it.

## The mallet

Without `mallet.png`, a skin uses the shared [`App/Resources/mallet.png`](../App/Resources/mallet.png). A skin's own mallet must be laid out the same way, because Plinth positions it by fixed points in the image:

| Property | Value |
| --- | --- |
| Canvas | Square, transparent. The shared mallet is 512 × 512 px. Plinth draws it at 0.6 × the frame's side. |
| Orientation | Horizontal, head on the left, grip at the right edge. |
| Head centre | (0.169, 0.505) of the mallet image. This point lands on `strike`. |
| Grip | (0.964, 0.505) of the mallet image. The mallet rotates around this point. |

At the moment of impact the handle rises 15° above horizontal toward the grip. At rest, the mallet is raised a further 25°. A knock from typing skips the small lift before the swing.

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

If you change a skin you aren't wearing, Plinth picks it up the next time the folder changes or the app starts. If the skin you're wearing disappears, Plinth switches to the wooden fish.

## Built-in skins

The built-in skins live in [`App/Resources/Skins`](../App/Resources/Skins), one folder each, in the same format. Their names come from `skin.json` in English and from [`Skins.strings`](../App/Resources/zh-Hans.lproj/Skins.strings), keyed by folder name, in other languages. The wooden fish is listed first and the rest follow by folder name.

| Folder | Name | 中文名 | Voice | Strike | Hit frame | Mallet | Burst |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `wooden-fish` | Wooden Fish | 木鱼 | `wood` | 0.625, 0.316 | no | shared | shared |
| `bamboo-block` | Bamboo Block | 竹节 | `bamboo` | 0.52, 0.485 | no | own | own |
| `cartoon-fish` | Cartoon Fish | 卡通鱼 | `cartoon` | 0.625, 0.296 | no | own | own |
| `crt-terminal` | CRT Terminal | CRT 终端 | `crt` | 0.52, 0.395 | yes | own | own |
| `ink-fish` | Ink Fish | 水墨鱼 | `ink` | 0.625, 0.289 | no | own | own |
| `jade-fish` | Jade Fish | 玉鱼 | `jade` | 0.625, 0.304 | no | own | own |
| `moss-stone` | Moss Stone | 苔石 | `stone` | 0.52, 0.375 | no | own | own |
| `piston` | Piston | 活塞 | `piston` | 0.52, 0.39 | yes | own | own |
| `pixel-fish` | Pixel Fish | 像素鱼 | `pixel` | 0.625, 0.326 | no | own | own |
| `red-lacquer` | Red Lacquer | 朱漆 | `lacquer` | 0.625, 0.306 | no | own | own |
| `singing-bowl` | Singing Bowl | 铜磬 | `bowl` | 0.625, 0.39 | no | own | own |
| `space-key` | Space Key | 空格键 | `key` | 0.52, 0.515 | yes | own | own |

None of the built-in skins has blink frames. To add a built-in skin, add its folder here and its Chinese name to `Skins.strings`. If its art is new, credit it in [CREDITS.md](../CREDITS.md).

## Checklist

- [ ] `idle.png` exists, is square, and has a transparent background.
- [ ] Every frame is the same size, with the figure's base in the same place.
- [ ] Sequences are numbered from 1 without gaps, and there is no single `blink.png` or `hit.png` beside them.
- [ ] `skin.json` is valid JSON, and `strike` is two numbers between 0 and 1.
- [ ] `voice` is one of the twelve names, in lowercase.
- [ ] A custom `mallet.png` is square, with the head centre at (0.169, 0.505) and the grip at (0.964, 0.505).
- [ ] Knock a few times at each fish size: the mallet head meets the figure, and the burst sits where it lands.
