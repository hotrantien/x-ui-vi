# x-ui VI — Cài một lần trên Oracle Cloud VPS, quản lý qua web

**Bản dùng cố định: [`v0.3.2-vi.5`](https://github.com/hotrantien/x-ui-vi/releases/tag/v0.3.2-vi.5).**

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

Trên VPS Ubuntu 22.04, chạy **một lệnh duy nhất**:

```bash
set -o pipefail && curl -fsSL https://raw.githubusercontent.com/hotrantien/x-ui-vi/main/quick-install.sh | sudo bash
```

Lệnh tải script khởi động từ repo của bạn và chạy trực tiếp bằng Bash. Script
**cố định tag `v0.3.2-vi.5`**, tải gói từ [GitHub Releases của repository này](https://github.com/hotrantien/x-ui-vi/releases/tag/v0.3.2-vi.5),
kiểm tra SHA-256 rồi cài panel và Xray. Không cần tải từ repo x-ui gốc hoặc
tạo file cài trong thư mục hiện tại. Bạn cần **giữ phiên SSH mở trong lúc cài**
để nhập tài khoản, mật khẩu và cổng. Sau khi hoàn tất có thể đóng SSH.

Nếu máy thiếu `curl`, cài một lần bằng `sudo apt update && sudo apt install -y curl`.
Chỉ chạy lệnh từ repo bạn tin cậy: `curl | sudo bash` thực thi script tải qua
mạng với quyền quản trị.

Khi được hỏi cấu hình, hãy nhập **`y`** rồi đặt:

1. Tên tài khoản quản trị.
2. Mật khẩu mạnh, riêng biệt.
3. Cổng web quản trị: **nhấn Enter để giữ mặc định `54321`**, hoặc nhập một
   cổng khác từ `1` đến `65535`.

**Lưu ý:** `0.0.0.0` là **địa chỉ lắng nghe ở phía VPS**, không phải địa chỉ
để nhập vào trình duyệt. Để truy cập, luôn dùng **IP công khai của VPS**.

## 3. Các cổng TCP được mở tự động

Ngay sau khi **cài mới**, bộ cài tự thêm luật `iptables` cho **TCP `54321`,
`80` và `443`**, không cần nhập từng cổng hoặc chạy thêm lệnh mở cổng. Nếu
bạn đặt cổng web khác `54321`, bộ cài mở cả cổng đó. Bạn có thể tạo VLESS
trên `80` hoặc `443` qua web sau này.

**Trên Oracle Cloud:** bạn tự mở Ingress TCP `80`, `443` và cổng quản trị
`54321` (nếu đổi cổng, mở cổng tương ứng) trong Security List/NSG. Giữ nguyên
cổng SSH. Nên giới hạn IP nguồn truy cập **cổng quản trị** thay vì mở cho mọi
địa chỉ; phần này không cần cấu hình qua script cài đặt.

### Firewall bên trong Ubuntu trên Oracle Cloud

**Không chạy `iptables -F`**, không bật hoặc chỉnh UFW trên Oracle Ubuntu image
nếu chưa hiểu cấu hình của image. Oracle cảnh báo thay đổi firewall có thể ảnh
hưởng các quy tắc thiết yếu cho boot volume và làm VPS không khởi động được.
Xem [Oracle Compute Best Practices](https://docs.oracle.com/en-us/iaas/Content/Compute/References/bestpracticescompute.htm).

Trên VPS mới, bộ cài chỉ thêm luật vào `INPUT`, **không xóa luật Oracle có
sẵn**. Khi đã có `netfilter-persistent`, các luật được tự lưu để vẫn còn
sau khởi động lại. Nếu bộ cài cảnh báo thiếu công cụ lưu firewall, chạy:

```bash
sudo apt install -y iptables-persistent
sudo netfilter-persistent save
```

Nếu cần áp dụng lại các cổng mặc định, dùng **`sudo x-ui` → mục 2** hoặc
`sudo x-ui open-port` (không nhập tham số). Lệnh chỉ thêm luật chưa có. Muốn
mở một cổng khác riêng lẻ: `sudo x-ui open-port 8443 tcp`.

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

Phiên bản mong đợi: `0.3.2-vi.5`. Khi cần xem lỗi:

```bash
sudo journalctl -u x-ui -n 50 --no-pager
```

Nếu cần mở menu quản trị từ SSH, dùng **`sudo x-ui`**. Script quản trị
yêu cầu quyền root; chạy `x-ui` bằng tài khoản `ubuntu` thông thường có thể
báo `Permission denied`. Đây không phải lỗi dịch vụ và không cần sửa quyền
tệp hoặc cài lại. Sau lần cài đầu tiên, bạn có thể đóng SSH và chỉ sử dụng
web để quản lý VLESS.

**Gói cài cố định** gồm `x-ui-linux-amd64.tar.gz`, `x-ui-linux-arm64.tar.gz`
và `SHA256SUMS`. Bạn có thể tải cả ba về máy để lưu dự phòng một lần, phòng khi
GitHub không truy cập được sau này. Không cần sử dụng chức năng nâng cấp.

Giữ nguyên thông tin tác giả và giấy phép tại [ORIGIN.md](ORIGIN.md) và
[LICENSE](LICENSE).
