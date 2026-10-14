# Đóng gói X-UI Linux độc lập

Các script trong thư mục này tạo gói cài đặt **không cần tải Xray hoặc dữ liệu
địa lý khi triển khai**. Chúng sử dụng mã nguồn X-UI đã Việt hóa và các file
đầu vào trên máy đóng gói. Tên gói tương thích với bộ cài: `x-ui-linux-amd64.tar.gz`,
`x-ui-linux-arm64.tar.gz` hoặc `x-ui-linux-s390x.tar.gz`.

## Điều kiện build

- Máy build **Linux native** theo đúng kiến trúc đích, ví dụ Linux x86_64 để tạo
  gói amd64, Linux aarch64 để tạo gói arm64. Script không hỗ trợ CGO=0 hay
  giả định cross-build từ Windows.
- Có Go, C compiler (`cc` hoặc biến `CC`), GNU tar, `od`, `sha256sum`.
- Các Go module đã được cache nếu dùng `--offline`. Nếu không dùng tùy chọn
  này, `go build` / `go run` **có thể cần mạng để tải Go module**.
- Chuẩn bị sẵn đúng kiến trúc `bin/xray-linux-<arch>`, `bin/geoip.dat` và
  `bin/geosite.dat`. Repo hiện có file cho amd64 và arm64. Để tạo s390x,
  phải cung cấp file Xray Linux s390x riêng.

Tạo gói trên Linux amd64 với các file sẵn có:

```bash
bash scripts/packaging/build.sh --arch amd64
```

Build không truy cập Go module proxy (cần module đã cache):

```bash
bash scripts/packaging/build.sh --arch amd64 --offline
```

Dùng Xray và dữ liệu địa lý được cung cấp ở vị trí khác:

```bash
bash scripts/packaging/build.sh --arch amd64 \
  --xray /home/user/assets/xray-linux-amd64 \
  --geoip /home/user/assets/geoip.dat \
  --geosite /home/user/assets/geosite.dat \
  --output-dir /home/user/releases
```

Nếu đã có bản x-ui Linux **CGO=1** do Go build tạo, chỉ cần đóng gói:

```bash
bash scripts/packaging/package.sh --arch amd64 \
  --binary /home/user/build/x-ui
```

Kiểm tra gói trước khi chuyển sang VPS:

```bash
bash scripts/packaging/verify.sh \
  --archive dist/x-ui-linux-amd64.tar.gz --arch amd64
```

## Bên trong gói

```text
x-ui/
  x-ui
  install.sh
  x-ui.sh
  x-ui.service
  SHA256SUMS
  bin/
    xray-linux-amd64
    geoip.dat
    geosite.dat
```

Script build chạy phép thử SQLite CREATE/INSERT/SELECT trên một database tạm,
sau đó biên dịch X-UI với `CGO_ENABLED=1`. Script đóng gói xác nhận metadata
`CGO_ENABLED=1`, `GOOS=linux`, `GOARCH` và dependency go-sqlite3. Script
verify kiểm tra thành phần, SHA256, kiến trúc ELF và metadata Go (khi có Go).
Script verify không chạy x-ui hoặc Xray và không chạm vào dữ liệu máy chủ.

Gói chỉ gồm binary và dữ liệu ứng dụng; không bao gồm toàn bộ hệ điều hành.
Binary CGO có thể phụ thuộc libc/loader của hệ điều hành build. Hãy build trên
phiên bản Linux tương thích với máy nhận, kiểm tra `ldd x-ui/x-ui` trên máy
nhận nếu gặp lỗi thư viện, và bảo đảm máy chủ có thư viện C cùng chứng chỉ CA
phù hợp. Quá trình **cài đặt và cập nhật gói này không cần tải từ vaxilu**;
các chức năng khác như cấp chứng chỉ ACME hoặc tải module khi biên dịch có thể
cần mạng tùy cách sử dụng.

Gói chứa bản sao `install.sh` từ cùng working tree, cho phép bộ quản lý cập
nhật sử dụng lại script cục bộ. Dữ liệu X-UI lưu riêng trong `/etc/x-ui/`;
script đóng gói không xóa hoặc thay đổi thư mục đó.

Workflow `.github/workflows/release.yml` build native amd64/arm64 từ các
tệp trong repo và xuất GitHub Actions artifacts khi chạy thủ công. Khi push tag
`v*`, workflow còn tạo Release trên **chính GitHub repository này**, gồm
`x-ui-linux-amd64.tar.gz`, `x-ui-linux-arm64.tar.gz`, `SHA256SUMS`.
GitHub Actions có thể tải Go toolchain/module và actions chính thức, nhưng
không tải source hay release từ repo x-ui gốc. Bước đóng gói không tải Xray.

Nếu repository công khai, người dùng có thể tải và xác thực bundle bằng
`scripts/packaging/install-from-github.sh OWNER/REPO [TAG]`. Script nhận
đích GitHub repository tường minh, không dùng URL cố định của upstream.
