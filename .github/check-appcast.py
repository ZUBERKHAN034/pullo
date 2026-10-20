import sys
import xml.etree.ElementTree as ET

SPARKLE = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"

path, build, channel = sys.argv[1], sys.argv[2], sys.argv[3]
items = ET.parse(path).getroot().iter("item")
item = next((i for i in items if i.findtext(f"{SPARKLE}version") == build), None)
if item is None:
    sys.exit(f"::error::The feed has no item for build {build}")
found = item.findtext(f"{SPARKLE}channel") or ""
if found != channel:
    sys.exit(f"::error::Build {build} is on channel '{found or 'stable'}', expected '{channel or 'stable'}'")
print(f"Build {build} is on the {channel or 'stable'} channel")
