#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=common.sh
source "$script_dir/common.sh"

usage() {
    cat <<'HELP'
Kiểm tra layout, SHA256, ELF, Go CGO metadata (nếu có Go) của gói Linux.

  bash scripts/packaging/verify.sh --archive x-ui-linux-amd64.tar.gz --arch amd64

Không chạy dịch vụ, không cập nhật và không ghi vào /etc hoặc /usr/local.
HELP
}

archive=""
arch=""
while (($#)); do
    case "$1" in
        --archive) (($# >= 2)) || packaging_error "Thiếu đối số --archive"; archive="$2"; shift 2 ;;
        --arch) (($# >= 2)) || packaging_error "Thiếu đối số --arch"; arch="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) packaging_error "Tham số không hỗ trợ: $1" ;;
    esac
done
packaging_validate_arch "$arch"
packaging_require_input "$archive"
archive="$(cd -- "$(dirname -- "$archive")" && pwd -P)/$(basename -- "$archive")"
packaging_require_command tar
packaging_require_command sha256sum
packaging_require_command mktemp
packaging_require_command awk

work_dir="$(mktemp -d)"
trap 'rm -rf -- "$work_dir"' EXIT
list_path="$work_dir/entries.txt"
tar -tzf "$archive" > "$list_path" || packaging_error "Không đọc được archive."
# Tệp liên kết, thiết bị và FIFO không được phép nằm trong gói.
tar -tvzf "$archive" | while IFS= read -r entry; do
    case "${entry:0:1}" in
        -|d) ;;
        *) packaging_error "Archive chứa mục không phải tệp hoặc thư mục thường: $entry" ;;
    esac
done

# Chỉ nhận layout được định nghĩa; chống absolute path và path traversal khi giải nén.
while IFS= read -r entry; do
    case "$entry" in
        x-ui/|x-ui/bin/|x-ui/x-ui|x-ui/install.sh|x-ui/x-ui.sh|x-ui/x-ui.service|x-ui/SHA256SUMS|x-ui/bin/geoip.dat|x-ui/bin/geosite.dat) ;;
        "x-ui/bin/xray-linux-$arch") ;;
        *) packaging_error "Archive chứa đường dẫn ngoài danh sách: $entry" ;;
    esac
done < "$list_path"

for entry in "x-ui/x-ui" "x-ui/install.sh" "x-ui/x-ui.sh" "x-ui/x-ui.service" "x-ui/SHA256SUMS" \
    "x-ui/bin/xray-linux-$arch" "x-ui/bin/geoip.dat" "x-ui/bin/geosite.dat"; do
    [[ "$(grep -Fxc -- "$entry" "$list_path")" == 1 ]] \
        || packaging_error "Thiếu hoặc trùng mục bắt buộc: $entry"
done
tar -xzf "$archive" -C "$work_dir" --no-same-owner || packaging_error "Giải nén không thành công."

cd -- "$work_dir/x-ui"
for entry in x-ui install.sh x-ui.sh x-ui.service "bin/xray-linux-$arch" bin/geoip.dat bin/geosite.dat; do
    [[ -f "$entry" && ! -L "$entry" && -s "$entry" ]] \
        || packaging_error "Tệp không hợp lệ hoặc là symlink: $entry"
done
sha256sum --check --status SHA256SUMS || packaging_error "SHA256 không khớp."
packaging_check_elf x-ui "$arch"
packaging_check_elf "bin/xray-linux-$arch" "$arch"
# Kiểm tra quyền thực thi trong tar header, vì Windows/Git Bash có thể bỏ
# mất bit thực thi khi giải nén vào NTFS.
tar -tvzf "$archive" | awk -v binary="x-ui/bin/xray-linux-$arch" '
    ($NF == "x-ui/x-ui" || $NF == binary) {
        if (substr($1, 4, 1) == "x") valid++
    }
    END { if (valid != 2) exit 1 }
' || packaging_error "Archive thiếu quyền thực thi cho x-ui hoặc Xray."
if command -v go >/dev/null 2>&1; then
    packaging_check_go_binary x-ui "$arch"
else
    printf 'Lưu ý: Không có Go, chưa kiểm tra được metadata CGO của binary.\n' >&2
fi
printf 'PASS: archive %s có đủ thành phần, SHA256 và ELF linux/%s hợp lệ.\n' "$archive" "$arch"
