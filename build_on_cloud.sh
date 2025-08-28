#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

# ====== Kiểm tra dự án ======
if [ ! -f "settings.gradle.kts" ] || [ ! -d "app" ]; then
  echo "❌ Không thấy settings.gradle.kts/app/. Hãy cd vào thư mục dự án (vd: cd ~/Z9Turbo) rồi chạy lại."
  exit 1
fi

# ====== Cài gói cần thiết ======
pkg update -y
pkg install -y git gh openjdk-17 unzip wget sed grep || true

# ====== Git config tối thiểu ======
git config --global user.name  >/dev/null 2>&1 || git config --global user.name "Z9 User"
git config --global user.email >/dev/null 2>&1 || git config --global user.email "z9@example.com"
git config --global init.defaultBranch main

# ====== Gradle properties (managed SDK, JVM) ======
cat > gradle.properties <<'P'
org.gradle.jvmargs=-Xmx3g -Dfile.encoding=UTF-8
android.experimental.enableSdkDownload=true
kotlin.code.style=official
P

# ====== Đảm bảo Compose cho Kotlin 2.0.x – chỉ dùng sed/grep ======
# 1) Thêm plugin compose compiler nếu thiếu
if ! grep -q 'org.jetbrains.kotlin.plugin.compose' app/build.gradle.kts; then
  sed -i '/^plugins *{/a\    id("org.jetbrains.kotlin.plugin.compose") version "2.0.20"' app/build.gradle.kts
fi

# 2) Nâng BOM Compose lên 2024.08.00 (nếu dòng này tồn tại)
if grep -q 'androidx\.compose:compose-bom:' app/build.gradle.kts; then
  sed -i 's/androidx\.compose:compose-bom:[^"]\+/androidx.compose:compose-bom:2024.08.00/g' app/build.gradle.kts
fi

# 3) Xoá khối composeOptions { ... } nếu còn (không cần khi đã dùng plugin compose 2.x)
#    Xoá từ dòng có 'composeOptions' tới dấu '}'
sed -i '/composeOptions[[:space:]]*{/,/}/d' app/build.gradle.kts || true

# 4) Thêm compileOptions Java 17 nếu chưa có
if ! grep -q 'compileOptions' app/build.gradle.kts; then
  sed -i '/android[[:space:]]*{/a\
\    compileOptions {\n\
\        sourceCompatibility = JavaVersion.VERSION_17\n\
\        targetCompatibility = JavaVersion.VERSION_17\n\
\    }' app/build.gradle.kts
fi

# 5) Thêm kotlinOptions { jvmTarget = "17" } nếu chưa có
if ! grep -q 'kotlinOptions' app/build.gradle.kts; then
  sed -i '/android[[:space:]]*{/a\
\    kotlinOptions {\n\
\        jvmTarget = "17"\n\
\    }' app/build.gradle.kts
fi

# ====== Gradle wrapper 8.7 (nếu thiếu) ======
if [ ! -f "./gradlew" ]; then
  echo "→ Tạo Gradle wrapper 8.7…"
  cd ~
  [ -d gradle-8.7 ] || (wget -q https://services.gradle.org/distributions/gradle-8.7-bin.zip -O g.zip && unzip -q g.zip -d ~/ && rm -f g.zip)
  export PATH="$HOME/gradle-8.7/bin:$PATH"
  cd - >/dev/null
  gradle wrapper --gradle-version 8.7
  chmod +x gradlew
fi

# ====== Android CI workflow ======
mkdir -p .github/workflows
cat > .github/workflows/android.yml <<'YAML'
name: Android CI
on:
  push:
    branches: [ "main" ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"
      - name: Ensure Gradle Wrapper 8.7
        run: |
          chmod +x ./gradlew || true
          if [ ! -f "./gradlew" ]; then
            curl -sL https://services.gradle.org/distributions/gradle-8.7-bin.zip -o g.zip
            unzip -q g.zip -d ~/g && rm g.zip
            ~/g/gradle-8.7/bin/gradle wrapper --gradle-version 8.7
            chmod +x ./gradlew
          fi
          ./gradlew --version
      - name: Build Debug APK (verbose + managed SDK)
        env:
          ORG_GRADLE_PROJECT_android.experimental.enableSdkDownload: "true"
        run: |
          set -e
          mkdir -p build_logs
          ./gradlew clean                   --no-daemon --stacktrace --info 2>&1 | tee build_logs/01_clean.log
          ./gradlew :app:compileDebugKotlin --no-daemon --stacktrace --info 2>&1 | tee build_logs/02_compile_kotlin.log
          ./gradlew assembleDebug           --no-daemon --stacktrace --info 2>&1 | tee build_logs/03_assemble.log
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: z9turbo-apk
          path: app/build/outputs/apk/debug/*.apk
          if-no-files-found: ignore
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: z9turbo-logs
          path: build_logs/*.log
          if-no-files-found: warn
YAML

# ====== Khởi tạo / commit / đẩy lên GitHub ======
git init 2>/dev/null || true
git add .
git commit -m "ci: cloud build setup (V2 no-perl)" >/dev/null 2>&1 || true
git branch -M main

USER=$(gh api user --jq .login)
REPO="z9turbo-app-$(date +%s)"
git remote remove origin 2>/dev/null || true
gh repo create "$REPO" --public -y || true
git remote add origin "https://github.com/$USER/$REPO.git" 2>/dev/null || git remote set-url origin "https://github.com/$USER/$REPO.git"
git push -u origin main --force

# ====== Theo dõi CI & tải APK ======
echo "→ Chờ workflow chạy…"
sleep 3
RUN_ID=$(gh run list --repo "$USER/$REPO" --workflow "Android CI" --limit 1 --json databaseId -q '.[0].databaseId' || echo "")
[ -z "$RUN_ID" ] && { echo "❌ Không tìm thấy run. Hãy kiểm tra tab Actions trên GitHub."; exit 1; }

gh run watch "$RUN_ID" --repo "$USER/$REPO" || true

mkdir -p ~/z9_artifact && cd ~/z9_artifact
gh run download "$RUN_ID" --repo "$USER/$REPO" --name z9turbo-apk --dir . || true
gh run download "$RUN_ID" --repo "$USER/$REPO" --name z9turbo-logs --dir . || true

termux-setup-storage <<<"y" >/dev/null 2>&1 || true
APK=$(find . -type f -name "*.apk" | head -n 1 || true)
if [ -n "${APK:-}" ]; then
  cp "$APK" ~/storage/downloads/Z9Turbo-debug.apk
  echo "✅ APK đã chép: ~/storage/downloads/Z9Turbo-debug.apk"
else
  echo "❌ Chưa có APK. Xem log tại ~/z9_artifact/build_logs/*.log để biết lỗi gốc."
fi
