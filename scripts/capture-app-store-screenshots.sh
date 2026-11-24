#!/usr/bin/env bash
set -euo pipefail

output_dir=$1
scratch=$(mktemp -d)
active_device=
bundle_id=au.h-v.in.level

cleanup() {
    if [[ -n "$active_device" ]]; then
        xcrun simctl shutdown "$active_device" || true
        xcrun simctl delete "$active_device" || true
    fi
    rm -rf -- "$scratch"
}
trap cleanup EXIT

xcrun simctl list runtimes --json > "$scratch/runtimes.json"
xcrun simctl list devicetypes --json > "$scratch/device-types.json"
runtime=$(python3 - "$scratch/runtimes.json" <<'PY'
import json
import sys

with open(sys.argv[1]) as manifest:
    runtimes = [
        item for item in json.load(manifest)["runtimes"]
        if item["isAvailable"] and item["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-")
    ]
if not runtimes:
    sys.exit("No installed iOS Simulator runtime can capture screenshots.")
latest = max(runtimes, key=lambda item: tuple(map(int, item["version"].split("."))))
print(latest["identifier"])
PY
)

device_type() {
    python3 - "$scratch/device-types.json" "$@" <<'PY'
import json
import sys

with open(sys.argv[1]) as manifest:
    devices = {item["name"]: item["identifier"] for item in json.load(manifest)["devicetypes"]}
for name in sys.argv[2:]:
    if name in devices:
        print(devices[name])
        break
else:
    sys.exit("Expected simulator device types unavailable: " + ", ".join(sys.argv[2:]))
PY
}

iphone=$(device_type "iPhone 17 Pro" "iPhone 16 Pro")
ipad=$(device_type "iPad Pro 13-inch (M5)" "iPad Pro 13-inch (M4)")

xcodebuild build -quiet \
    -project InLevel.xcodeproj -scheme InLevel -configuration Debug \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$scratch/build" CODE_SIGNING_ALLOWED=NO

app="$scratch/build/Build/Products/Debug-iphonesimulator/In.Level.app"
test -d "$app"

capture_device() {
    local type=$1 folder=$2 width=$3 height=$4 capture scene screenshot properties pixels
    active_device=$(xcrun simctl create "In.Level $folder" "$type" "$runtime")
    xcrun simctl boot "$active_device"
    xcrun simctl bootstatus "$active_device" -b
    xcrun simctl status_bar "$active_device" override --time '9:41' \
        --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 \
        --batteryState discharging --batteryLevel 100
    xcrun simctl install "$active_device" "$app"

    mkdir -p "$output_dir/$folder"
    for capture in 01-level 02-slope 03-match 04-colours 05-full-screen; do
        scene=${capture#*-}
        SIMCTL_CHILD_INLEVEL_SCREENSHOT_SCENE="$scene" \
            xcrun simctl launch --terminate-running-process "$active_device" "$bundle_id"
        sleep 4
        screenshot="$output_dir/$folder/$capture.jpg"
        xcrun simctl io "$active_device" screenshot --type=jpeg "$screenshot"
        properties=$(sips -g pixelWidth -g pixelHeight -g hasAlpha "$screenshot")
        pixels=$(awk '/pixelWidth:/{w=$2} /pixelHeight:/{print w "x" $2}' <<< "$properties")
        if [[ "$pixels" != "${width}x${height}" ]]; then
            echo "$screenshot is $pixels, expected ${width}x${height}" >&2
            return 1
        fi
        if [[ "$(awk '/hasAlpha:/{print $2}' <<< "$properties")" != no ]]; then
            echo "$screenshot must have no alpha channel" >&2
            return 1
        fi
        echo "$screenshot verified at $pixels with no alpha channel"
    done
    xcrun simctl shutdown "$active_device"
    xcrun simctl delete "$active_device"
    active_device=
}

capture_device "$iphone" iPhone 1206 2622
capture_device "$ipad" iPad 2064 2752
