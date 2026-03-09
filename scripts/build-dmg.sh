#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Spotti DMG Builder
# =============================================================================

# --- Configuration -----------------------------------------------------------
APP_NAME="Spotti"
SCHEME="Spotti"
DMG_WINDOW_WIDTH=540
DMG_WINDOW_HEIGHT=540
DMG_ICON_SIZE=80

# Set these when you have a Developer ID certificate and notarytool profile.
# Leave empty to skip signing/notarization.
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
NOTARIZE_PROFILE="${NOTARIZE_PROFILE:-}"

# --- Paths -------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
EXPORT_DIR="$BUILD_DIR/export"
APP_PATH="$EXPORT_DIR/$APP_NAME.app"
XCODEPROJ="$PROJECT_DIR/SpottiApp/Spotti/Spotti.xcodeproj"

# --- Flags -------------------------------------------------------------------
NO_CLEAN=false
SKIP_RUST=false
SKIP_SIGN=false
SKIP_NOTARIZE=false

for arg in "$@"; do
    case "$arg" in
        --no-clean)       NO_CLEAN=true ;;
        --skip-rust)      SKIP_RUST=true ;;
        --skip-sign)      SKIP_SIGN=true ;;
        --skip-notarize)  SKIP_NOTARIZE=true ;;
        --help|-h)
            echo "Usage: $0 [--no-clean] [--skip-rust] [--skip-sign] [--skip-notarize]"
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg"
            exit 1
            ;;
    esac
done

# --- Helpers -----------------------------------------------------------------
step() { echo ""; echo "==> $1"; }
info() { echo "    $1"; }
fail() { echo "ERROR: $1" >&2; exit 1; }

# --- Preflight ---------------------------------------------------------------
# Extract version from pbxproj directly (avoids xcodebuild DerivedData permission issues)
VERSION=$(grep 'MARKETING_VERSION' "$XCODEPROJ/project.pbxproj" | head -1 | sed 's/.*= *//;s/ *;.*//')
VERSION="${VERSION:-1.0}"

DMG_NAME="$APP_NAME-$VERSION"
DMG_FINAL="$BUILD_DIR/$DMG_NAME.dmg"

step "Building $APP_NAME $VERSION"

command -v xcodebuild >/dev/null 2>&1 || fail "xcodebuild is not available. Install Xcode."
command -v uv >/dev/null 2>&1 || fail "uv is not installed. Run: brew install uv"

# --- Step 0: Clean -----------------------------------------------------------
if [ "$NO_CLEAN" = false ]; then
    step "Cleaning build directory"
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"

# --- Step 1: Build Rust Core ------------------------------------------------
if [ "$SKIP_RUST" = false ]; then
    step "Building Rust core"
    "$SCRIPT_DIR/build-rust.sh"
else
    step "Skipping Rust build (--skip-rust)"
fi

# --- Step 2: Build Release ---------------------------------------------------
step "Building $SCHEME (Release)"
SYMROOT="$BUILD_DIR/sym"

xcodebuild build \
    -project "$XCODEPROJ" \
    -scheme "$SCHEME" \
    -destination 'platform=macOS' \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    SYMROOT="$SYMROOT" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    ONLY_ACTIVE_ARCH=YES \
    ARCHS=arm64 \
    | tail -5

# Find the built .app
BUILT_APP=$(find "$SYMROOT/Release" -maxdepth 1 -name "*.app" -type d | head -1)
[ -n "$BUILT_APP" ] || fail "Build succeeded but could not find .app in $SYMROOT/Release"

# --- Step 3: Export App ------------------------------------------------------
step "Exporting app bundle"
rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"
cp -R "$BUILT_APP" "$APP_PATH"
info "Exported to $APP_PATH"

# --- Step 4: Code Sign -------------------------------------------------------
if [ "$SKIP_SIGN" = false ]; then
    IDENTITY="${SIGNING_IDENTITY:--}"
    step "Code signing app (identity: $IDENTITY)"

    ENTITLEMENTS_FLAG=""
    if [ -f "$PROJECT_DIR/Spotti.entitlements" ]; then
        ENTITLEMENTS_FLAG="--entitlements $PROJECT_DIR/Spotti.entitlements"
        info "Using entitlements: Spotti.entitlements"
    fi

    if [ "$IDENTITY" != "-" ]; then
        codesign --deep --force --options runtime \
            --sign "$IDENTITY" \
            $ENTITLEMENTS_FLAG \
            "$APP_PATH"
    else
        codesign --deep --force \
            --sign - \
            $ENTITLEMENTS_FLAG \
            "$APP_PATH"
    fi

    info "App signed with: $IDENTITY"
else
    step "Skipping code signing (--skip-sign)"
fi

# --- Step 5: Create DMG -----------------------------------------------------
step "Creating DMG"

rm -f "$DMG_FINAL"
DMG_BG="$SCRIPT_DIR/dmg_bg.png"
DMG_SETTINGS="$SCRIPT_DIR/dmgbuild_settings.py"

# Resolve volume icon
VOLUME_ICON=""
ICNS_PATH="$APP_PATH/Contents/Resources/AppIcon.icns"
if [ -f "$ICNS_PATH" ]; then
    VOLUME_ICON="$ICNS_PATH"
elif [ -f "$PROJECT_DIR/icon.png" ]; then
    ICONSET_DIR="$BUILD_DIR/VolumeIcon.iconset"
    mkdir -p "$ICONSET_DIR"
    for size in 16 32 64 128 256 512; do
        sips -z $size $size "$PROJECT_DIR/icon.png" --out "$ICONSET_DIR/icon_${size}x${size}.png" > /dev/null 2>&1
        double=$((size * 2))
        sips -z $double $double "$PROJECT_DIR/icon.png" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" > /dev/null 2>&1
    done
    iconutil -c icns "$ICONSET_DIR" -o "$BUILD_DIR/VolumeIcon.icns" 2>/dev/null
    VOLUME_ICON="$BUILD_DIR/VolumeIcon.icns"
fi

uv run --with dmgbuild \
    dmgbuild \
    -s "$DMG_SETTINGS" \
    -D app_path="$APP_PATH" \
    -D background_path="$DMG_BG" \
    -D volume_icon="$VOLUME_ICON" \
    "$APP_NAME" \
    "$DMG_FINAL"

[ -f "$DMG_FINAL" ] || fail "dmgbuild failed to produce $DMG_FINAL"
info "DMG created: $DMG_FINAL"

# --- Step 6: Sign DMG (optional) --------------------------------------------
if [ -n "$SIGNING_IDENTITY" ] && [ "$SKIP_SIGN" = false ]; then
    step "Signing DMG"
    codesign --force --sign "$SIGNING_IDENTITY" "$DMG_FINAL"
    info "DMG signed"
else
    step "Skipping DMG signing"
fi

# --- Step 7: Notarize (optional) --------------------------------------------
if [ -n "$NOTARIZE_PROFILE" ] && [ "$SKIP_NOTARIZE" = false ]; then
    step "Submitting for notarization"
    SUBMIT_OUTPUT=$(xcrun notarytool submit "$DMG_FINAL" \
        --keychain-profile "$NOTARIZE_PROFILE" \
        --wait 2>&1)

    echo "$SUBMIT_OUTPUT"

    if echo "$SUBMIT_OUTPUT" | grep -q "status: Accepted"; then
        step "Stapling notarization ticket"
        xcrun stapler staple "$DMG_FINAL"
        info "Notarization complete"
    else
        SUBMISSION_ID=$(echo "$SUBMIT_OUTPUT" | grep "id:" | head -1 | awk '{print $NF}')
        fail "Notarization failed. Check logs: xcrun notarytool log $SUBMISSION_ID --keychain-profile $NOTARIZE_PROFILE"
    fi
else
    step "Skipping notarization"
fi

# --- Done --------------------------------------------------------------------
step "Done!"
DMG_SIZE=$(du -sh "$DMG_FINAL" | cut -f1)
info "$DMG_FINAL ($DMG_SIZE)"
