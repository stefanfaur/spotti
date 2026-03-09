"""dmgbuild settings for Spotti DMG installer."""

import os

# These are overridden via -D flags from build-dmg.sh
app_path = defines.get("app_path", "build/export/Spotti.app")  # noqa: F821
background_path = defines.get("background_path", "scripts/dmg_bg.png")  # noqa: F821
volume_icon = defines.get("volume_icon", "")  # noqa: F821

# Volume format
format = "UDZO"
size = None  # auto-calculate
filesystem = "HFS+"

# Window settings
background = background_path
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

window_rect = ((200, 120), (540, 540))
icon_size = 80
text_size = 12

# Contents
files = [app_path]
symlinks = {"Applications": "/Applications"}

# Icon positions — centered on the background's placeholder areas
icon_locations = {
    os.path.basename(app_path): (140, 270),
    "Applications": (403, 270),
}

# Volume icon
if volume_icon:
    badge_icon = volume_icon
