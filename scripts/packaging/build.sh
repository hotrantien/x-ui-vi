#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/../.." && pwd -P)"
# shellcheck source=common.sh
source "$script_dir/common.sh"

usage() {
    cat <<'HELP'
Biên dịch x-ui trên Linux (CGO=1) rồi đóng gói cùng Xray và các tệp địa lý có sẵn.

  bash scripts/packaging/build.sh [--offline] [--arch amd64|arm64|s390x]
      [--xray TEP] [--geoip TEP] [--geosite TEP] [--output-dir THU_MUC]

Mặc định dùng bin/xray-linux-<arch>, bin/geoip.dat, bin/geosite.dat.
Không tải Xray hoặc geodata. Go có thể tải module khi chưa cache; dùng --offline
để cấm truy cập module proxy và thất bại có chủ đích nếu thiếu cache.
Phải chạy trên Linux native có go và C compiler; không build CGO=0 trên Windows.
HELP
}

[[ "$(uname -s)" == Linux ]] || packaging_error "Phải build native trên Linux có C compiler."
packaging_require_command go
packaging_require_command tar
arch="$(packaging_arch)"
offline=0
xray_input=""
geoip_input=""
geosite_input=""
output_dir="$repo_root/dist"

while (($#)); do
    case "$1" in
        --arch) (($# >= 2)) || packaging_error "Thiếu đối số --arch"; arch="$2"; shift 2 ;;
        --xray) (($# >= 2)) || packaging_error "Thiếu đối số --xray"; xray_input="$2"; shift 2 ;;
        --geoip) (($# >= 2)) || packaging_error "Thiếu đối số --geoip"; geoip_input="$2"; shift 2 ;;
        --geosite) (($# >= 2)) || packaging_error "Thiếu đối số --geosite"; geosite_input="$2"; shift 2 ;;
        --output-dir) (($# >= 2)) || packaging_error "Thiếu đối số --output-dir"; output_dir="$2"; shift 2 ;;
        --offline) offline=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) packaging_error "Tham số không hỗ trợ: $1" ;;
    esac
done

packaging_validate_arch "$arch"
[[ "$arch" == "$(packaging_arch)" ]] \
    || packaging_error "Để có SQLite CGO đúng kiến trúc, hãy build trên Linux/$arch native."
compiler="${CC:-cc}"
packaging_require_command "$compiler"
packaging_require_command mktemp

xray_input="${xray_input:-$repo_root/bin/xray-linux-$arch}"
geoip_input="${geoip_input:-$repo_root/bin/geoip.dat}"
geosite_input="${geosite_input:-$repo_root/bin/geosite.dat}"
packaging_check_elf "$xray_input" "$arch"
packaging_require_input "$geoip_input"
packaging_require_input "$geosite_input"

work_dir="$(mktemp -d)"
trap 'rm -rf -- "$work_dir"' EXIT
printf 'Build Linux/%s với CGO_ENABLED=1...\n' "$arch"
if ((offline)); then
    (cd -- "$repo_root" && GOPROXY=off GOSUMDB=off CGO_ENABLED=1 GOOS=linux GOARCH="$arch" CC="$compiler" \
        go run -mod=readonly "$script_dir/sqlite-smoke.go")
    (cd -- "$repo_root" && GOPROXY=off GOSUMDB=off CGO_ENABLED=1 GOOS=linux GOARCH="$arch" CC="$compiler" \
        go build -mod=readonly -trimpath -o "$work_dir/x-ui" .)
else
    (cd -- "$repo_root" && CGO_ENABLED=1 GOOS=linux GOARCH="$arch" CC="$compiler" \
        go run -mod=readonly "$script_dir/sqlite-smoke.go")
    (cd -- "$repo_root" && CGO_ENABLED=1 GOOS=linux GOARCH="$arch" CC="$compiler" \
        go build -mod=readonly -trimpath -o "$work_dir/x-ui" .)
fi
packaging_check_elf "$work_dir/x-ui" "$arch"
packaging_check_go_binary "$work_dir/x-ui" "$arch"
bash "$script_dir/package.sh" --arch "$arch" --binary "$work_dir/x-ui" \
    --xray "$xray_input" --geoip "$geoip_input" --geosite "$geosite_input" \
    --output-dir "$output_dir"
