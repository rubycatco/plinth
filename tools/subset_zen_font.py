"""Cut the iPhone app's Song face down to the characters the fish says.

On a half-open iPhone Duo the fish writes its line for the day down the spare
page, as the Mac's Settings > Why a Fish writes its scroll in Songti SC. iOS
has no Song face of its own, so the app carries one: Noto Serif SC Regular,
from https://github.com/notofonts/noto-cjk (Serif/SubsetOTF/SC), under the
SIL Open Font License 1.1, cut down to every character in the strings of
Sources/PlinthCore/Zen.swift and the upright brackets that stand in a column
for 《》. That cuts it from 11 MB to some 65 KB. The cut keeps the font's
names, copyright and license, and the license is also in OFL.txt beside it.
Run it again when the sayings change.
Needs fonttools.

Usage: python subset_zen_font.py <NotoSerifSC-Regular.otf>
       (writes iOS/Plinth/Fonts/NotoSerifSC-Zen.otf)
"""
import re
import sys
from pathlib import Path

from fontTools import subset

ROOT = Path(__file__).resolve().parents[1]
ZEN = ROOT / "Sources/PlinthCore/Zen.swift"
OUT = ROOT / "iOS/Plinth/Fonts/NotoSerifSC-Zen.otf"


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    strings = "".join(re.findall(r'"((?:[^"\\]|\\.)*)"', ZEN.read_text(encoding="utf-8")))
    text = "".join(sorted({c for c in strings if ord(c) > 127} | set("︽︾")))
    options = subset.Options()
    options.name_IDs = ["*"]
    options.name_languages = ["*"]
    font = subset.load_font(sys.argv[1], options)
    missing = [c for c in text if ord(c) not in font.getBestCmap()]
    if missing:
        sys.exit("Not in the font: " + "".join(missing))
    subsetter = subset.Subsetter(options)
    subsetter.populate(text=text)
    subsetter.subset(font)
    subset.save_font(font, str(OUT), options)
    print(f"{OUT.relative_to(ROOT)}: {len(text)} characters, {OUT.stat().st_size} bytes")


if __name__ == "__main__":
    main()
