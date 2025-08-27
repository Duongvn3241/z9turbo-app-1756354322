# Z9 Turbo (Android)

A lightweight, privacy-friendly booster that helps you quickly close resource-hungry apps and guide you to app settings to free up space. No ads, no trackers.

## What it can (and can't) do

- ✅ Show apps consuming foreground time recently (24h), so you can pick which to close.
- ✅ "Boost now": 
  1) Soft-kill background for selected apps; 
  2) Opens each app's info screen so the included **Accessibility Service** can press **Force stop** automatically.
- ✅ Open per-app settings to clear cache/data manually.
- ❌ It **cannot** magically increase hardware performance or clear other apps' caches without your consent — Android restricts that for safety.

## Build

1. Install **Android Studio** (Hedgehog or newer).
2. Open this folder as a project. If prompted about a Gradle wrapper, allow Android Studio to create it.
3. Connect/enable a device or emulator with Android 8.0+ (API 26+).
4. Click **Run** ▶️.

## First run: grant permissions

- In the app, tap **Cấp quyền Usage Access** and enable Z9 Turbo.
- Tap **Bật Accessibility** and enable **Z9 Turbo Boost Service**.

## Use

1. Tap **Quét lại** to load recent heavy apps.
2. Select apps you want to close.
3. Tap **Boost ngay** — watch it open each app info page and auto-press **Force stop**.

## Tips for a faster phone (manual, optional)
- Reduce animations in **Developer options** to 0.5x.
- Uninstall or disable rarely used apps.
- Limit "run in background" for chat/social apps you don't need always-on.
- Keep at least 15% free storage.

---

MIT License © 2025