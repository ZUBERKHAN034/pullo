# dmgbuild settings for the DevNotch disk image: the app next to an Applications shortcut, ready to drag.
import os.path

application = defines["app"]
appname = os.path.basename(application)

format = "UDZO"
files = [application]
symlinks = {"Applications": "/Applications"}
hide_extensions = [appname]

window_rect = ((200, 120), (540, 360))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
icon_size = 128
text_size = 13
icon_locations = {appname: (140, 170), "Applications": (400, 170)}
