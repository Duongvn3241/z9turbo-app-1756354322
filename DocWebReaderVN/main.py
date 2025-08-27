# -*- coding: utf-8 -*-
import os
import re
import threading
import tempfile
import shutil
from functools import partial

import requests
from bs4 import BeautifulSoup

from kivy.app import App
from kivy.lang import Builder
from kivy.clock import Clock, mainthread
from kivy.properties import StringProperty, BooleanProperty, ListProperty
from kivy.uix.boxlayout import BoxLayout
from kivy.core.audio import SoundLoader
from gtts import gTTS


KV = """
<Root>:
    orientation: "vertical"
    padding: dp(12)
    spacing: dp(8)

    BoxLayout:
        size_hint_y: None
        height: dp(44)
        spacing: dp(8)

        TextInput:
            id: url_input
            hint_text: "Dán liên kết bài viết (URL) ..."
            text: root.last_url
            multiline: False
            on_text_validate: root.on_fetch_click(self.text)

        Button:
            text: "Lấy nội dung"
            on_release: root.on_fetch_click(url_input.text)

    Label:
        id: status_lbl
        text: root.status_text
        size_hint_y: None
        height: self.texture_size[1] + dp(6)
        halign: "left"
        valign: "middle"
        text_size: self.width, None

    TextInput:
        id: content_input
        text: root.content_text
        hint_text: "Nội dung sẽ hiện ở đây. Bạn có thể chỉnh sửa trước khi đọc."
        readonly: False
        multiline: True

    BoxLayout:
        size_hint_y: None
        height: dp(48)
        spacing: dp(8)

        Button:
            text: "Đọc"
            on_release: root.on_read_click()

        Button:
            text: "Dừng"
            on_release: root.on_stop_click()
"""

def clean_html_to_text(html: str) -> str:
    soup = BeautifulSoup(html, "html.parser")

    # Remove scripts/styles
    for tag in soup(["script", "style", "noscript", "header", "footer", "nav", "aside"]):
        tag.decompose()

    # Prefer <article> if present
    article = soup.find("article")
    if article:
        text = " ".join(p.get_text(" ", strip=True) for p in article.find_all(["p", "h1", "h2", "h3", "li"]))
    else:
        # Fallback: choose the container with the most paragraph text
        best_node = None
        best_len = 0
        for node in soup.find_all():
            ps = node.find_all("p")
            if not ps:
                continue
            txt = " ".join(p.get_text(" ", strip=True) for p in ps)
            L = len(txt)
            if L > best_len:
                best_len = L
                best_node = node
        if best_node:
            text = " ".join(p.get_text(" ", strip=True) for p in best_node.find_all(["p", "h1", "h2", "h3", "li"]))
        else:
            # Ultimate fallback: full page text
            text = soup.get_text(" ", strip=True)

    # Normalize whitespace
    text = re.sub(r"\s+", " ", text).strip()
    return text


def split_into_chunks(text: str, max_chars: int = 1800):
    # Split by sentences, then pack into chunks under max_chars
    sentences = re.split(r"(?<=[\.\?\!…])\s+", text)
    chunks = []
    current = ""
    for s in sentences:
        if not s:
            continue
        if len(current) + len(s) + 1 <= max_chars:
            current = (current + " " + s).strip()
        else:
            if current:
                chunks.append(current)
            if len(s) <= max_chars:
                current = s
            else:
                # Hard split long sentence
                for i in range(0, len(s), max_chars):
                    chunks.append(s[i:i+max_chars])
                current = ""
    if current:
        chunks.append(current)
    return chunks


class Root(BoxLayout):
    status_text = StringProperty("Sẵn sàng.")
    content_text = StringProperty("")
    last_url = StringProperty("")
    _audio_files = ListProperty([])
    _current_sound = None
    _is_generating = BooleanProperty(False)
    _stop_flag = BooleanProperty(False)

    def on_fetch_click(self, url: str):
        url = (url or "").strip()
        if not url or not (url.startswith("http://") or url.startswith("https://")):
            self.set_status("Vui lòng nhập URL hợp lệ (bắt đầu bằng http/https).")
            return
        self.last_url = url
        self.set_status("Đang tải nội dung...")
        threading.Thread(target=self._fetch_thread, args=(url,), daemon=True).start()

    def on_read_click(self):
        text = self.ids.content_input.text.strip()
        if not text:
            self.set_status("Không có nội dung để đọc.")
            return
        if self._is_generating:
            self.set_status("Đang tạo audio, vui lòng đợi...")
            return
        self._stop_flag = False
        self.set_status("Đang chuẩn bị đọc...")
        threading.Thread(target=self._tts_thread, args=(text,), daemon=True).start()

    def on_stop_click(self):
        self._stop_flag = True
        # Stop current sound
        if self._current_sound:
            try:
                self._current_sound.stop()
            except Exception:
                pass
            self._current_sound = None

        # Clear queue and delete files
        self._cleanup_audio_files()
        self.set_status("Đã dừng.")

    def _fetch_thread(self, url: str):
        try:
            headers = {
                "User-Agent": "Mozilla/5.0 (Android 13; Mobile) KivyApp/1.0",
                "Accept-Language": "vi-VN,vi;q=0.9,en;q=0.8"
            }
            resp = requests.get(url, headers=headers, timeout=15)
            resp.raise_for_status()
            text = clean_html_to_text(resp.text)
            if not text:
                raise RuntimeError("Không trích xuất được nội dung.")
            self.set_content(text)
            self.set_status("Đã lấy nội dung. Bạn có thể chỉnh sửa trước khi đọc.")
        except Exception as e:
            self.set_status(f"Lỗi tải nội dung: {e}")

    def _tts_thread(self, text: str):
        self._is_generating = True
        self._cleanup_audio_files()
        try:
            chunks = split_into_chunks(text, max_chars=1800)
            if not chunks:
                self.set_status("Văn bản trống.")
                return

            tmp_dir = os.path.join(App.get_running_app().user_data_dir, "tts_cache")
            os.makedirs(tmp_dir, exist_ok=True)

            # Generate mp3 files with gTTS (Vietnamese female-sounding voice)
            files = []
            total = len(chunks)
            for i, chunk in enumerate(chunks, 1):
                if self._stop_flag:
                    self.set_status("Đã hủy tạo audio.")
                    return
                self.set_status(f"Tạo audio {i}/{total} ...")
                tts = gTTS(text=chunk, lang="vi", slow=False)
                out_path = os.path.join(tmp_dir, f"chunk_{i:03d}.mp3")
                tts.save(out_path)
                files.append(out_path)

            self._audio_files = files
            self.set_status("Bắt đầu đọc...")
            Clock.schedule_once(lambda dt: self._play_next(), 0)
        except Exception as e:
            self.set_status(f"Lỗi TTS: {e}")
        finally:
            self._is_generating = False

    @mainthread
    def _play_next(self, *args):
        if self._stop_flag:
            self._cleanup_audio_files()
            return

        if not self._audio_files:
            self.set_status("Đọc xong.")
            self._cleanup_audio_files()
            return

        next_file = self._audio_files.pop(0)
        try:
            if self._current_sound:
                try:
                    self._current_sound.unload()
                except Exception:
                    pass
                self._current_sound = None

            sound = SoundLoader.load(next_file)
            if sound is None:
                # Skip broken file
                self._play_next()
                return

            self._current_sound = sound

            def on_stop(_):
                # When a chunk ends, play the next
                Clock.schedule_once(lambda dt: self._play_next(), 0.1)

            sound.bind(on_stop=on_stop)
            sound.play()
        except Exception as e:
            self.set_status(f"Lỗi phát audio: {e}")
            # try next
            Clock.schedule_once(lambda dt: self._play_next(), 0.1)

    def _cleanup_audio_files(self):
        # Remove cached audio dir
        try:
            cache_dir = os.path.join(App.get_running_app().user_data_dir, "tts_cache")
            if os.path.isdir(cache_dir):
                shutil.rmtree(cache_dir, ignore_errors=True)
        except Exception:
            pass
        self._audio_files = []
        self._current_sound = None

    @mainthread
    def set_content(self, text: str):
        self.content_text = text
        self.ids.content_input.text = text

    @mainthread
    def set_status(self, msg: str):
        self.status_text = msg


class DocWebReaderVN(App):
    def build(self):
        self.title = "Đọc Văn Bản Từ Web (VI)"
        Builder.load_string(KV)
        return Root()

if __name__ == "__main__":
    DocWebReaderVN().run()
