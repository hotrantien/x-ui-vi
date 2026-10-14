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

## 3. Mở cổng một lần cho cả web và các kết nối VLESS

Ví dụ dùng cổng quản trị `54321` và dành trước dải **`20000–20100/tcp`** cho
VLESS. Khi thêm inbound VLESS qua web, chọn một cổng **trong dải này** (ví dụ
`20001`, `20002`...). Bạn không cần SSH để mở từng cổng sau đó.

Không chạy `iptables -F`: lệnh đó xóa các quy tắc firewall hiện có, có thể mở
nhầm dịch vụ khác ra Internet và không ảnh hưởng tới Security Group của VPS.

Đầu tiên kiểm tra ứng dụng đã chạy và panel lắng nghe trên mọi IPv4:

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

Nếu UFW đang bật (`Status: active`), cho phép cổng quản trị và toàn bộ dải
VLESS một lần:

```bash
sudo ufw allow 54321/tcp
sudo ufw allow 20000:20100/tcp
```

Nếu VLESS dùng truyền tải UDP, mở thêm `20000:20100/udp` bằng UFW. Chỉ mở giao
thức thực sự sử dụng, không cần mở tất cả cổng TCP/UDP của máy chủ.

Nếu UFW chưa cài hoặc đang tắt, **không bật UFW hoặc chạy `iptables -F` một cách
tùy tiện**. Trước tiên xem các luật hiện có:

```bash
sudo iptables -S INPUT
```

Trường hợp VPS dùng **iptables** và đang có các luật chặn cổng trong chuỗi
`INPUT`, có thể thêm hai luật cho phép này **mà không xóa luật cũ**:

```bash
sudo iptables -I INPUT 1 -p tcp --dport 54321 -j ACCEPT
sudo iptables -I INPUT 1 -p tcp --dport 20000:20100 -j ACCEPT
```

Nếu dùng UDP, thêm quy tắc UDP tương tự. Các luật `iptables` có thể mất sau
khởi động lại; nếu VPS đã sử dụng `netfilter-persistent`, chạy
`sudo netfilter-persistent save` để lưu cấu hình. Với hệ thống dùng `nftables`
hoặc công cụ firewall khác, hãy chỉnh trong đúng công cụ đang quản lý firewall,
không trộn nhiều công cụ khi chưa kiểm tra.

**Firewall trên nhà cung cấp VPS:** vào mục **Security Group / Cloud Firewall /
Ingress Rules**, tạo hai quy tắc nhận kết nối từ Internet:

| Giao thức | Cổng | Mục đích |
| --- | --- | --- |
| TCP | `54321` | Đăng nhập bảng điều khiển; nên giới hạn IP nguồn |
| TCP | `20000–20100` | Các inbound VLESS sẽ tạo sau này |

Nếu VLESS dùng UDP, tạo thêm quy tắc UDP cho dải cổng tương ứng. Giữ nguyên
quy tắc SSH TCP `22` (hoặc cổng SSH riêng đang dùng) để tránh tự khóa quyền
quản trị VPS. Không phải mở dải cổng trên nếu chỉ sử dụng các cổng cụ thể khác;
thay dải cho phù hợp ngay ở bước cài.

## 4. Điều khiển trên máy khác

Sau khi mở cổng, trên PC hoặc điện thoại, nhập:

```text
http://IP_VPS:54321/
```

Đăng nhập bằng tài khoản ở bước 2. **Không cần SSH tunnel và không cần giữ
phiên SSH cài đặt đang mở.** Dịch vụ x-ui tự chạy cùng VPS qua `systemd`.

Nếu trang không mở được, kiểm tra cổng đã lắng nghe ở `0.0.0.0`, các luật
firewall của VPS và **Ingress Rule** ở nhà cung cấp. Nếu web truy cập được
nhưng VLESS không hoạt động, kiểm tra **cổng inbound đã chọn nằm trong dải cho
phép**, ứng dụng Xray đã lắng nghe cổng đó và giao thức mạng (TCP/UDP) khớp
với quy tắc firewall. Ví dụ VLESS dùng cổng `443/tcp` thì phải mở thêm đúng
cổng `443/tcp` ở cả hai lớp firewall vì nằm ngoài dải ví dụ.

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
