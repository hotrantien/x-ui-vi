#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Lỗi:${plain} Bạn phải chạy script này bằng quyền root!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}Không xác định được phiên bản hệ điều hành. Vui lòng liên hệ tác giả script!${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    echo -e "${red}Kiến trúc CPU không được hỗ trợ: ${arch}${plain}" >&2
    exit 1
fi

echo "Kiến trúc: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "Phần mềm không hỗ trợ hệ điều hành 32 bit (x86). Hãy dùng hệ điều hành 64 bit (x86_64). Nếu phát hiện sai, vui lòng liên hệ tác giả."
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Vui lòng sử dụng CentOS 7 trở lên!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Vui lòng sử dụng Ubuntu 16 trở lên!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Vui lòng sử dụng Debian 8 trở lên!${plain}\n" && exit 1
    fi
fi

log_error() {
    echo -e "${red}Lỗi: $*${plain}" >&2
}

resolve_panel_port() {
    local selected="${1:-54321}"
    if [[ ! "$selected" =~ ^[1-9][0-9]{0,4}$ ]] || (( selected > 65535 )); then
        log_error "Cổng không hợp lệ: $selected (chỉ chấp nhận số từ 1 đến 65535)."
        return 1
    fi
    printf '%s\n' "$selected"
}

# Chỉ yêu cầu cấu hình tài khoản khi cài đặt mới.
config_after_install() {
    echo -e "${yellow}Để đảm bảo an toàn, hãy đổi cổng truy cập và mật khẩu sau khi cài đặt.${plain}"
    read -p "Bạn có muốn tiếp tục không? [y/n]: " config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "Nhập tên tài khoản: " config_account
        echo -e "${yellow}Tên tài khoản sẽ được đặt thành: ${config_account}${plain}"
        read -r -s -p "Nhập mật khẩu tài khoản: " config_password
        echo
        read -r -p "Nhập cổng truy cập bảng điều khiển [54321]: " config_port || return 1
        config_port="$(resolve_panel_port "$config_port")" || return 1
        echo -e "${yellow}Cổng truy cập bảng điều khiển sẽ là: ${config_port}${plain}"
        echo -e "${yellow}Đã xác nhận, đang lưu cài đặt...${plain}"
        /usr/local/x-ui/x-ui setting -username "${config_account}" -password "${config_password}" || return 1
        echo -e "${yellow}Đã đặt tên tài khoản và mật khẩu${plain}"
        /usr/local/x-ui/x-ui setting -port "${config_port}" || return 1
        echo -e "${yellow}Đã đặt cổng bảng điều khiển${plain}"
    else
        echo -e "${red}Đã hủy. Các thiết lập vẫn giữ giá trị mặc định, vui lòng thay đổi sớm!${plain}"
    fi
}

install_x-ui() {
    archive="${1:-${script_dir}/x-ui-linux-${arch}.tar.gz}"
    stage_dir=""
    old_install=0 old_cli=0 old_unit=0 was_running=0 moved_old=0
    started_change=0 deployed=0 committed=0

    if [[ ! -f "$archive" || ! -r "$archive" ]]; then
        log_error "Không tìm thấy gói cục bộ: $archive"
        log_error "Đặt x-ui-linux-${arch}.tar.gz cạnh install.sh hoặc chạy: bash install.sh /đường/dẫn/x-ui-linux-${arch}.tar.gz"
        return 1
    fi

    for requirement in tar mktemp mv cp chmod systemctl sha256sum od awk tr grep; do
        if ! command -v "$requirement" >/dev/null 2>&1; then
            log_error "Thiếu lệnh $requirement. Hãy cài sẵn công cụ này từ nguồn nội bộ."
            return 1
        fi
    done

    stage_dir=$(mktemp -d /usr/local/.x-ui-stage.XXXXXXXX) || {
        log_error "Không tạo được thư mục tạm trong /usr/local"
        return 1
    }

    rollback_and_cleanup() {
        local rc=$?
        local restore_failed=0
        trap - EXIT INT TERM
        if (( ! committed && started_change )); then
            log_error "Cài đặt chưa thành công. Đang khôi phục phiên bản trước..."
            if (( deployed )); then
                rm -rf -- /usr/local/x-ui || restore_failed=1
            fi
            if (( moved_old )); then
                mv -- "$stage_dir/previous-x-ui" /usr/local/x-ui || restore_failed=1
            fi
            rm -f -- /usr/bin/x-ui || restore_failed=1
            if (( old_cli )); then
                cp -a -- "$stage_dir/previous-cli" /usr/bin/x-ui || restore_failed=1
            fi
            if (( ! old_install )); then systemctl disable x-ui >/dev/null 2>&1; fi
            rm -f -- /etc/systemd/system/x-ui.service || restore_failed=1
            if (( old_unit )); then
                cp -a -- "$stage_dir/previous-unit" /etc/systemd/system/x-ui.service || restore_failed=1
            fi
            systemctl daemon-reload || restore_failed=1
            if (( was_running )); then
                systemctl start x-ui || restore_failed=1
            fi
        fi
        if (( restore_failed == 0 )); then
            rm -rf -- "$stage_dir"
        else
            log_error "Không thể khôi phục hoàn toàn; giữ bản dự phòng tại $stage_dir"
        fi
        exit "$rc"
    }
    trap rollback_and_cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM

    if ! tar -tzf "$archive" > "$stage_dir/files.txt"; then
        log_error "Gói nén không hợp lệ: $archive"
        return 1
    fi
    if [[ ! -s "$stage_dir/files.txt" ]]; then
        log_error "Gói nén rỗng: $archive"
        return 1
    fi
    while IFS= read -r entry; do
        entry="${entry#./}"
        if [[ "$entry" != "x-ui" && "$entry" != x-ui/* ]] || [[ "/$entry/" == *"/../"* || "/$entry/" == *"/./"* ]]; then
            log_error "Gói chứa đường dẫn không an toàn: $entry"
            return 1
        fi
    done < "$stage_dir/files.txt"
    if tar -tvzf "$archive" | grep -Eq '^[lh]'; then
        log_error "Gói chứa liên kết cứng hoặc liên kết tượng trưng; chỉ nhận tệp và thư mục thường"
        return 1
    fi
    if ! tar -xzf "$archive" -C "$stage_dir"; then
        log_error "Không giải nén được gói: $archive"
        return 1
    fi
    for source_file in x-ui x-ui.sh install.sh x-ui.service "bin/xray-linux-${arch}" bin/geoip.dat bin/geosite.dat SHA256SUMS; do
        if [[ ! -f "$stage_dir/x-ui/$source_file" || -L "$stage_dir/x-ui/$source_file" ]]; then
            log_error "Thiếu tệp bắt buộc x-ui/$source_file trong gói cục bộ"
            return 1
        fi
    done
    if [[ ! -s "$stage_dir/x-ui/x-ui" || ! -s "$stage_dir/x-ui/bin/xray-linux-${arch}" ]]; then
        log_error "Gói thiếu chương trình x-ui hoặc Xray hợp lệ cho kiến trúc ${arch}"
        return 1
    fi

    if ! awk '
        {
            hash = substr($0, 1, 64)
            separator = substr($0, 65, 2)
            name = substr($0, 67)
            if (length(hash) != 64 || hash ~ /[^0-9a-fA-F]/ || (separator != "  " && separator != " *") || name == "" || name ~ /^\// || name ~ /(^|\/)\.\.?(\/|$)/ || name ~ /\\/) exit 1
        }
    ' "$stage_dir/x-ui/SHA256SUMS"; then
        log_error "Manifest SHA256SUMS không hợp lệ hoặc chứa đường dẫn không an toàn"
        return 1
    fi
    for source_file in x-ui x-ui.sh install.sh x-ui.service "bin/xray-linux-${arch}" bin/geoip.dat bin/geosite.dat; do
        if ! awk -v target="$source_file" '{ name = substr($0,67); if (name == target || name == "./" target) found=1 } END { exit !found }' "$stage_dir/x-ui/SHA256SUMS"; then
            log_error "SHA256SUMS không chứa tệp bắt buộc: $source_file"
            return 1
        fi
    done
    if ! (cd "$stage_dir/x-ui" && sha256sum -c --status SHA256SUMS); then
        log_error "Xác thực SHA-256 thất bại; gói có thể bị hỏng hoặc bị sửa đổi"
        return 1
    fi

    for source_file in "$stage_dir/x-ui/x-ui" "$stage_dir/x-ui/bin/xray-linux-${arch}"; do
        read -r -a elf_bytes <<< "$(od -An -tu1 -N20 "$source_file" | tr '\n' ' ')"
        if [[ "${elf_bytes[0]:-}" != 127 || "${elf_bytes[1]:-}" != 69 || "${elf_bytes[2]:-}" != 76 || "${elf_bytes[3]:-}" != 70 || "${elf_bytes[4]:-}" != 2 ]]; then
            log_error "Tệp thực thi không phải ELF 64 bit: $source_file"
            return 1
        fi
        case "$arch" in
            amd64) expected_machine="62 0 1" ;;
            arm64) expected_machine="183 0 1" ;;
            s390x) expected_machine="0 22 2" ;;
        esac
        if [[ "${elf_bytes[18]:-} ${elf_bytes[19]:-} ${elf_bytes[5]:-}" != "$expected_machine" ]]; then
            log_error "Kiến trúc ELF không khớp với máy chủ: $source_file"
            return 1
        fi
    done
    chmod +x "$stage_dir/x-ui/x-ui" "$stage_dir/x-ui/x-ui.sh" "$stage_dir/x-ui/install.sh" "$stage_dir/x-ui/bin/xray-linux-${arch}" || return 1

    if [[ -e /usr/local/x-ui && ! -d /usr/local/x-ui ]]; then
        log_error "/usr/local/x-ui đã tồn tại nhưng không phải thư mục"
        return 1
    fi
    if [[ -d /usr/local/x-ui ]]; then
        old_install=1
    fi
    if [[ -e /usr/bin/x-ui ]]; then
        cp -a -- /usr/bin/x-ui "$stage_dir/previous-cli" || return 1
        old_cli=1
    fi
    if [[ -e /etc/systemd/system/x-ui.service ]]; then
        cp -a -- /etc/systemd/system/x-ui.service "$stage_dir/previous-unit" || return 1
        old_unit=1
    fi
    if systemctl is-active --quiet x-ui; then was_running=1; fi
    echo -e "${yellow}Đang cài đặt từ gói cục bộ: $archive${plain}"
    started_change=1
    if (( was_running )); then systemctl stop x-ui || return 1; fi
    if (( old_install )); then
        mv -- /usr/local/x-ui "$stage_dir/previous-x-ui" || return 1
        moved_old=1
    fi
    mv -- "$stage_dir/x-ui" /usr/local/x-ui || return 1
    deployed=1
    rm -f -- /usr/bin/x-ui || return 1
    cp -- /usr/local/x-ui/x-ui.sh /usr/bin/x-ui || return 1
    chmod +x /usr/bin/x-ui || return 1
    rm -f -- /etc/systemd/system/x-ui.service || return 1
    cp -- /usr/local/x-ui/x-ui.service /etc/systemd/system/x-ui.service || return 1
    systemctl daemon-reload || return 1
    if (( ! old_install )); then
        config_after_install || return 1
        systemctl enable x-ui || return 1
    fi
    if (( was_running || ! old_install )); then systemctl start x-ui || return 1; fi
    committed=1

    if (( old_install )); then
        echo -e "${green}Đã cập nhật x-ui. Giữ nguyên dữ liệu /etc/x-ui và chứng chỉ ngoài thư mục ứng dụng.${plain}"
    else
        echo -e "${green}Đã cài đặt mới x-ui.${plain}"
    fi
    if (( old_install )); then
        if (( ! was_running )); then
            echo -e "${yellow}Dịch vụ đang dừng trước khi cập nhật, nên vẫn giữ trạng thái dừng.${plain}"
        fi
    fi
    echo -e "${green}Đã cài đặt x-ui từ gói cục bộ.${plain}"
    echo -e ""
    echo -e "Cách sử dụng script quản lý x-ui: "
    echo -e "----------------------------------------------"
    echo -e "x-ui              - Hiển thị menu quản lý (đầy đủ tính năng)"
    echo -e "x-ui start        - Khởi động bảng điều khiển x-ui"
    echo -e "x-ui stop         - Dừng bảng điều khiển x-ui"
    echo -e "x-ui restart      - Khởi động lại bảng điều khiển x-ui"
    echo -e "x-ui status       - Xem trạng thái x-ui"
    echo -e "x-ui enable       - Bật tự khởi động x-ui cùng hệ thống"
    echo -e "x-ui disable      - Tắt tự khởi động x-ui cùng hệ thống"
    echo -e "x-ui log          - Xem nhật ký x-ui"
    echo -e "x-ui v2-ui        - Chuyển dữ liệu tài khoản v2-ui sang x-ui trên máy này"
    echo -e "x-ui open-port    - Mở cổng firewall Ubuntu (TCP/UDP)"
    echo -e "x-ui install      - Cài đặt bảng điều khiển x-ui"
    echo -e "x-ui uninstall    - Gỡ cài đặt bảng điều khiển x-ui"
    echo -e "----------------------------------------------"
}

if [[ $# -gt 1 ]]; then
    log_error "Cú pháp: bash install.sh [đường/dẫn/x-ui-linux-${arch}.tar.gz]"
    exit 1
fi
echo -e "${green}Bắt đầu cài đặt từ tệp cục bộ${plain}"
install_x-ui "${1:-}"
