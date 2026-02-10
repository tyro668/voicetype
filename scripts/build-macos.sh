#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

flutter build macos --release

app_path="$(find "$repo_root/build/macos/Build/Products/Release" -maxdepth 1 -name "*.app" -print -quit)"
if [[ -z "${app_path}" ]]; then
  echo "No .app found in build output." >&2
  exit 1
fi

app_name="$(basename "$app_path" .app)"
version="$(grep -E '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1)"
if [[ -z "${version}" ]]; then
  version="0.0.0"
fi

out_dir="$repo_root/dmg"
mkdir -p "$out_dir"

dmg_path="$out_dir/${app_name}-${version}.dmg"
rm -f "$dmg_path"

hdiutil create -volname "$app_name" -srcfolder "$app_path" -ov -format UDZO "$dmg_path"

echo "DMG created: $dmg_path"
