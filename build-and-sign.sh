#!/bin/bash
#
# Build and sign Dumb Browser for ARM64
#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
OUT_DIR="$SRC_DIR/out/ArmChrome"
KEYSTORE="$SCRIPT_DIR/vanadium.keystore"
APKSIGNER="$SRC_DIR/third_party/android_sdk/public/build-tools/36.0.0/apksigner"

# Add depot_tools to PATH
export PATH="/home/jacko/proj/dumb/depot_tools:$PATH"

echo "=== Dumb Browser Build Script ==="
echo ""

# Check for keystore
if [[ ! -f "$KEYSTORE" ]]; then
    echo "Warning: Keystore not found at $KEYSTORE"
    echo "APKs will be built but not signed."
    SIGN=false
else
    SIGN=true
fi

# Generate build files
echo "[1/4] Generating build files..."
cd "$SRC_DIR"
gn gen "$OUT_DIR" --args="$(cat "$SCRIPT_DIR/args.gn")"

# Build
echo ""
echo "[2/4] Building Trichrome APKs (this will take a while)..."
autoninja -C "$OUT_DIR" trichrome_webview_64_32_apk trichrome_chrome_64_32_apk trichrome_library_64_32_apk vanadium_config_apk

# Check if build succeeded
if [[ ! -d "$OUT_DIR/apks" ]]; then
    echo "Error: Build failed - no apks directory found"
    exit 1
fi

echo ""
echo "[3/4] Build complete. APKs located at:"
ls -la "$OUT_DIR/apks/"*.apk "$OUT_DIR/apks/"*.aab 2>/dev/null || true

# Sign if keystore exists
if [[ "$SIGN" == "true" ]]; then
    echo ""
    echo "[4/4] Signing APKs..."

    read -p "Enter keystore passphrase: " -s KEYSTORE_PASS
    echo ""

    RELEASE_DIR="$OUT_DIR/apks/release"
    mkdir -p "$RELEASE_DIR"

    for apk in "$OUT_DIR/apks/"*.apk; do
        if [[ -f "$apk" ]]; then
            filename=$(basename "$apk")
            echo "Signing $filename..."
            "$APKSIGNER" sign \
                --ks "$KEYSTORE" \
                --ks-pass "pass:$KEYSTORE_PASS" \
                --ks-key-alias vanadium \
                --in "$apk" \
                --out "$RELEASE_DIR/$filename"
        fi
    done

    echo ""
    echo "=== Signed APKs ==="
    ls -la "$RELEASE_DIR/"
else
    echo ""
    echo "[4/4] Skipping signing (no keystore)"
fi

# Copy APKs to GrapheneOS source tree
GRAPHENE_DIR="/home/jacko/proj/dumb/grapheneos-stable"
VANADIUM_PREBUILT="$GRAPHENE_DIR/external/vanadium/prebuilt"

echo ""
echo "[5/5] Copying APKs to GrapheneOS source tree..."

# Use signed APKs if available, otherwise use unsigned
if [[ "$SIGN" == "true" && -d "$RELEASE_DIR" ]]; then
    APK_SOURCE="$RELEASE_DIR"
else
    APK_SOURCE="$OUT_DIR/apks"
fi

cp "$APK_SOURCE/TrichromeLibrary6432.apk" "$VANADIUM_PREBUILT/arm64/TrichromeLibrary.apk"
cp "$APK_SOURCE/TrichromeChrome6432.apk" "$VANADIUM_PREBUILT/arm64/TrichromeChrome.apk"
cp "$APK_SOURCE/TrichromeWebView6432.apk" "$VANADIUM_PREBUILT/arm64/TrichromeWebView.apk"
cp "$APK_SOURCE/VanadiumConfig.apk" "$VANADIUM_PREBUILT/VanadiumConfig.apk"

echo "Copied to:"
echo "  $VANADIUM_PREBUILT/arm64/TrichromeLibrary.apk"
echo "  $VANADIUM_PREBUILT/arm64/TrichromeChrome.apk"
echo "  $VANADIUM_PREBUILT/arm64/TrichromeWebView.apk"
echo "  $VANADIUM_PREBUILT/VanadiumConfig.apk"

echo ""
echo "[6/6] Uploading to R2..."
BUCKET="os-uploads"
BUILD_ID="browser-$(date +%Y%m%d-%H%M%S)"
rclone copy "$RELEASE_DIR/TrichromeLibrary6432.apk" "r2:$BUCKET/$BUILD_ID/" --progress
rclone copy "$RELEASE_DIR/TrichromeChrome6432.apk" "r2:$BUCKET/$BUILD_ID/" --progress
rclone copy "$RELEASE_DIR/TrichromeWebView6432.apk" "r2:$BUCKET/$BUILD_ID/" --progress

echo ""
echo "=== Build Complete ==="
echo ""
echo "To download and install on your local machine:"
echo "  rclone copy r2:$BUCKET/$BUILD_ID/ . --progress && adb install-multiple TrichromeLibrary6432.apk TrichromeChrome6432.apk TrichromeWebView6432.apk"
