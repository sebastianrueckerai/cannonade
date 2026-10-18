#!/usr/bin/env python3
# Builds each direction's ui/ drop-in set from the gen-2 textures: resized 9-slice pngs
# (a-panel crops its cream backdrop first), manifest margins, theme.tres variant, the
# direction's font. c is the flat fallback with no textures. Run from the repo root.
import glob
import json
import os
import shutil
from PIL import Image

R = "art/game/art-direction/rounds/30-menu-look"
UI = "assets/art/ui"

CREAM = "Color(0.984, 0.937, 0.851, 1)"   # #fbefd9
INK = "Color(0.227, 0.18, 0.157, 1)"      # #3a2e28
ACCENT = "Color(0.784, 0.196, 0.176, 1)"  # #c8322d

# texture -> (backdrop crop px per side, resized height, slice margins [l,t,r,b])
TEXTURES = {
    "a-button": (0, 96, [12, 10, 12, 10]),
    "b-button": (0, 96, [12, 10, 12, 10]),
    "a-panel": (40, 512, [68, 68, 68, 68]),
    "b-panel": (0, 512, [46, 46, 46, 46]),
}
BUTTON_CONTENT = [16, 6, 16, 6]
PANEL_CONTENT = [26, 12, 26, 12]
FONTS = {"a": "imfell", "b": "alegreya", "c": "signika"}


def box(sid: str, bg: str, outline: bool) -> str:
    border = ("".join(f"border_width_{s} = 2\n" for s in ("left", "top", "right", "bottom"))
              + f"border_color = {INK}\n") if outline else ""
    return (f'[sub_resource type="StyleBoxFlat" id="{sid}"]\n'
            "content_margin_left = 16.0\ncontent_margin_top = 8.0\n"
            "content_margin_right = 16.0\ncontent_margin_bottom = 8.0\n"
            f"bg_color = {bg}\n{border}"
            "corner_radius_top_left = 3\ncorner_radius_top_right = 3\n"
            "corner_radius_bottom_right = 3\ncorner_radius_bottom_left = 3\n\n")


def theme(dir_id: str) -> str:
    # a: cream text on wood. b/c: ink text on parchment. The pngs override the
    # button/panel boxes for a/b; the boxes stay as a same-palette fallback.
    wood = dir_id == "a"
    base = CREAM if wood else INK
    hover = "Color(1, 1, 1, 1)" if wood else ACCENT
    btn = "Color(0.545, 0.353, 0.169, 1)" if wood else "Color(0.91, 0.863, 0.784, 1)"
    btn_hi = "Color(0.651, 0.486, 0.322, 1)" if wood else "Color(0.937, 0.906, 0.847, 1)"
    panel = "Color(0.545, 0.353, 0.169, 0.95)" if wood else "Color(0.984, 0.937, 0.851, 0.97)"
    flat = dir_id == "c"
    return (f'[gd_resource type="Theme" load_steps=5 format=3]\n\n'
            + box("btn_normal", btn, flat) + box("btn_hover", btn_hi, flat)
            + box("btn_pressed", btn, flat) + box("panel", panel, False)
            + "[resource]\ndefault_font_size = 20\n"
            f"Button/colors/font_color = {base}\n"
            f"Button/colors/font_hover_color = {hover}\n"
            f"Button/colors/font_pressed_color = {INK}\n"
            'Button/styles/focus = SubResource("btn_hover")\n'
            'Button/styles/hover = SubResource("btn_hover")\n'
            'Button/styles/normal = SubResource("btn_normal")\n'
            'Button/styles/pressed = SubResource("btn_pressed")\n'
            f"Label/colors/font_color = {base}\n"
            'PanelContainer/styles/panel = SubResource("panel")\n')


def main() -> None:
    os.makedirs(f"{R}/candidates", exist_ok=True)
    shutil.copy(f"{UI}/theme.tres", f"{R}/candidates/original-theme.tres")
    for d, font in FONTS.items():
        out = f"{R}/candidates/{d}/ui"
        os.makedirs(out, exist_ok=True)
        shutil.copy(glob.glob(f"{R}/fonts/{font}/*.ttf")[0], f"{out}/font.ttf")
        manifest = {"ui": {}}
        for role in ("button", "panel"):
            key = f"{d}-{role}"
            if key not in TEXTURES:
                continue
            crop, h, margins = TEXTURES[key]
            im = Image.open(f"{R}/gen2/{key}.png")
            if crop:
                im = im.crop((crop, crop, im.width - crop, im.height - crop))
            im = im.resize((round(im.width * h / im.height), h), Image.LANCZOS)
            im.save(f"{out}/{role}.png")
            manifest["ui"][role] = {
                "margins": margins,
                "content": BUTTON_CONTENT if role == "button" else PANEL_CONTENT,
            }
        with open(f"{out}/manifest.json", "w") as f:
            f.write(json.dumps(manifest, indent=1))
        with open(f"{out}/theme.tres", "w") as f:
            f.write(theme(d))
        print(f"{d}: built")


if __name__ == "__main__":
    main()
