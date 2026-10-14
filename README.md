# x-ui VI — Cài một lần trên Oracle Cloud VPS, quản lý qua web

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

- **Oracle Cloud Infrastructure (OCI)**: Compute Instance có **Public IPv4**,
  nằm trong public subnet có route Internet Gateway. Chọn image **Ubuntu 22.04
  LTS 64-bit** (đã kiểm thử), có SSH, `systemd`, `sudo` và Internet.
- CPU **AMD64/x86_64** hoặc **ARM64/aarch64** (script tự chọn gói).
- Các cổng TCP `80`, `443` cho VLESS và `54321` cho quản trị (nếu chưa bị chiếm).

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

## 3. Mở ba cổng TCP trên Oracle Cloud (OCI)

Chỉ cần mở **TCP `80`, `443` và `54321` một lần**. Sau này tạo VLESS qua web
với cổng `80` hoặc `443`, không cần SSH trở lại để mở cổng. Cổng `54321` dành
riêng cho panel (thay bằng cổng quản trị đã chọn nếu khác).

### 3.1. Oracle Cloud Console — Security List hoặc NSG

1. Vào [Oracle Cloud Console](https://cloud.oracle.com/) → **Networking** →
   **Virtual Cloud Networks** → chọn **VCN** của VPS.
2. Chọn **Security Lists** → Security List gắn với **subnet** của VPS (thường
   là `Default Security List for ...`). Nếu VNIC dùng **Network Security
   Group (NSG)**, kiểm tra các **Security Rules** của NSG liên quan.
3. Chọn **Add Ingress Rules**, tạo các quy tắc bên dưới với **IP Protocol =
   TCP**, **Source Port = All**, **Stateless = bỏ chọn** (stateful):

| Destination Port | Source CIDR | Sử dụng |
| --- | --- | --- |
| `80` | `0.0.0.0/0` | VLESS TCP cổng 80 |
| `443` | `0.0.0.0/0` | VLESS TCP cổng 443 |
| `54321` | `IP_CUA_BAN/32` (nên dùng) | Web quản trị x-ui |

Nếu cần điều khiển panel từ nhiều mạng với IP thường xuyên thay đổi, có thể
đặt Source CIDR của `54321` là `0.0.0.0/0`, **nhưng khi đó màn hình đăng nhập
HTTP bị phơi ra Internet và không mã hóa mật khẩu**. Nên ưu tiên IP giới hạn
hoặc cấu hình HTTPS. **Giữ nguyên** quy tắc SSH `22/tcp` hiện có.

Các cổng chỉ có thể truy cập từ Internet nếu instance có Public IPv4 và subnet
có route qua Internet Gateway. Xem hướng dẫn [Oracle về Security Lists](https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/securitylists.htm)
và [ví dụ mở TCP 80/443](https://docs.oracle.com/en/learn/publish-webserver-using-oci/index.html).

### 3.2. Firewall bên trong Ubuntu trên Oracle Cloud

**Không chạy `iptables -F`**, không bật hoặc chỉnh UFW trên Oracle Ubuntu image
nếu chưa hiểu cấu hình của image. Oracle cảnh báo thay đổi firewall có thể ảnh
hưởng các quy tắc thiết yếu cho boot volume và làm VPS không khởi động được.
Xem [Oracle Compute Best Practices](https://docs.oracle.com/en-us/iaas/Content/Compute/References/bestpracticescompute.htm).

Kiểm tra các luật hiện tại, rồi chỉ **thêm** ba quy tắc TCP cần dùng vào
`INPUT`. Các lệnh dưới đây không xóa luật có sẵn và tránh tạo trùng:

```bash
sudo iptables -S INPUT

for port in 80 443 54321; do
  sudo iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || \
    sudo iptables -I INPUT 1 -p tcp --dport "$port" -j ACCEPT
done

sudo iptables -L INPUT -n --line-numbers
```

Để giữ các luật này sau khi **khởi động lại VPS**, trên Ubuntu dùng gói
`iptables-persistent` / lệnh `netfilter-persistent` (nếu chưa có):

```bash
sudo apt install -y iptables-persistent
sudo netfilter-persistent save
```

Nếu máy dùng firewall riêng do `nftables` hay phần mềm khác quản lý, hãy cấu
hình theo công cụ đó thay vì chèn luật vào hai hệ thống cùng lúc. Không thay
đổi luật SSH hoặc các luật `OUTPUT` phục vụ Oracle Cloud.

Kiểm tra panel lắng nghe trên mọi IPv4:

```bash
sudo systemctl is-active x-ui
sudo systemctl is-enabled x-ui
sudo ss -lntp | grep ':54321'
```

Kết quả mong đợi: `active`, `enabled` và `0.0.0.0:54321` (hoặc `*:54321`).

## 4. Điều khiển trên máy khác

Sau khi mở cổng, trên PC hoặc điện thoại, nhập:

```text
http://IP_VPS:54321/
```

Đăng nhập bằng tài khoản ở bước 2. **Không cần SSH tunnel và không cần giữ
phiên SSH cài đặt đang mở.** Dịch vụ x-ui tự chạy cùng VPS qua `systemd`.

Nếu trang không mở được, kiểm tra IP công khai, quy tắc OCI Security List/NSG,
firewall Ubuntu và lệnh `ss` ở trên. Nếu web vào được nhưng VLESS không hoạt
động, xem trong giao diện x-ui liệu inbound sử dụng đúng `80/tcp` hoặc
`443/tcp`, đã bật, và Xray có lắng nghe hay chưa (`sudo ss -lntp`).

**Lưu ý:** Cổng `443` không tự biến kết nối VLESS thành HTTPS/TLS; cần cấu hình
bảo mật và giao thức truyền tải tương ứng trong inbound. Một địa chỉ IP không
thể có hai tiến trình độc lập cùng lắng nghe một cổng TCP tại một thời điểm.

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
