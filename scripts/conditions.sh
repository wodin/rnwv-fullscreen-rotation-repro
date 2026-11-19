#!/usr/bin/env bash
#
# Runs the repro on the one connected device under each rotation condition
# and writes one file per run to output/conditions/.
#
#   flow            the Maestro flow as it is. Its setOrientation turns
#                   auto-rotate off and sets user_rotation.
#   sensor-auto-on  auto-rotate on, device physically turned
#   sensor-auto-off auto-rotate off, device physically turned
#
# An emulator is turned through its accelerometer. A phone has to be turned
# by hand when the video goes fullscreen.
#
# Usage: [VARIANTS=locked] scripts/conditions.sh [condition...]
# Defaults: both variants, all three conditions.

set -uo pipefail
cd "$(dirname "$0")/.."

APP_ID=io.github.wodin.rnwvrotation
OUT=output/conditions
TMP=$(mktemp -d)
trap 'rm -r "$TMP"' EXIT

sdk=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
# Empty on a phone.
avd=$(adb emu avd name 2>/dev/null | head -1 | tr -d '\r')
model=$(adb shell getprop ro.product.model | tr -d '\r')
webview=$(adb shell dumpsys webviewupdate | sed -n 's/.*Current WebView package[^,]*, version): (\(.*\))/\1/p' | tr -d '\r')

setting() { adb shell settings get system "$1" | tr -d '\r'; }
rotation() { adb shell dumpsys display | grep -o -m1 'mCurrentOrientation=[0-9]' | cut -d= -f2; }
landscape() { [ "$(rotation)" = 1 ] || [ "$(rotation)" = 3 ]; }

# Turns an emulator through its accelerometer. A phone has to be turned by
# hand, so this watches for a while instead. Prints whether the display
# followed. A locked app goes back to portrait as soon as the WebView is
# destroyed, so landscape can be brief and the watch must not sleep.
turn() {
  local seconds=6
  if [ -n "$avd" ]; then
    case $1 in
      landscape) adb emu sensor set acceleration 9.81:0:0 ;;
      portrait) adb emu sensor set acceleration 0:9.81:0 ;;
    esac >/dev/null
  else
    seconds=25
  fi
  # On a phone a miss proves nothing: the turn may have been too brief.
  local followed=no
  [ -z "$avd" ] && followed='not seen'
  SECONDS=0
  while [ $SECONDS -lt $seconds ]; do
    if { [ "$1" = landscape ] && landscape; } || { [ "$1" = portrait ] && ! landscape; }; then
      followed=yes
      break
    fi
  done
  sleep 3
  echo "$followed"
}

# Two screenshots a second apart differ only while the video is playing. The
# top strip is cut off so the status bar clock cannot count as a change.
advancing() {
  adb exec-out screencap -p >"$TMP/a.png"
  sleep 1
  adb exec-out screencap -p >"$TMP/b.png"
  local changed
  changed=$(compare -metric AE "$TMP/a.png[0x0+0+200]" "$TMP/b.png[0x0+0+200]" null: 2>&1)
  [ "${changed%%[ .e]*}" -gt 500 ] && echo yes || echo no
}

visible() {
  adb shell uiautomator dump /sdcard/window.xml >/dev/null 2>&1 &&
    adb shell cat /sdcard/window.xml | grep -q "text=\"$1\"" && echo yes || echo no
}

reset() {
  adb shell am force-stop "$1"
  adb shell settings put system user_rotation 0
  adb shell settings put system accelerometer_rotation "$2"
  turn portrait >/dev/null
}

observe_after() {
  echo "after exit: display rotation $(rotation), video row on screen: $(visible 'Enter fullscreen'), frames advancing: $(advancing)"
  echo "auto-rotate after: $(setting accelerometer_rotation), user_rotation after: $(setting user_rotation)"
}

run() {
  local variant=$1 condition=$2 app=$APP_ID want='mounts: 1, unmounts: 0, layouts: .*' require_exit=false
  if [ "$variant" = unlocked ]; then
    app=$APP_ID.unlocked
    want='mounts: 1, unmounts: \d+, layouts: .*'
    require_exit=true
  fi
  local file=$OUT/api$sdk-$variant-$condition.txt
  echo "== $file"
  {
    echo "device: ${avd:-$model} (API $sdk, WebView $webview)"
    echo "variant: $variant, condition: $condition"
    case $condition in
      flow)
        reset "$app" 1
        echo "auto-rotate before: $(setting accelerometer_rotation)"
        echo
        maestro test ".maestro/$variant.yaml"
        echo
        observe_after
        ;;
      sensor-auto-on | sensor-auto-off)
        local auto=1
        [ "$condition" = sensor-auto-off ] && auto=0
        reset "$app" "$auto"
        echo "auto-rotate before: $(setting accelerometer_rotation)"
        echo
        maestro test -e APP_ID="$app" .maestro/sensor/enter.yaml
        echo
        # Not on a phone: the measurement would overlap the turn by hand.
        [ -n "$avd" ] && echo "in fullscreen, before turning: display rotation $(rotation), frames advancing: $(advancing)"
        echo "turned to landscape, display followed: $(turn landscape)"
        echo "in fullscreen, after turning: display rotation $(rotation), frames advancing: $(advancing)"
        echo
        maestro test -e APP_ID="$app" -e WANT="$want" -e REQUIRE_EXIT="$require_exit" .maestro/sensor/exit.yaml
        echo
        # The unlocked app stays in landscape, so look before turning back.
        observe_after
        ;;
    esac
  } >"$file" 2>&1
  grep -E 'Expected|check.js|^turned|^in fullscreen|^after exit|^auto-rotate after' "$file"
}

conditions=("$@")
[ ${#conditions[@]} -eq 0 ] && conditions=(flow sensor-auto-on sensor-auto-off)

for condition in "${conditions[@]}"; do
  for variant in ${VARIANTS:-locked unlocked}; do
    run "$variant" "$condition"
  done
done

reset "$APP_ID" 1
