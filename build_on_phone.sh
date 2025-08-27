#!/data/data/com.termux/files/usr/bin/bash
set -e

# -------- Config --------
export SDK_ROOT="$HOME/android-sdk"
export ANDROID_HOME="$SDK_ROOT"
export ANDROID_SDK_ROOT="$SDK_ROOT"
BUILD_TOOLS_VER="34.0.0"
PLATFORM_VER="android-34"
CMDLINE_TOOLS_VER="11076708_latest"
PROJECT_DIR="$HOME/Z9Turbo"
GRADLE_USER_HOME="$HOME/.gradle"
# ------------------------

echo "[1/7] Installing Termux packages..."
pkg update -y
pkg install -y openjdk-17 gradle zip unzip wget git || true
# rsync là optional; nếu không có cũng không sao
pkg install -y rsync || true

mkdir -p "$SDK_ROOT/cmdline-tools" "$PROJECT_DIR"

echo "[2/7] Project setup ..."
CUR_DIR="$(pwd)"
if [ -f "./settings.gradle.kts" ] && [ -f "./app/build.gradle.kts" ]; then
  # Đang ở GỐC dự án rồi
  if [ "$(realpath "$CUR_DIR")" = "$(realpath "$PROJECT_DIR")" ]; then
    echo "Already in project root ($PROJECT_DIR). Skip copying."
  else
    echo "Copy project into $PROJECT_DIR ..."
    if command -v rsync >/dev/null 2>&1; then
      rsync -a ./ "$PROJECT_DIR"/
    else
      cp -r ./ "$PROJECT_DIR"/
    fi
  fi
elif [ -f "./Z9Turbo_with_phone_build.zip" ] || [ -f "./Z9Turbo.zip" ]; then
  ZIPFILE="./Z9Turbo_with_phone_build.zip"
  [ -f "$ZIPFILE" ] || ZIPFILE="./Z9Turbo.zip"
  echo "Unzip $ZIPFILE to $PROJECT_DIR ..."
  unzip -o "$ZIPFILE" -d "$PROJECT_DIR"
else
  echo "Put this script inside project folder or next to Z9Turbo_with_phone_build.zip"
  exit 1
fi

cd "$SDK_ROOT"

echo "[3/7] Downloading Android cmdline-tools..."
URL="https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VER}.zip"
[ -f commandlinetools.zip ] || wget -O commandlinetools.zip "$URL"
rm -rf cmdline-tools/latest || true
unzip -o commandlinetools.zip -d cmdline-tools-tmp
mkdir -p cmdline-tools/latest
mv -f cmdline-tools-tmp/cmdline-tools/* cmdline-tools/latest/ 2>/dev/null || true
rm -rf cmdline-tools-tmp

export PATH="$SDK_ROOT/cmdline-tools/latest/bin:$SDK_ROOT/platform-tools:$PATH"
yes | sdkmanager --licenses >/dev/null

echo "[4/7] Installing SDK packages..."
sdkmanager "platform-tools" "platforms;${PLATFORM_VER}" "build-tools;${BUILD_TOOLS_VER}"

echo "[5/7] Env check:"
java -version || true
gradle -v || true
sdkmanager --list | head -n 30 || true

echo "[6/7] Building debug APK..."
cd "$PROJECT_DIR"
mkdir -p "$GRADLE_USER_HOME"
echo "org.gradle.jvmargs=-Xmx1024m -Dfile.encoding=UTF-8" > "$GRADLE_USER_HOME/gradle.properties"

gradle assembleDebug --no-daemon --warning-mode all

APK_PATH=$(find "$PROJECT_DIR/app/build/outputs/apk/debug" -name "*-debug.apk" | head -n 1)
if [ -z "$APK_PATH" ]; then
  echo "Build failed: no APK found."
  exit 1
fi

echo "[7/7] APK ready: $APK_PATH"
echo "To copy to Downloads:"
echo "  termux-setup-storage"
echo "  cp \"$APK_PATH\" \"\$HOME/storage/downloads/Z9Turbo-debug.apk\""
