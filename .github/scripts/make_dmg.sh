#!/usr/bin/env bash
# Собирает образ диска .dmg для macOS из архива экспорта Godot.
# Внутри образа приложение и ярлык «Программы», чтобы игру можно было перетащить и установить.
# Запуск только на macOS (нужен hdiutil): make_dmg.sh <архив .zip> <результат .dmg>
set -euo pipefail

zip_path="$1"
dmg_path="$2"
work="$(mktemp -d)"
unzip -q "$zip_path" -d "$work/unpacked"
app="$(find "$work/unpacked" -maxdepth 2 -name '*.app' | head -1)"
if [ -z "$app" ]; then
  echo "::error::В архиве нет .app"
  exit 1
fi
mkdir -p "$work/volume"
ditto "$app" "$work/volume/$(basename "$app")"
ln -s /Applications "$work/volume/Applications"
hdiutil create -volname "MAKE A ERROR" -srcfolder "$work/volume" -ov -format UDZO "$dmg_path"
hdiutil verify "$dmg_path"
ls -la "$dmg_path"
