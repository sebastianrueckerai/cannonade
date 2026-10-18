#!/usr/bin/env bash
# Fetches the four OFL candidate fonts (static ttf per weight) plus their licences.
set -eu
cd "$(dirname "$0")"
mkdir -p fonts/signika fonts/alegreya fonts/metamorphous fonts/imfell

dl() { # $1 css2 family query, $2 slug, $3 google/fonts dir
  url=$(curl -s "https://fonts.googleapis.com/css2?family=$1" | grep -o 'https://[^)]*\.ttf' | head -1)
  test -n "$url"
  curl -sL "$url" -o "fonts/$2/$2.ttf"
  curl -sL "https://raw.githubusercontent.com/google/fonts/main/ofl/$3/OFL.txt" -o "fonts/$2/OFL.txt" || rm -f "fonts/$2/OFL.txt"
}

dl "Signika:wght@600" signika Signika
dl "Alegreya:wght@500" alegreya Alegreya
dl "Metamorphous" metamorphous Metamorphous
dl "IM+Fell+English" imfell IMFellEnglish
file fonts/*/*.ttf
ls -l fonts/*/ | grep -E 'ttf|OFL' || true
