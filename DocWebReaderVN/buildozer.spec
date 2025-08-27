[app]
title = Đọc Văn Bản Từ Web (VI)
package.name = docwebreadervn
package.domain = org.example
source.dir = .
source.include_exts = py,kv,txt,md,mp3,png,jpg,ttf
# version.number = 0.1
# version.code = 1
orientation = portrait
fullscreen = 0

requirements = python3,kivy,requests,beautifulsoup4,gTTS
android.permissions = INTERNET
android.api = 33
android.minapi = 24
android.archs = armeabi-v7a, arm64-v8a

# Optional: if you face audio playback issues with mp3, uncomment ffpyplayer
# requirements = python3,kivy,requests,beautifulsoup4,gTTS,ffpyplayer

# Icon (optional)
# icon.filename = %(source.dir)s/icon.png

# Presplash (optional)
# presplash.filename = %(source.dir)s/presplash.png

[buildozer]
log_level = 2
warn_on_root = 1
