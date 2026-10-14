#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
work_dir="$(mktemp -d)"
trap 'rm -rf -- "$work_dir"' EXIT

awk '
    /^valid_firewall_port\(\) \{$/ { inside=1 }
    /^uninstall\(\) \{$/ { inside=0 }
    inside { print }
' "$repo_root/x-ui.sh" > "$work_dir/functions.sh"

grep -Fq 'open_firewall_port()' "$work_dir/functions.sh"
source "$work_dir/functions.sh"

LOGI() { :; }
LOGE() { :; }

declare -A rules=()
declare -i insert_calls=0
declare -i save_calls=0
persistence_error=0
iptables() {
    local action="$1"
    shift
    local key
    case "$action" in
    -C)
        key="$*"
        [[ "${rules[$key]:-}" == 1 ]]
        ;;
    -I)
        [[ "$1" == INPUT && "$2" == 1 ]]
        key="$1 ${*:3}"
        rules["$key"]=1
        ((++insert_calls))
        ;;
    *)
        echo "Gọi iptables không mong đợi: $action" >&2
        return 1
        ;;
    esac
}
netfilter-persistent() {
    [[ "$1" == save ]]
    ((++save_calls))
    [[ "$persistence_error" == 0 ]]
}

open_firewall_port 80 tcp
[[ "$insert_calls" == 1 && "$save_calls" == 1 ]]
[[ "${rules[INPUT -p tcp --dport 80 -j ACCEPT]:-}" == 1 ]]

open_firewall_port 80 tcp
[[ "$insert_calls" == 1 && "$save_calls" == 1 ]]

open_firewall_port 443 both
[[ "$insert_calls" == 3 && "$save_calls" == 2 ]]
[[ "${rules[INPUT -p tcp --dport 443 -j ACCEPT]:-}" == 1 ]]
[[ "${rules[INPUT -p udp --dport 443 -j ACCEPT]:-}" == 1 ]]

open_firewall_port <<< $'54321\n\n'
[[ "$insert_calls" == 4 && "$save_calls" == 3 ]]
[[ "${rules[INPUT -p tcp --dport 54321 -j ACCEPT]:-}" == 1 ]]

for invalid in 0 -1 65536 999999 abc 01 '80/tcp'; do
    if open_firewall_port "$invalid" tcp >/dev/null 2>&1; then
        echo "Cổng không hợp lệ được chấp nhận: $invalid" >&2
        exit 1
    fi
done
if open_firewall_port 9000 unsupported >/dev/null 2>&1; then
    echo 'Giao thức không hợp lệ được chấp nhận' >&2
    exit 1
fi
[[ "$insert_calls" == 4 && "$save_calls" == 3 ]]

persistence_error=1
if open_firewall_port 9001 tcp >/dev/null 2>&1; then
    echo 'Báo thành công khi lưu firewall thất bại' >&2
    exit 1
fi
[[ "$insert_calls" == 5 && "$save_calls" == 4 ]]
[[ "${rules[INPUT -p tcp --dport 9001 -j ACCEPT]:-}" == 1 ]]

if grep -Eq 'Cập nhật x-ui|Cập nhật bảng điều khiển|x-ui update|check_install && update' "$repo_root/x-ui.sh"; then
    echo 'Menu vẫn còn tùy chọn cập nhật' >&2
    exit 1
fi
grep -Fq '2.${plain} Mở cổng firewall (TCP/UDP)' "$repo_root/x-ui.sh"
grep -Fq '"open-port")' "$repo_root/x-ui.sh"
echo 'PASS: mở cổng TCP/UDP, không trùng, lưu luật, xử lý lỗi và bỏ menu cập nhật.'
