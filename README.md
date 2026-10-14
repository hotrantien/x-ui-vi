# x-ui VI — bản Việt hóa tự quản lý

**x-ui VI `0.3.2-vi.1`** là bản Việt hóa bảng điều khiển Xray dựa trên
mã nguồn x-ui đời đầu, có bộ cài Linux, workflow build và GitHub Release riêng.
Mục tiêu: **repo của bạn vẫn tự clone, build, cài và cập nhật được ngay cả khi
repository của tác giả gốc không còn tồn tại**.

Mã nguồn, tài nguyên giao diện, binary Xray cho `amd64`/`arm64`, `geoip.dat`
và `geosite.dat` đã được lưu trong chính repo này. Không cần tải bản phát hành,
script cài đặt hay Git object từ kho x-ui gốc. Ghi công và giấy phép GPLv3:
[ORIGIN.md](ORIGIN.md) và [LICENSE](LICENSE).

> **Lưu ý bảo mật:** Đây là bản x-ui 0.3.2 cũ được Việt hóa, **không phải**
> phiên bản Xray/panel hiện đại đã được audit toàn diện. Nên dùng để nghiên cứu,
> thử nghiệm. Không mở trang quản trị qua HTTP không mã hóa ra Internet;
> nên dùng SSH tunnel, HTTPS hoặc tường lửa hạn chế IP.

## Những gì độc lập và những gì tải từ ngoài

| Thành phần | Quy tắc |
| --- | --- |
| Clone repository | Chỉ cần **repo x-ui VI do bạn quản lý**; không cần upstream |
| Chạy panel | HTML, JS, bản dịch được nhúng trong Go binary; Xray và geodata lấy từ bundle |
| Cài / cập nhật | `install.sh` nhận **tarball cục bộ**, không tự tải từ `vaxilu` |
| Phát hành | Workflow của **repo này** tự build `amd64`/`arm64`, upload artifact và tạo Release trên chính repo này khi push tag `v*` |
| Build Go | Có thể tải Go modules theo `go.mod`/`go.sum` từ hệ sinh thái Go; `--offline` khi đã cache |
| GitHub Actions | Dùng các actions chính thức và Go toolchain của GitHub; không phụ thuộc repo x-ui cũ |
| Xray, geoip/geosite | Bản hiện tại đã được đưa vào repo; chủ repo có thể cập nhật thủ công khi cần |
| DNS, TLS/ACME, Telegram | Các dịch vụ mạng riêng của tính năng, chỉ cần nếu bạn sử dụng |

**Không nên vendor tất cả Go modules hoặc cả hệ điều hành vào repository:**
chúng lớn và tương đối ổn định. Repo vẫn có thể hoạt động độc lập với tác giả
x-ui nhờ phiên bản dependency được khóa trong `go.mod` và `go.sum`. Nếu muốn
build **hoàn toàn không Internet**, hãy chuẩn bị trước Go toolchain, C compiler
và cache module đầy đủ, rồi chạy `--offline`.

## Cách 1: tải bản Release từ repo của bạn rồi cài (khuyên dùng)

Sau khi push mã nguồn lên GitHub, tạo tag `v0.3.2-vi.1` để workflow build
và xuất bản ba file trong **Releases của repo riêng**:

- `x-ui-linux-amd64.tar.gz`
- `x-ui-linux-arm64.tar.gz`
- `SHA256SUMS`

Với **repo public**, trên VPS Ubuntu/Debian có Bash, `curl`, `tar`,
`sha256sum` và quyền sudo, dùng repo GitHub `hotrantien/x-ui-vi`:

```bash
curl -fsSLo install-from-github.sh \
  https://raw.githubusercontent.com/hotrantien/x-ui-vi/main/scripts/packaging/install-from-github.sh
sudo bash install-from-github.sh hotrantien/x-ui-vi
```

Lệnh trên chỉ tải **bản Release từ repo của bạn**, kiểm tra SHA-256 rồi chạy
`install.sh` nằm trong tarball đã tải. Bạn có thể chỉ định một bản cụ thể:

```bash
sudo bash install-from-github.sh hotrantien/x-ui-vi v0.3.2-vi.1
```

**Với repo private:** tải Release bằng giao diện GitHub đã đăng nhập hoặc
`gh release download` có xác thực, rồi dùng cách 2 dưới đây. Wrapper tải HTTP
không tự nhận access token, tránh rò rỉ token trong script hoặc lịch sử shell.

## Cách 2: cài đặt / nâng cấp không dùng Internet trên VPS

Tải `x-ui-linux-amd64.tar.gz` từ Release (hoặc lấy từ máy build của bạn),
chuyển đến VPS. Gói chứa `x-ui/install.sh`, có thể giải nén script cài:

```bash
tar -xOzf x-ui-linux-amd64.tar.gz x-ui/install.sh > install.sh
sudo bash install.sh ./x-ui-linux-amd64.tar.gz
```

Bạn cũng có thể chép `install.sh` trong mã nguồn cạnh tarball và chạy trực tiếp.
Script xác thực thành phần, ELF đúng kiến trúc và checksum nội bộ trước khi
thay thế chương trình. Khi cập nhật, giữ nguyên dữ liệu `/etc/x-ui/` và cấu
hình tài khoản; cố gắng phục hồi bản cũ nếu thay thế lỗi. Trường hợp cập nhật:

```bash
sudo x-ui update /root/x-ui-linux-amd64.tar.gz
```

Các bản Release là **gói cài ứng dụng**, không phải một bản sao của Ubuntu.
SQLite dùng CGO=1 nên máy nhận cần có libc Linux tương thích.

## Tự build từ GitHub repository riêng

Trên Linux native cùng kiến trúc với máy nhận, có Go, GCC/C compiler:

```bash
git clone https://github.com/hotrantien/x-ui-vi.git
cd x-ui-vi
bash scripts/packaging/build.sh --arch amd64
bash scripts/packaging/verify.sh \
  --archive dist/x-ui-linux-amd64.tar.gz --arch amd64
```

Nếu Go modules đã có trong cache, chạy `build.sh --offline` để ngăn truy cập
module proxy. Script tự thử `CREATE/INSERT/SELECT` SQLite trước khi compile
thật với `CGO_ENABLED=1`; không dùng binary CGO=0 vì driver SQLite sẽ bị stub.
Hướng dẫn đóng gói chi tiết: [scripts/packaging/README.md](scripts/packaging/README.md).

### Xuất bản bản Release trong repo của bạn

Sau khi có mã nguồn ở `main`, push tag:

```bash
git tag v0.3.2-vi.1
git push origin main
git push origin v0.3.2-vi.1
```

GitHub Actions build ở runner `amd64` và `arm64` rồi đưa tarball vào GitHub
Releases của **chính repository đang chạy workflow**. Không cần GitHub PAT của
tác giả cũ. Với `workflow_dispatch` thủ công, các gói được lưu trong Artifacts,
**chỉ push tag mới tạo Release**. Phải bật quyền GitHub Actions cho repo và
đảm bảo workflow được phép dùng `GITHUB_TOKEN` ghi Releases.

Workflow với Go 1.26 cần kiểm chứng thêm bằng một lượt chạy GitHub Actions;
bản đã kiểm thử thành công trên VPS Ubuntu 22.04 được build bằng Go 1.18.1.

## Tính năng chính

- Quản lý và giám sát Xray qua giao diện web Việt hóa.
- Các giao thức: VMess, VLESS, Trojan, Shadowsocks, SOCKS, HTTP,
  dokodemo-door (tùy tính năng của phiên bản Xray đi kèm).
- Quản lý kết nối vào, giới hạn lưu lượng, ngày hết hạn và thống kê tài nguyên.
- Cấu hình Xray, tài khoản panel, TLS và thông báo Telegram khi cấu hình riêng.

Lệnh quản trị trên máy cài: `sudo x-ui` (menu), `sudo x-ui status`, `start`,
`stop`, `restart`, `update /duong-dan/goi.tar.gz`.

## Lưu ý bảo trì lâu dài

1. Lưu ít nhất một bản Release `.tar.gz` và `SHA256SUMS` ngoài GitHub như bản
   dự phòng — GitHub vẫn là dịch vụ bên thứ ba.
2. Nâng cấp Xray và geodata theo kế hoạch, kiểm tra giấy phép và checksum, thử
   lại giao thức trước khi thay file đã được lưu trong repo.
3. Luôn backup `/etc/x-ui/` trước thay đổi lớn. Không commit cơ sở dữ liệu,
   mật khẩu quản trị, SSH key, chứng chỉ TLS, bot token vào repository.
4. Giữ nguyên giấy phép GPLv3 và tài liệu ghi công tác giả khi phân phối.

**Không có URL cài đặt/cập nhật cố định trỏ tới repository gốc**. Nếu đổi tên
account hoặc chuyển quyền sở hữu repo, dùng `OWNER/REPO` mới trong lệnh cài;
script không phụ thuộc tên tài khoản được hardcode.
