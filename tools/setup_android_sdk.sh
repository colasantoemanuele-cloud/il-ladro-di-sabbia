#!/bin/bash
# Prepara la toolchain per esportare l'APK su Linux Debian/Ubuntu quando
# dl.google.com non e raggiungibile (ambiente cloud con rete ristretta).
# Usa i pacchetti apt apksigner, zipalign, adb dentro una struttura minima
# che Godot riconosce come Android SDK. Su un PC con accesso alla rete si
# puo invece installare l'SDK ufficiale con sdkmanager (vedi CLAUDE.md).
#
# Uso: bash tools/setup_android_sdk.sh
# Poi: godot --headless --export-debug "Android" build/android/il-ladro-di-sabbia-demo.apk
set -euo pipefail

SDK="${ANDROID_SDK:-$HOME/Android/Sdk}"
KEYSTORE="$HOME/.local/share/godot/keystores/debug.keystore"
SETTINGS="$HOME/.config/godot/editor_settings-4.7.tres"
JAVA_DIR="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"

apt-get install -y apksigner zipalign adb

mkdir -p "$SDK"/{platform-tools,platforms/android-34,cmdline-tools/latest/bin,build-tools/34.0.0}
for par in "platform-tools/adb:adb" "build-tools/34.0.0/apksigner:apksigner" "build-tools/34.0.0/zipalign:zipalign"; do
    printf '#!/bin/sh\nexec %s "$@"\n' "$(command -v "${par##*:}")" > "$SDK/${par%%:*}"
    chmod +x "$SDK/${par%%:*}"
done
printf '#!/bin/sh\nexit 0\n' > "$SDK/cmdline-tools/latest/bin/sdkmanager"
chmod +x "$SDK/cmdline-tools/latest/bin/sdkmanager"
echo "Pkg.Revision=34.0.0" > "$SDK/build-tools/34.0.0/source.properties"

mkdir -p "$(dirname "$KEYSTORE")"
if [ ! -f "$KEYSTORE" ]; then
    keytool -genkey -keystore "$KEYSTORE" -storepass android -alias androiddebugkey \
        -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Debug,O=Debug,C=US"
fi

mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' > "$SETTINGS"
imposta() {
    if grep -q "^$1 = " "$SETTINGS"; then
        sed -i "s|^$1 = .*|$1 = \"$2\"|" "$SETTINGS"
    else
        printf '%s = "%s"\n' "$1" "$2" >> "$SETTINGS"
    fi
}
imposta export/android/java_sdk_path "$JAVA_DIR"
imposta export/android/android_sdk_path "$SDK"
imposta export/android/debug_keystore "$KEYSTORE"
imposta export/android/debug_keystore_user androiddebugkey
imposta export/android/debug_keystore_pass android
echo "Toolchain Android pronta in $SDK"
