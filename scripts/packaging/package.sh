#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/../.." && pwd -P)"
# shellcheck source=common.sh
source "$script_dir/common.sh"

usage() {
    cat <<'HELP'
Đóng gói offline từ binary Linux CGO=1 và Xray/geodata đã có sẵn.

  bash scripts/packaging/package.sh --arch amd64|arm64|s390x --binary TEP
      [--xray TEP] [--geoip TEP] [--geosite TEP] [--output-dir THU_MUC]

Tạo dist/x-ui-linux-<arch>.tar.gz với thư mục gốc x-ui/.
Không thực hiện tải mạng, không build lại binary, không xóa dữ liệu máy chủ.
HELP
}

arch=""
binary=""
xray_input=""
geoip_input=""
geosite_input=""
output_dir="$repo_root/dist"

while (($#)); do
    case "$1" in
        --arch) (($# >= 2)) || packaging_error "Thiếu đối số --arch"; arch="$2"; shift 2 ;;
        --binary) (($# >= 2)) || packaging_error "Thiếu đối số --binary"; binary="$2"; shift 2 ;;
        --xray) (($# >= 2)) || packaging_error "Thiếu đối số --xray"; xray_input="$2"; shift 2 ;;
        --geoip) (($# >= 2)) || packaging_error "Thiếu đối số --geoip"; geoip_input="$2"; shift 2 ;;
        --geosite) (($# >= 2)) || packaging_error "Thiếu đối số --geosite"; geosite_input="$2"; shift 2 ;;
        --output-dir) (($# >= 2)) || packaging_error "Thiếu đối số --output-dir"; output_dir="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) packaging_error "Tham số không hỗ trợ: $1" ;;
    esac
done

packaging_validate_arch "$arch"
[[ -n "$binary" ]] || packaging_error "Thiếu --binary (đường dẫn x-ui ELF Linux CGO=1)."
packaging_require_command tar
packaging_require_command sha256sum
packaging_require_command mktemp
packaging_require_command sed
xray_input="${xray_input:-$repo_root/bin/xray-linux-$arch}"
geoip_input="${geoip_input:-$repo_root/bin/geoip.dat}"
geosite_input="${geosite_input:-$repo_root/bin/geosite.dat}"
packaging_check_elf "$binary" "$arch"
packaging_check_go_binary "$binary" "$arch"
packaging_check_elf "$xray_input" "$arch"
for input in "$geoip_input" "$geosite_input" "$repo_root/install.sh" "$repo_root/x-ui.sh" "$repo_root/x-ui.service"; do
    packaging_require_input "$input"
done

mkdir -p -- "$output_dir"
output_dir="$(cd -- "$output_dir" && pwd -P)"
output="$output_dir/x-ui-linux-$arch.tar.gz"
[[ ! -e "$output" ]] || packaging_error "Tệp đã tồn tại, không tự ghi đè: $output"

work_dir="$(mktemp -d)"
trap 'rm -rf -- "$work_dir"' EXIT
mkdir -p -- "$work_dir/x-ui/bin"
cp -- "$binary" "$work_dir/x-ui/x-ui"
cp -- "$repo_root/install.sh" "$work_dir/x-ui/install.sh"
cp -- "$repo_root/x-ui.sh" "$work_dir/x-ui/x-ui.sh"
cp -- "$repo_root/x-ui.service" "$work_dir/x-ui/x-ui.service"
cp -- "$xray_input" "$work_dir/x-ui/bin/xray-linux-$arch"
cp -- "$geoip_input" "$work_dir/x-ui/bin/geoip.dat"
cp -- "$geosite_input" "$work_dir/x-ui/bin/geosite.dat"
# Bản checkout được chuẩn bị trên Windows có thể chứa CRLF. Chuẩn hóa
# hai script trong bundle mà không thay đổi nguồn trong repository.
sed -i 's/\r$//' "$work_dir/x-ui/install.sh" "$work_dir/x-ui/x-ui.sh"
chmod 755 "$work_dir/x-ui/x-ui" "$work_dir/x-ui/install.sh" "$work_dir/x-ui/x-ui.sh" "$work_dir/x-ui/bin/xray-linux-$arch"
chmod 644 "$work_dir/x-ui/x-ui.service" "$work_dir/x-ui/bin/geoip.dat" "$work_dir/x-ui/bin/geosite.dat"

(
    cd -- "$work_dir/x-ui"
    sha256sum x-ui install.sh x-ui.sh x-ui.service "bin/xray-linux-$arch" bin/geoip.dat bin/geosite.dat > SHA256SUMS
)
tar -czf "$output" -C "$work_dir" x-ui
if ! bash "$script_dir/verify.sh" --archive "$output" --arch "$arch"; then
    rm -f -- "$output"
    packaging_error "Gói vừa tạo không vượt qua kiểm tra."
fi
printf 'Đã tạo gói triển khai offline: %s\n' "$output"
