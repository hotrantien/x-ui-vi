# x-ui VI — Cài đặt trên VPS mới

**Phiên bản cố định:** [`v0.3.2-vi.1`](https://github.com/hotrantien/x-ui-vi/releases/tag/v0.3.2-vi.1).

Đây là bản Việt hóa x-ui dành cho việc cài và sử dụng một phiên bản đã đóng gói sẵn.
Repository này lưu **toàn bộ mã nguồn, giao diện web, Xray Linux và dữ liệu
`geoip.dat` / `geosite.dat`**. Khi cài đặt, chỉ tải file từ **repository
`hotrantien/x-ui-vi` của bạn**, không gọi đến `vaxilu/x-ui` hoặc bản phát hành
của tác giả gốc. Không cần clone repo gốc, cài Go hay tự biên dịch.

> **Lưu ý:** Đây là bản x-ui/Xray thế hệ cũ, đã thử nghiệm chạy trên VPS Ubuntu
> 22.04 AMD64 nhưng chưa được kiểm toán bảo mật toàn diện. Dùng cho mục đích cá
> nhân hoặc thử nghiệm; nên giữ trang quản trị sau SSH tunnel, không công khai
> trực tiếp qua HTTP.

## 1. Chuẩn bị VPS

- VPS **Ubuntu 22.04 64-bit (khuyên dùng)**, có `systemd`, tài khoản được phép
  dùng `sudo`, có SSH và kết nối Internet để tải bản phát hành trên GitHub.
- CPU **AMD64/x86_64** hoặc **ARM64/aarch64**. Script tự chọn gói tương ứng.
- Chưa có dịch vụ x-ui khác chiếm tên hoặc cổng định cài.

Đăng nhập bằng SSH từ máy tính (thay `IP_VPS` bằng địa chỉ VPS của bạn):

```bash
ssh ubuntu@IP_VPS
```

Nếu VPS dùng tài khoản hoặc khóa SSH khác, thay thông tin kết nối cho phù hợp.

## 2. Cài x-ui VI

Chạy **trên VPS**, trong phiên SSH vừa mở:

```bash
sudo apt update
sudo apt install -y curl ca-certificates tar coreutils gawk

curl -fL --retry 3 -o install-x-ui-vi.sh \
  https://raw.githubusercontent.com/hotrantien/x-ui-vi/v0.3.2-vi.1/scripts/packaging/install-from-github.sh

sudo bash install-x-ui-vi.sh hotrantien/x-ui-vi v0.3.2-vi.1
```

Script tải đúng gói Linux từ [GitHub Release `v0.3.2-vi.1`](https://github.com/hotrantien/x-ui-vi/releases/tag/v0.3.2-vi.1),
kiểm tra **SHA-256**, rồi cài panel và Xray vào VPS. Không lấy thêm script hoặc
binary từ dự án gốc.

Khi bộ cài hỏi thông tin, hãy:

1. Nhập **`y`** để thiết lập tài khoản quản trị ngay trong lần cài đầu tiên.
2. Tự đặt **tên đăng nhập** và **mật khẩu mạnh** (không dùng mặc định).
3. Đặt **cổng quản trị**, ví dụ **`54321`**.

Không cần mở cổng quản trị ra Internet: bản mới mặc định chỉ lắng nghe tại
`127.0.0.1` trên VPS.

## 3. Kiểm tra sau khi cài

```bash
sudo systemctl is-active x-ui
sudo systemctl is-enabled x-ui
sudo /usr/local/x-ui/x-ui -v
```

Kết quả mong đợi: `active`, `enabled`, `0.3.2-vi.1`.

Nếu cần xem lỗi khi khởi động:

```bash
sudo journalctl -u x-ui -n 50 --no-pager
```

## 4. Mở giao diện web an toàn từ máy tính

Trên máy tính **Windows**, mở một cửa sổ PowerShell hoặc Terminal mới:

```powershell
ssh -N -L 15432:127.0.0.1:54321 ubuntu@IP_VPS
```

Giữ cửa sổ SSH này mở. Nếu bạn đã chọn cổng quản trị khác `54321`, hãy đổi số
`54321` ở lệnh trên thành cổng thực tế. Nếu đăng nhập SSH bằng khóa riêng,
thêm `-i "C:\duong-dan\khoa-ssh.txt"` vào lệnh `ssh`.

Sau đó mở trên trình duyệt máy tính:

**http://127.0.0.1:15432/**

Đăng nhập bằng tài khoản và mật khẩu bạn vừa tạo. Đây là địa chỉ **trên máy
tính của bạn**, được chuyển tiếp qua SSH tới VPS, không phải địa chỉ IP công
khai của VPS. Đóng cửa sổ SSH thì đường hầm cũng dừng; panel trên VPS vẫn chạy.

## Thông tin về gói cài

Release cố định gồm:

- `x-ui-linux-amd64.tar.gz` — VPS x86_64 / AMD64.
- `x-ui-linux-arm64.tar.gz` — VPS aarch64 / ARM64.
- `SHA256SUMS` — kiểm tra tính toàn vẹn file tải về.

Không cần dùng GitHub Actions, build Go hoặc cài Docker để chạy các gói này.
Nếu muốn lưu một bản dự phòng không cần GitHub, hãy tải ba file Release này
về máy tính và cất riêng. Các tệp nén đã chứa bộ cài và tài nguyên cần thiết.

Mã nguồn dựa trên x-ui gốc; thông tin tác giả, các thành phần bên thứ ba và
giấy phép GPLv3 được giữ tại [ORIGIN.md](ORIGIN.md) và [LICENSE](LICENSE).
