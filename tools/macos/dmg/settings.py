# dmgbuild settings for the Carina installer disk image.
#
# Run from the repository root:
#   dmgbuild -s tools/macos/dmg/settings.py -D app=path/to/Carina.app \
#     "Carina" dist/Carina.dmg
import os.path

app = defines["app"]  # noqa: F821 (injected by dmgbuild)
app_name = os.path.basename(app)

format = "UDZO"
filesystem = "HFS+"
files = [app]
symlinks = {"Applications": "/Applications"}
icon_locations = {app_name: (170, 180), "Applications": (470, 180)}
background = "tools/macos/dmg/background.png"
window_rect = ((200, 200), (640, 400))
default_view = "icon-view"
icon_size = 128
text_size = 13
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
