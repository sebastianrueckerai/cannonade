#!/usr/bin/env bash
# Licence files for the four fonts; the raw host needs a browser UA here.
set -eu
cd "$(dirname "$0")/fonts"
base="https://raw.githubusercontent.com/google/fonts/main/ofl"
curl -sL -A "Mozilla/5.0" "$base/signika/OFL.txt"      -o signika/OFL.txt
curl -sL -A "Mozilla/5.0" "$base/alegreya/OFL.txt"     -o alegreya/OFL.txt
curl -sL -A "Mozilla/5.0" "$base/metamorphous/OFL.txt" -o metamorphous/OFL.txt
curl -sL -A "Mozilla/5.0" "$base/imfellenglish/OFL.txt" -o imfell/OFL.txt
wc -c */OFL.txt
