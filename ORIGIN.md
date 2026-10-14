# Nguồn gốc và giấy phép

Đây là phiên bản **x-ui VI** được Việt hóa, đóng gói và bảo trì riêng. Mã nguồn
ban đầu dựa trên dự án **x-ui** của tác giả **vaxilu**, bản snapshot có mã commit
`9c1be8c57a53953b47ee7c09a93554e73816f907` (phiên bản cũ 0.3.2).

- Tác giả của mã nguồn gốc: vaxilu và những người đã đóng góp cho x-ui.
- Giấy phép được giữ lại: **GNU General Public License v3**, xem `LICENSE`.
- Phiên bản Việt hóa bổ sung dịch giao diện/CLI, điều chỉnh runtime, kiểm thử,
  cách cài đặt từ bundle cục bộ, các script build và phát hành riêng.

Lịch sử Git của repository mới bắt đầu từ snapshot mã nguồn đầy đủ này để có
thể clone, build, sửa chữa và phát hành mà **không cần Git remote hoặc Git
object từ kho của tác giả gốc**. Việc giữ thông tin ghi công và giấy phép
không tạo ra phụ thuộc mạng tới repository gốc.

Các thành phần bên thứ ba (Go modules, Xray Core, Ant Design Vue, Vue.js,
Moment.js...) tiếp tục thuộc về các chủ sở hữu và giấy phép tương ứng.
Thông tin và danh sách phụ thuộc Go có trong `go.mod`/`go.sum`; gói cài đặt
Linux dùng Xray và geoip/geosite đã có sẵn trong chính repository này.
