#!/usr/bin/env bash
# Exports a sideloadable Android APK (arm64) with Godot's prebuilt export template. Linux only.
#
#   tools/build_android.sh [output.apk]      default: build/iron-temple.apk
#
# Needs on PATH: godot 4.4+ (or set GODOT), a JDK 17+ (java, keytool), curl and unzip.
# The Android SDK tools, the export template and a signing key are fetched or created on first
# use and kept in ANDROID_TOOLCHAIN_DIR, outside the repository. Reusing that directory keeps
# the signing key, so later builds install over earlier ones.
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUTPUT="${1:-build/iron-temple.apk}"
TOOLCHAIN="${ANDROID_TOOLCHAIN_DIR:-$HOME/.cache/iron-temple-android}"
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
BUILD_TOOLS="35.0.0"

export ANDROID_HOME="${ANDROID_HOME:-$TOOLCHAIN/sdk}"
export JAVA_HOME="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}"
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-$TOOLCHAIN/sideload.keystore}"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="${GODOT_ANDROID_KEYSTORE_RELEASE_USER:-sideload}"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:-android}"

mkdir -p "$TOOLCHAIN" "$(dirname "$OUTPUT")"

# Android SDK: a prebuilt-template export only needs adb and apksigner.
if [ ! -x "$ANDROID_HOME/build-tools/$BUILD_TOOLS/apksigner" ] || [ ! -x "$ANDROID_HOME/platform-tools/adb" ]; then
	echo "Installing Android SDK tools into $ANDROID_HOME"
	curl -fsSL "$CMDLINE_TOOLS_URL" -o "$TOOLCHAIN/cmdline-tools.zip"
	rm -rf "$TOOLCHAIN/cmdline-tools"
	unzip -q "$TOOLCHAIN/cmdline-tools.zip" -d "$TOOLCHAIN"
	rm "$TOOLCHAIN/cmdline-tools.zip"
	sdkmanager="$TOOLCHAIN/cmdline-tools/bin/sdkmanager"
	yes | "$sdkmanager" --sdk_root="$ANDROID_HOME" --licenses >/dev/null || true
	"$sdkmanager" --sdk_root="$ANDROID_HOME" "platform-tools" "build-tools;$BUILD_TOOLS" >/dev/null
fi

# Export template matching the installed Godot, e.g. version "4.4.1.stable" is tag "4.4.1-stable".
version="$("$GODOT" --version | sed -E 's/\.(official|custom_build).*//')"
templates="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$version"
if [ ! -f "$templates/android_release.apk" ]; then
	tag="${version%.*}-${version##*.}"
	echo "Downloading Godot $tag export templates"
	mkdir -p "$templates"
	curl -fsSL "https://github.com/godotengine/godot/releases/download/$tag/Godot_v${tag}_export_templates.tpz" -o "$TOOLCHAIN/templates.tpz"
	unzip -q -j -o "$TOOLCHAIN/templates.tpz" templates/android_release.apk templates/android_debug.apk templates/version.txt -d "$templates"
	rm "$TOOLCHAIN/templates.tpz"
fi

if [ ! -f "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" ]; then
	echo "Creating signing key $GODOT_ANDROID_KEYSTORE_RELEASE_PATH"
	keytool -genkeypair -keystore "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" -alias "$GODOT_ANDROID_KEYSTORE_RELEASE_USER" \
		-storepass "$GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD" -keypass "$GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD" \
		-keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Iron Temple Sideload" >/dev/null
fi

rm -f "$OUTPUT"
"$GODOT" --headless --path . --export-release "Android" "$OUTPUT"
"$ANDROID_HOME/build-tools/$BUILD_TOOLS/apksigner" verify "$OUTPUT"
ls -lh "$OUTPUT"
