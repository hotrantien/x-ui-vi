#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

#Add some basic function here
function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}
# check root
[[ $EUID -ne 0 ]] && LOGE "Lỗi: Bạn phải chạy script này bằng quyền root!\n" && exit 1

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
    LOGE "Không xác định được phiên bản hệ điều hành. Vui lòng liên hệ tác giả script!\n" && exit 1
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
        LOGE "Vui lòng sử dụng CentOS 7 trở lên!\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        LOGE "Vui lòng sử dụng Ubuntu 16 trở lên!\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        LOGE "Vui lòng sử dụng Debian 8 trở lên!\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [mặc định: $2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Bạn có muốn khởi động lại bảng điều khiển? Xray cũng sẽ khởi động lại." "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Nhấn Enter để trở về menu chính: ${plain}" && read temp
    show_menu
}

run_local_installer() {
    local installer="/usr/local/x-ui/install.sh"
    local script_dir
    if [[ ! -f "$installer" ]]; then
        script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
        installer="$script_dir/install.sh"
    fi
    if [[ ! -f "$installer" ]]; then
        LOGE "Không tìm thấy install.sh cục bộ. Hãy đặt install.sh cạnh x-ui.sh hoặc chạy bash install.sh từ bộ cài."
        return 1
    fi
    bash "$installer" "${1:-}"
}

install() {
    local archive="${2:-}"
    if run_local_installer "$archive"; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    else
        LOGE "Cài đặt thất bại. Phiên bản hiện có đã được giữ lại nếu có thể."
        return 1
    fi
}

valid_firewall_port() {
    local port="${1:-}"
    [[ "$port" =~ ^[1-9][0-9]{0,4}$ ]] && (( port <= 65535 ))
}

open_firewall_port() {
    local port="${1:-}"
    local protocol="${2:-}"
    local rule_protocol
    local protocols=()
    local changed=0

    if [[ -z "$port" ]]; then
        read -r -p "Nhập cổng cần mở [1-65535]: " port || return 1
    fi
    if ! valid_firewall_port "$port"; then
        LOGE "Cổng không hợp lệ: $port. Chỉ chấp nhận số từ 1 đến 65535."
        return 1
    fi

    if [[ -z "$protocol" ]]; then
        read -r -p "Giao thức [tcp/udp/both, mặc định tcp]: " protocol || return 1
    fi
    protocol="${protocol,,}"
    protocol="${protocol:-tcp}"
    case "$protocol" in
    tcp|udp) protocols=("$protocol") ;;
    both) protocols=(tcp udp) ;;
    *) LOGE "Giao thức không hợp lệ; chỉ chọn tcp, udp hoặc both."; return 1 ;;
    esac

    if ! command -v iptables >/dev/null 2>&1; then
        LOGE "Không tìm thấy iptables. Không thể mở cổng."
        return 1
    fi

    for rule_protocol in "${protocols[@]}"; do
        if iptables -C INPUT -p "$rule_protocol" --dport "$port" -j ACCEPT 2>/dev/null; then
            LOGI "Đã có luật cho phép ${rule_protocol^^} $port."
        else
            if ! iptables -I INPUT 1 -p "$rule_protocol" --dport "$port" -j ACCEPT; then
                LOGE "Không thể thêm luật ${rule_protocol^^} $port."
                return 1
            fi
            changed=1
            LOGI "Đã mở cổng ${rule_protocol^^} $port trên firewall Ubuntu."
        fi
    done

    if (( changed )); then
        if command -v netfilter-persistent >/dev/null 2>&1; then
            if netfilter-persistent save; then
                LOGI "Đã lưu luật firewall để dùng sau khi VPS khởi động lại."
            else
                LOGE "Đã thêm luật hiện tại nhưng không lưu được. Kiểm tra netfilter-persistent."
                return 1
            fi
        else
            LOGE "Luật đã mở nhưng chưa được lưu lâu dài (thiếu netfilter-persistent)."
            LOGI "Trên Ubuntu có thể cài iptables-persistent rồi chạy: sudo netfilter-persistent save"
        fi
    fi
    LOGI "Lưu ý: Oracle Cloud Security List/NSG phải được cho phép riêng trên web OCI."
}

open_default_firewall_ports() {
    local port
    local failures=0
    LOGI "Đang tự mở TCP 54321, 80 và 443 trên firewall Ubuntu..."
    for port in 54321 80 443; do
        if ! open_firewall_port "$port" tcp; then
            ((++failures))
        fi
    done
    if (( failures )); then
        LOGE "Không thể hoàn tất mở $failures cổng. Kiểm tra iptables và netfilter-persistent."
        return 1
    fi
    LOGI "Đã xử lý các cổng mặc định TCP 54321, 80, 443."
}

uninstall() {
    confirm "Bạn có chắc muốn gỡ bảng điều khiển? Xray cũng sẽ bị gỡ." "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop x-ui
    systemctl disable x-ui
    rm /etc/systemd/system/x-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /usr/local/x-ui/ -rf

    echo ""
    echo -e "Đã gỡ ứng dụng. Dữ liệu /etc/x-ui vẫn được giữ lại. Để xóa cả script này, hãy thoát rồi chạy ${green}rm /usr/bin/x-ui -f${plain}"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

reset_user() {
    confirm "Bạn có chắc muốn đặt lại tên tài khoản và mật khẩu thành admin?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -username admin -password admin
    echo -e "Đã đặt lại tên tài khoản và mật khẩu thành ${green}admin${plain}. Hãy khởi động lại bảng điều khiển."
    confirm_restart
}

reset_config() {
    confirm "Bạn có chắc muốn khôi phục toàn bộ cài đặt bảng điều khiển? Dữ liệu tài khoản, tên đăng nhập và mật khẩu sẽ được giữ nguyên." "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -reset
    echo -e "Đã khôi phục cài đặt mặc định. Hãy khởi động lại bảng điều khiển và truy cập qua cổng mặc định ${green}54321${plain}."
    confirm_restart
}

check_config() {
    info=$(/usr/local/x-ui/x-ui setting -show true)
    if [[ $? != 0 ]]; then
        LOGE "Không lấy được cài đặt hiện tại. Vui lòng kiểm tra nhật ký."
        show_menu
    fi
    LOGI "${info}"
}

set_port() {
    echo && echo -n -e "Nhập cổng [1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        LOGD "Đã hủy"
        before_show_menu
    else
        /usr/local/x-ui/x-ui setting -port ${port}
        echo -e "Đã đặt cổng. Hãy khởi động lại bảng điều khiển và truy cập qua cổng mới ${green}${port}${plain}."
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        LOGI "Bảng điều khiển đang chạy. Nếu muốn chạy lại, hãy chọn khởi động lại."
    else
        systemctl start x-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            LOGI "Đã khởi động x-ui thành công"
        else
            LOGE "Không thể xác nhận bảng điều khiển đã khởi động, có thể do mất hơn 2 giây. Hãy kiểm tra nhật ký sau."
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        LOGI "Bảng điều khiển đã dừng"
    else
        systemctl stop x-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            LOGI "Đã dừng x-ui và Xray thành công"
        else
            LOGE "Không thể xác nhận bảng điều khiển đã dừng, có thể do mất hơn 2 giây. Hãy kiểm tra nhật ký sau."
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart x-ui
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        LOGI "Đã khởi động lại x-ui và Xray thành công"
    else
        LOGE "Không thể xác nhận bảng điều khiển đã khởi động lại, có thể do mất hơn 2 giây. Hãy kiểm tra nhật ký sau."
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status x-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable x-ui
    if [[ $? == 0 ]]; then
        LOGI "Đã bật tự khởi động x-ui cùng hệ thống"
    else
        LOGE "Không bật được tự khởi động x-ui cùng hệ thống"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable x-ui
    if [[ $? == 0 ]]; then
        LOGI "Đã tắt tự khởi động x-ui cùng hệ thống"
    else
        LOGE "Không tắt được tự khởi động x-ui cùng hệ thống"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u x-ui.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

migrate_v2_ui() {
    /usr/local/x-ui/x-ui v2-ui

    before_show_menu
}

install_bbr() {
    LOGI "Việc cài đặt BBR cần được quản lý bằng công cụ hệ điều hành. Bản ngoại tuyến không tự tải hoặc chạy script từ Internet."
    echo ""
    before_show_menu
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/x-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status x-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled x-ui)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        LOGE "Bảng điều khiển đã được cài đặt, không cần cài lại"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        LOGE "Vui lòng cài đặt bảng điều khiển trước"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
    0)
        echo -e "Trạng thái bảng điều khiển: ${green}Đang chạy${plain}"
        show_enable_status
        ;;
    1)
        echo -e "Trạng thái bảng điều khiển: ${yellow}Đã dừng${plain}"
        show_enable_status
        ;;
    2)
        echo -e "Trạng thái bảng điều khiển: ${red}Chưa cài đặt${plain}"
        ;;
    esac
    show_xray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Tự khởi động cùng hệ thống: ${green}Có${plain}"
    else
        echo -e "Tự khởi động cùng hệ thống: ${red}Không${plain}"
    fi
}

check_xray_status() {
    count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_xray_status() {
    check_xray_status
    if [[ $? == 0 ]]; then
        echo -e "Trạng thái Xray: ${green}Đang chạy${plain}"
    else
        echo -e "Trạng thái Xray: ${red}Đã dừng${plain}"
    fi
}

ssl_cert_issue() {
    echo -E ""
    LOGD "******Hướng dẫn sử dụng******"
    LOGI "Script dùng acme.sh để cấp chứng chỉ SSL. Bạn cần đảm bảo:"
    LOGI "1. Biết email đăng ký Cloudflare"
    LOGI "2. Có Cloudflare Global API Key"
    LOGI "3. Tên miền đã trỏ qua Cloudflare về máy chủ này"
    LOGI "4. Chứng chỉ được lưu mặc định tại /root/cert"
    confirm "Tôi xác nhận các điều kiện trên" "y"
    if [ $? -eq 0 ]; then
        cd ~
        if [[ ! -x "$HOME/.acme.sh/acme.sh" ]]; then
            LOGE "Chưa có acme.sh cục bộ tại $HOME/.acme.sh/acme.sh. Hãy cài sẵn acme.sh rồi chạy lại."
            return 1
        fi
        CF_Domain=""
        CF_GlobalKey=""
        CF_AccountEmail=""
        certPath=/root/cert
        mkdir -p -- "$certPath" || return 1
        LOGD "Nhập tên miền:"
        read -p "Tên miền: " CF_Domain
        LOGD "Tên miền đã nhập: ${CF_Domain}"
        LOGD "Nhập API Key:"
        read -r -s -p "API Key: " CF_GlobalKey
        echo
        LOGD "Nhập email đăng ký:"
        read -p "Email: " CF_AccountEmail
        LOGD "Email đã nhập: ${CF_AccountEmail}"
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
        if [ $? -ne 0 ]; then
            LOGE "Không chuyển được CA mặc định sang Let's Encrypt. Thoát script."
            exit 1
        fi
        export CF_Key="${CF_GlobalKey}"
        export CF_Email=${CF_AccountEmail}
        ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${CF_Domain} -d *.${CF_Domain} --log
        if [ $? -ne 0 ]; then
            LOGE "Không cấp được chứng chỉ. Thoát script."
            exit 1
        else
            LOGI "Đã cấp chứng chỉ thành công, đang cài đặt..."
        fi
        ~/.acme.sh/acme.sh --installcert -d ${CF_Domain} -d *.${CF_Domain} --ca-file /root/cert/ca.cer \
        --cert-file /root/cert/${CF_Domain}.cer --key-file /root/cert/${CF_Domain}.key \
        --fullchain-file /root/cert/fullchain.cer
        if [ $? -ne 0 ]; then
            LOGE "Không cài đặt được chứng chỉ. Thoát script."
            exit 1
        else
            LOGI "Đã cài đặt chứng chỉ. Lịch gia hạn và cập nhật acme.sh cần được quản lý riêng."
        fi
        ls -lah cert
        chmod 755 "$certPath"
    else
        show_menu
    fi
}

show_usage() {
    echo "Cách sử dụng script quản lý x-ui: "
    echo "------------------------------------------"
    echo "x-ui              - Hiển thị menu quản lý (đầy đủ tính năng)"
    echo "x-ui start        - Khởi động bảng điều khiển x-ui"
    echo "x-ui stop         - Dừng bảng điều khiển x-ui"
    echo "x-ui restart      - Khởi động lại bảng điều khiển x-ui"
    echo "x-ui status       - Xem trạng thái x-ui"
    echo "x-ui enable       - Bật tự khởi động x-ui cùng hệ thống"
    echo "x-ui disable      - Tắt tự khởi động x-ui cùng hệ thống"
    echo "x-ui log          - Xem nhật ký x-ui"
    echo "x-ui v2-ui        - Chuyển dữ liệu tài khoản v2-ui sang x-ui trên máy này"
    echo "x-ui open-port             - Mở sẵn TCP 54321, 80, 443"
    echo "x-ui open-port [cổng] [tcp|udp|both] - Mở thêm cổng riêng"
    echo "x-ui install [gói] - Cài đặt bảng điều khiển từ gói .tar.gz cục bộ"
    echo "x-ui uninstall    - Gỡ cài đặt bảng điều khiển x-ui"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}Script quản lý bảng điều khiển x-ui${plain}
  ${green}0.${plain} Thoát
————————————————
  ${green}1.${plain} Cài đặt x-ui
  ${green}2.${plain} Mở mặc định TCP 54321, 80, 443
  ${green}3.${plain} Gỡ cài đặt x-ui
————————————————
  ${green}4.${plain} Đặt lại tên tài khoản và mật khẩu
  ${green}5.${plain} Khôi phục cài đặt bảng điều khiển
  ${green}6.${plain} Đổi cổng bảng điều khiển
  ${green}7.${plain} Xem cài đặt bảng điều khiển
————————————————
  ${green}8.${plain} Khởi động x-ui
  ${green}9.${plain} Dừng x-ui
  ${green}10.${plain} Khởi động lại x-ui
  ${green}11.${plain} Xem trạng thái x-ui
  ${green}12.${plain} Xem nhật ký x-ui
————————————————
  ${green}13.${plain} Bật tự khởi động x-ui cùng hệ thống
  ${green}14.${plain} Tắt tự khởi động x-ui cùng hệ thống
————————————————
  ${green}15.${plain} Hướng dẫn BBR (tự cấu hình qua hệ điều hành)
  ${green}16.${plain} Cấp chứng chỉ SSL bằng acme.sh
 "
    show_status
    echo && read -p "Chọn chức năng [0-16]: " num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        check_uninstall && install
        ;;
    2)
        if check_install; then
            open_default_firewall_ports
            before_show_menu
        fi
        ;;
    3)
        check_install && uninstall
        ;;
    4)
        check_install && reset_user
        ;;
    5)
        check_install && reset_config
        ;;
    6)
        check_install && set_port
        ;;
    7)
        check_install && check_config
        ;;
    8)
        check_install && start
        ;;
    9)
        check_install && stop
        ;;
    10)
        check_install && restart
        ;;
    11)
        check_install && status
        ;;
    12)
        check_install && show_log
        ;;
    13)
        check_install && enable
        ;;
    14)
        check_install && disable
        ;;
    15)
        install_bbr
        ;;
    16)
        ssl_cert_issue
        ;;
    *)
        LOGE "Vui lòng nhập số hợp lệ [0-16]"
        ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
    "start")
        check_install 0 && start 0
        ;;
    "stop")
        check_install 0 && stop 0
        ;;
    "restart")
        check_install 0 && restart 0
        ;;
    "status")
        check_install 0 && status 0
        ;;
    "enable")
        check_install 0 && enable 0
        ;;
    "disable")
        check_install 0 && disable 0
        ;;
    "log")
        check_install 0 && show_log 0
        ;;
    "v2-ui")
        check_install 0 && migrate_v2_ui 0
        ;;
    "open-port")
        if check_install 0; then
            if [[ $# -eq 1 ]]; then
                open_default_firewall_ports
            else
                open_firewall_port "${2:-}" "${3:-}"
            fi
        fi
        ;;
    "install")
        check_uninstall 0 && install 0 "${2:-}"
        ;;
    "uninstall")
        check_install 0 && uninstall 0
        ;;
    *) show_usage ;;
    esac
else
    show_menu
fi
