#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
function_src="$(awk '
    /^resolve_panel_port\(\) \{$/ { inside=1 }
    inside { print }
    inside && /^\}$/ { exit }
' "$repo_root/install.sh")"
[[ "$function_src" == *'resolve_panel_port()'* ]] || {
    echo 'Không tìm thấy hàm xử lý cổng trong install.sh' >&2
    exit 1
}
eval 'log_error() { printf "%s\n" "$*" >&2; }'
eval "$function_src"

[[ "$(resolve_panel_port '')" == 54321 ]] || exit 1
[[ "$(resolve_panel_port 80)" == 80 ]] || exit 1
[[ "$(resolve_panel_port 443)" == 443 ]] || exit 1
[[ "$(resolve_panel_port 65535)" == 65535 ]] || exit 1
for invalid in 0 -1 65536 999999 abc '80/tcp' '080'; do
    if resolve_panel_port "$invalid" >/dev/null 2>&1; then
        printf 'Cổng không hợp lệ đã được chấp nhận: %s\n' "$invalid" >&2
        exit 1
    fi
done
grep -Fq 'config_port="$(resolve_panel_port "$config_port")" || return 1' \
    "$repo_root/install.sh" || exit 1
printf 'PASS: Enter dùng 54321; cổng hợp lệ được giữ, cổng sai bị chặn.\n'
