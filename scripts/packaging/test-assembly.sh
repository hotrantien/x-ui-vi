#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/../.." && pwd -P)"
source "$script_dir/common.sh"

# Test chỉ kiểm tra tar/manifest/ELF/logic xác minh. Binary thử nghiệm
# là Xray có sẵn và metadata Go là mock; tuyệt đối không dùng làm release.
if [[ "$(uname -s)" != Linux ]]; then
    printf 'SKIP: Kiểm tra quyền thực thi trong tar cần chạy trên filesystem Linux.\n'
    exit 0
fi
packaging_require_input "$repo_root/bin/xray-linux-amd64"
packaging_require_input "$repo_root/bin/geoip.dat"
packaging_require_input "$repo_root/bin/geosite.dat"
work_dir="$(mktemp -d)"
trap 'rm -rf -- "$work_dir"' EXIT
mkdir -p "$work_dir/mock-bin" "$work_dir/output" "$work_dir/corrupt"
cat > "$work_dir/mock-bin/go" <<'MOCK'
#!/usr/bin/env bash
[[ "${1:-}" == version && "${2:-}" == -m ]] || exit 2
cat <<'META'
fixture: go1.26.0
    dep github.com/mattn/go-sqlite3 v1.14.5
    build CGO_ENABLED=1
    build GOOS=linux
    build GOARCH=amd64
META
MOCK
chmod 755 "$work_dir/mock-bin/go"
export PATH="$work_dir/mock-bin:$PATH"

bash "$script_dir/package.sh" --arch amd64 \
    --binary "$repo_root/bin/xray-linux-amd64" --output-dir "$work_dir/output" \
    --xray "$repo_root/bin/xray-linux-amd64" \
    --geoip "$repo_root/bin/geoip.dat" --geosite "$repo_root/bin/geosite.dat"
archive="$work_dir/output/x-ui-linux-amd64.tar.gz"
bash "$script_dir/verify.sh" --archive "$archive" --arch amd64
tar -xzf "$archive" -C "$work_dir/corrupt"
printf '%s\n' 'tampered' >> "$work_dir/corrupt/x-ui/bin/geosite.dat"
tar -czf "$work_dir/corrupt.tar.gz" -C "$work_dir/corrupt" x-ui
if bash "$script_dir/verify.sh" --archive "$work_dir/corrupt.tar.gz" --arch amd64 >/dev/null 2>&1; then
    packaging_error "Verify không nhận ra checksum sai của fixture."
fi
printf 'PASS: đóng gói & verify cấu trúc thành công; checksum bị sửa đã bị chặn.\n'
printf 'Lưu ý: test dùng fake Go metadata, không chứng minh binary x-ui chạy SQLite.\n'
