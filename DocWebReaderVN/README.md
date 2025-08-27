# DocWebReaderVN (Kivy + gTTS)

App Android đọc văn bản tiếng Việt **giọng nữ** từ **một URL** hoặc từ nội dung bạn chỉnh sửa.

## Tính năng
- Nhập URL → Lấy nội dung chính của bài viết.
- Chỉnh sửa nội dung trước khi đọc.
- Đọc bằng **gTTS (vi)**, chia nhỏ văn bản tự động.
- Hoạt động trên Android qua **Buildozer**.

> Lưu ý: gTTS cần Internet để tạo giọng; app cũng cần Internet để tải nội dung web.

## Cách build APK (Linux/WSL/Ubuntu)
1. Cài Java & gói phụ trợ:
   ```bash
   sudo apt update
   sudo apt install -y python3-pip git openjdk-17-jdk zip unzip libffi-dev libssl-dev libsqlite3-dev
   ```
2. Cài buildozer:
   ```bash
   pip install --upgrade pip
   pip install "cython<3" buildozer
   ```
3. Khởi tạo môi trường p4a (lần đầu build buildozer sẽ tự setup).  
4. Trong thư mục dự án, chạy:
   ```bash
   buildozer -v android debug
   ```
5. File APK sẽ nằm ở `bin/` sau khi build xong, ví dụ:
   `bin/docwebreadervn-0.1-armeabi-v7a-debug.apk`

### Nếu gặp lỗi audio MP3
- Trên hầu hết máy Android, `SoundLoader` dùng `MediaPlayer` nên chạy MP3 tốt.  
- Nếu không phát được, mở `buildozer.spec` và thêm `ffpyplayer` vào `requirements`, rồi build lại:
  ```
  requirements = python3,kivy,requests,beautifulsoup4,gTTS,ffpyplayer
  ```

## Ghi chú
- Một số trang web render bằng JavaScript nặng có thể không lấy được nội dung (vì ứng dụng không chạy trình duyệt). Hãy thử chế độ đọc (Reader Mode) của trình duyệt để lấy URL "bài viết" hoặc copy nội dung vào ô nhập.
- Văn bản rất dài sẽ được chia thành nhiều đoạn (~1800 ký tự/đoạn) và phát nối tiếp.

Chúc bạn build thành công!
