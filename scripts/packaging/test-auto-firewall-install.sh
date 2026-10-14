#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
installer="$repo_root/install.sh"
manager="$repo_root/x-ui.sh"

# Bản cài mới phải gọi chức năng mở 3 cổng sau khi service đã được khởi động.
# Không gọi chức năng này khi xử lý bản đã cài.
awk '
    /committed=1/ { after_commit=1 }
    after_commit && /if \(\( old_install \)\); then/ { after_branch=1; next }
    after_branch && /^    else$/ { fresh_install=1; next }
    fresh_install && /bash \/usr\/local\/x-ui\/x-ui.sh open-port;/ {
        found_default=1
    }
    fresh_install && /bash \/usr\/local\/x-ui\/x-ui.sh open-port "\$panel_port" tcp;/ {
        found_custom=1
    }
    fresh_install && /^    fi$/ { exit }
    END {
        if (!after_commit || !found_default || !found_custom) exit 1
    }
' "$installer"

grep -Fq 'local panel_port=54321' "$installer"
grep -Fq 'panel_port="$config_port"' "$installer"
grep -Fq 'if [[ "$panel_port" != 54321 ]]; then' "$installer"
grep -Fq 'if [[ $# -eq 1 ]]; then' "$manager"
grep -Fq 'open_default_firewall_ports' "$manager"

if grep -Eq 'iptables -F|iptables --flush' "$installer" "$manager"; then
    echo 'Tìm thấy lệnh xóa firewall không an toàn' >&2
    exit 1
fi
printf 'PASS: sau cài mới tự mở TCP 54321,80,443 và cổng web khác nếu có.\n'
