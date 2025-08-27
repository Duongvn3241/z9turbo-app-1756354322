# Build on phone (Termux)

**Requirements**: Termux (from F-Droid), Android 8+ recommended, 4GB+ free storage.

## Steps
1. Open Termux:
```bash
pkg update -y
pkg install -y wget unzip
```
2. Put `Z9Turbo.zip` and `build_on_phone.sh` into the same Termux directory (usually `$HOME`).
3. Run:
```bash
chmod +x build_on_phone.sh
./build_on_phone.sh
```
4. After build, copy APK to Downloads to install:
```bash
termux-setup-storage
cp ~/Z9Turbo/app/build/outputs/apk/debug/app-debug.apk ~/storage/downloads/Z9Turbo-debug.apk
```
Install from your Downloads app (bật “Install unknown apps”).

> Nếu Gradle báo thiếu bộ nhớ, đóng app khác, chạy lại và giữ màn hình Termux sáng.
