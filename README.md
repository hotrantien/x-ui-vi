# x-ui VI — Cài một lần trên VPS, quản lý qua web

**Bản dùng cố định: [`v0.3.2-vi.2`](https://github.com/hotrantien/x-ui-vi/releases/tag/v0.3.2-vi.2).**

Đây là bản Việt hóa x-ui tự đóng gói, có mã nguồn, giao diện, Xray Linux và
`geoip.dat` / `geosite.dat` trong chính repository `hotrantien/x-ui-vi`.
**Cài đặt không cần repository hoặc máy chủ phát hành của tác giả x-ui gốc.**
Không cần Go, Docker hay biên dịch trên VPS.

**Cách sử dụng:** SSH vào VPS **một lần** để cài, sau đó mở bảng điều khiển trên
máy tính hoặc điện thoại khác bằng `http://IP_VPS:PORT/`. Ứng dụng mặc định
**lắng nghe trên `0.0.0.0`** (mọi địa chỉ IPv4 của VPS), không cần SSH tunnel.

> **Cảnh báo bảo mật:** `0.0.0.0` cho phép kết nối mạng tới panel khi firewall
> mở cổng. Phiên bản x-ui/Xray này đã cũ và chưa được kiểm toán bảo mật toàn
> diện. Nếu dùng `http://` trực tiếp, mật khẩu đăng nhập truyền qua mạng không
> được mã hóa. Nên chỉ cho phép IP của bạn trên firewall và dùng HTTPS nếu
> truy cập qua Internet thường xuyên. Bản này phù hợp thử nghiệm/cá nhân hơn
> là môi trường sản xuất công khai.

## 1. Chuẩn bị VPS

- **Ubuntu 22.04 LTS 64-bit** (khuyên dùng), có SSH, `systemd`, `sudo` và Internet.
- CPU **AMD64/x86_64** hoặc **ARM64/aarch64** (script tự chọn gói).
- Một cổng TCP chưa được sử dụng, ví dụ `54321`.

Từ máy tính, đăng nhập VPS bằng SSH (thay `IP_VPS` và tài khoản nếu cần):

```bash
ssh ubuntu@IP_VPS
```

## 2. Cài bản cố định

Chạy các lệnh sau **trên VPS**:

```bash
sudo apt update
sudo apt install -y curl ca-certificates tar coreutils gawk

curl -fL --retry 3 -o install-x-ui-vi.sh \
  https://raw.githubusercontent.com/hotrantien/x-ui-vi/v0.3.2-vi.2/scripts/packaging/install-from-github.sh

sudo bash install-x-ui-vi.sh hotrantien/x-ui-vi v0.3.2-vi.2
```

Bộ cài tải đúng phiên bản từ [GitHub Releases của repository này](https://github.com/hotrantien/x-ui-vi/releases/tag/v0.3.2-vi.2),
kiểm tra SHA-256 rồi cài vào VPS. Không cần tải từ repo x-ui gốc.

Khi được hỏi cấu hình, hãy nhập **`y`** rồi đặt:

1. Tên tài khoản quản trị.
2. Mật khẩu mạnh, riêng biệt.
3. Cổng web quản trị, ví dụ **`54321`**.

**Lưu ý:** `0.0.0.0` là **địa chỉ lắng nghe ở phía VPS**, không phải địa chỉ
để nhập vào trình duyệt. Để truy cập, luôn dùng **IP công khai của VPS**.

## 3. Mở cổng quản trị

Ví dụ bạn đã chọn cổng `54321`:

```bash
sudo systemctl is-active x-ui
sudo systemctl is-enabled x-ui
sudo ss -lntp | grep ':54321'
```

Dịch vụ cần ở trạng thái `active`, `enabled`. Dòng `ss` cần thể hiện địa chỉ
`0.0.0.0:54321` (hoặc `*:54321`), tức panel đã nhận kết nối từ bên ngoài VPS.

**Firewall trong VPS:** kiểm tra trạng thái UFW:

```bash
sudo ufw status
```

Nếu UFW đang bật (`Status: active`), cho phép cổng TCP tương ứng:

```bash
sudo ufw allow 54321/tcp
```

Nếu UFW chưa cài hoặc đang tắt, không cần bật UFW chỉ để mở cổng; hãy kiểm tra
firewall thực tế của hệ điều hành (`iptables`/`nftables`) nếu vẫn không truy cập
được. **Không vô hiệu hóa firewall hoặc xóa các luật hiện có một cách tùy tiện.**

**Firewall trên nhà cung cấp VPS:** vào mục **Security Group / Cloud Firewall /
Ingress Rules** và cho phép **TCP cổng `54321`**. Nên giới hạn nguồn bằng **IP
công khai của máy bạn** nếu nhà cung cấp hỗ trợ; chỉ dùng `0.0.0.0/0` khi bạn
chấp nhận panel có thể được truy cập từ mọi nơi. Nếu dùng cổng khác, thay
`54321` ở tất cả các bước bằng cổng đã chọn.

## 4. Điều khiển trên máy khác

Sau khi mở cổng, trên PC hoặc điện thoại, nhập:

```text
http://IP_VPS:54321/
```

Đăng nhập bằng tài khoản ở bước 2. **Không cần SSH tunnel và không cần giữ
phiên SSH cài đặt đang mở.** Dịch vụ x-ui tự chạy cùng VPS qua `systemd`.

Nếu trang không mở được, kiểm tra cổng đã lắng nghe ở `0.0.0.0`, các luật
firewall của VPS và **Ingress Rule** ở nhà cung cấp. Nếu web truy cập được
nhưng kết nối Xray không hoạt động, cổng của từng inbound Xray cũng phải được
cho phép trong firewall (riêng với cổng quản trị).

## 5. Kiểm tra nhanh

```bash
sudo /usr/local/x-ui/x-ui -v
sudo systemctl status x-ui --no-pager
```

Phiên bản mong đợi: `0.3.2-vi.2`. Khi cần xem lỗi:

```bash
sudo journalctl -u x-ui -n 50 --no-pager
```

**Gói cài cố định** gồm `x-ui-linux-amd64.tar.gz`, `x-ui-linux-arm64.tar.gz`
và `SHA256SUMS`. Bạn có thể tải cả ba về máy để lưu dự phòng một lần, phòng khi
GitHub không truy cập được sau này. Không cần sử dụng chức năng nâng cấp.

Giữ nguyên thông tin tác giả và giấy phép tại [ORIGIN.md](ORIGIN.md) và
[LICENSE](LICENSE).
