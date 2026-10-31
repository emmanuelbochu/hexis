"""Turns generated exercise pictures into image sets.

Put the pictures in one folder, named after the exercise as in Program.json ("Presse à cuisses.png"),
then from the repo root:  python3 Tools/exo_import.py <folder>
Each picture is cropped to a square, resized to 512 px and written to Hexis/Assets.xcassets/exo-<slug>.imageset
(same slug as ExerciseImage.assetName), replacing the drawn one.
"""
import json, os, sys, unicodedata
from PIL import Image

SIZE = 512


def slug(name):
    folded = "".join(c for c in unicodedata.normalize("NFD", name) if unicodedata.category(c) != "Mn").lower()
    words, word = [], ""
    for c in folded:
        if c.isalnum():
            word += c
        elif word:
            words.append(word)
            word = ""
    if word:
        words.append(word)
    return "exo-" + "-".join(words)


def main():
    if len(sys.argv) < 2 or not os.path.isdir(sys.argv[1]):
        sys.exit(__doc__)
    for file in sorted(os.listdir(sys.argv[1])):
        stem, ext = os.path.splitext(file)
        if ext.lower() not in (".png", ".jpg", ".jpeg", ".webp"):
            continue
        img = Image.open(os.path.join(sys.argv[1], file)).convert("RGB")
        side = min(img.size)
        left, top = (img.width - side) // 2, (img.height - side) // 2
        img = img.crop((left, top, left + side, top + side)).resize((SIZE, SIZE), Image.LANCZOS)
        name = slug(stem)
        folder = f"Hexis/Assets.xcassets/{name}.imageset"
        os.makedirs(folder, exist_ok=True)
        img.save(f"{folder}/{name}.png", optimize=True)
        with open(f"{folder}/Contents.json", "w") as f:
            json.dump({"images": [{"filename": f"{name}.png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}, f, indent=2)
        print("ok", name)


main()
