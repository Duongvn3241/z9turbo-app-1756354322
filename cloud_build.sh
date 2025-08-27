#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

#--- Kiểm tra dự án ---
if [ ! -f "settings.gradle.kts" ] || [ ! -d "app" ]; then
  echo "❌ Không thấy settings.gradle.kts/app/. Hãy cd vào thư mục dự án (ví dụ: cd ~/Z9Turbo) rồi chạy lại."
  exit 1
fi

#--- Cấu hình Git cơ bản (nếu chưa có) ---
git config --global user.name  >/dev/null 2>&1 || git config --global user.name "Z9 User"
git config --global user.email >/dev/null 2>&1 || git config --global user.email "z9@example.com"
git config --global init.defaultBranch main

#--- Bật managed SDK + JVM ---
cat > gradle.properties <<'P'
org.gradle.jvmargs=-Xmx3g -Dfile.encoding=UTF-8
android.experimental.enableSdkDownload=true
kotlin.code.style=official
P

#--- Thêm plugin Compose Compiler (Kotlin 2.0.20) nếu thiếu ---
if ! grep -q 'org.jetbrains.kotlin.plugin.compose' app/build.gradle.kts; then
  awk 'BEGIN{p=0}
       /^plugins *\{/ {print; print "    id(\"org.jetbrains.kotlin.plugin.compose\") version \"2.0.20\""; p=1; next}
       {print}' app/build.gradle.kts > app/build.gradle.kts.fixed && mv app/build.gradle.kts.fixed app/build.gradle.kts
fi

#--- Tạo Gradle Wrapper 8.7 nếu thiếu ---
if [ ! -f "./gradlew" ]; then
  echo "→ Tạo Gradle wrapper 8.7…"
  cd ~
  [ -d gradle-8.7 ] || (wget -q https://services.gradle.org/distributions/gradle-8.7-bin.zip -O g.zip && unzip -q g.zip -d ~/ && rm -f g.zip)
  export PATH="$HOME/gradle-8.7/bin:$PATH"
  cd - >/dev/null
  gradle wrapper --gradle-version 8.7
  chmod +x gradlew
fi

#--- Thêm workflow Android CI ---
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
      - name: Build Debug APK (verbose + managed SDK)
        env:
          ORG_GRADLE_PROJECT_android.experimental.enableSdkDownload: "true"
        run: |
          set -e
          chmod +x ./gradlew || true
          if [ ! -f "./gradlew" ]; then
            curl -sL https://services.gradle.org/distributions/gradle-8.7-bin.zip -o g.zip
            unzip -q g.zip -d ~/g && rm g.zip
            ~/g/gradle-8.7/bin/gradle wrapper --gradle-version 8.7
            chmod +x ./gradlew
          fi
          echo "=== Versions ==="
          java -version || true
          ./gradlew --version || true
          echo "=== Clean ==="
          ./gradlew clean --no-daemon --stacktrace --info
          echo "=== Compile Kotlin debug ==="
          ./gradlew :app:compileDebugKotlin --no-daemon --stacktrace --info
          echo "=== Assemble Debug APK ==="
          ./gradlew assembleDebug --no-daemon --stacktrace --info
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: z9turbo-apk
          path: app/build/outputs/apk/debug/*.apk
          if-no-files-found: ignore
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: z9turbo-reports
          path: |
            **/build/reports/**
            **/build/outputs/logs/**
            **/build/outputs/mapping/**
          if-no-files-found: ignore
YAML

#--- Khởi tạo repo và push ---
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git init
fi
git add .
git commit -m "ci: add Android CI + wrapper + compose plugin" >/dev/null 2>&1 || true
git branch -M main

USER=$(gh api user --jq .login)
RAND=$(date +%s)
REPO="z9turbo-app-$RAND"
if gh repo view "$USER/$REPO" >/dev/null 2>&1; then
  REPO="z9turbo-app-$RAND-$RANDOM"
fi

if gh repo view "$USER/$REPO" >/dev/null 2>&1; then
  git remote remove origin >/dev/null 2>&1 || true
  git remote add origin "https://github.com/$USER/$REPO.git"
else
  gh repo create "$REPO" --public -y
  git remote add origin "https://github.com/$USER/$REPO.git"
fi

git push -u origin main

#--- Lấy RUN_ID & JOB_ID, xem log và tải artifact ---
echo "→ Chờ workflow chạy…"
sleep 3
RUN_ID=$(gh run list --workflow "Android CI" --branch main --limit 1 --json databaseId -q '.[0].databaseId')
echo "RUN_ID=$RUN_ID"

# theo dõi đến khi xong
gh run watch "$RUN_ID" || true

# lấy JOB_ID cho job đầu tiên (build)
JOB_ID=$(gh run view "$RUN_ID" --json jobs -q '.jobs[0].id' 2>/dev/null || echo "")
[ -n "$JOB_ID" ] && echo "JOB_ID=$JOB_ID"

# in 60 dòng cuối log job
if [ -n "$JOB_ID" ]; then
  echo "→ 60 dòng log cuối của job build:"
  gh run view "$RUN_ID" --job "$JOB_ID" --log | tail -n 60 || true
fi

# tải APK nếu có
mkdir -p ~/z9_artifact && cd ~/z9_artifact
gh run download "$RUN_ID" --name z9turbo-apk --dir . || true

# chép sang Downloads
termux-setup-storage <<<"y" >/dev/null 2>&1 || true
APK=$(find . -type f -name "*.apk" | head -n 1 || true)
if [ -n "${APK:-}" ]; then
  cp "$APK" ~/storage/downloads/Z9Turbo-debug.apk
  echo "✅ APK đã chép: ~/storage/downloads/Z9Turbo-debug.apk"
else
  echo "❌ Chưa có APK trong artifact. Kiểm tra log ở trên (và artifact z9turbo-reports nếu có)."
fi
