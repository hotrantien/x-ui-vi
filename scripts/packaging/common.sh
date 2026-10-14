#!/usr/bin/env bash

packaging_error() {
    printf 'Lỗi đóng gói: %s\n' "$*" >&2
    exit 1
}

packaging_require_command() {
    command -v "$1" >/dev/null 2>&1 || packaging_error "Thiếu lệnh '$1'."
}

packaging_arch() {
    case "$(uname -m)" in
        x86_64|amd64) printf 'amd64\n' ;;
        aarch64|arm64) printf 'arm64\n' ;;
        s390x) printf 's390x\n' ;;
        *) packaging_error "Kiến trúc chưa hỗ trợ: $(uname -m)" ;;
    esac
}

packaging_validate_arch() {
    case "$1" in
        amd64|arm64|s390x) ;;
        *) packaging_error "Kiến trúc không hợp lệ: $1 (amd64, arm64 hoặc s390x)." ;;
    esac
}

packaging_require_input() {
    [[ -f "$1" && -s "$1" ]] || packaging_error "Thiếu tệp hoặc tệp rỗng: $1"
}

# Kiểm tra ELF64, endianness và e_machine, không thực thi tệp do người dùng cung cấp.
packaging_check_elf() {
    local pathname="$1" arch="$2" bytes machine actual
    packaging_require_command od
    packaging_require_input "$pathname"
    bytes="$(od -An -tu1 -N 6 "$pathname")"
    read -r -a fields <<< "$bytes"
    [[ "${fields[0]-}" == 127 && "${fields[1]-}" == 69 && "${fields[2]-}" == 76 && "${fields[3]-}" == 70 && "${fields[4]-}" == 2 ]] \
        || packaging_error "Không phải tệp ELF64 hợp lệ: $pathname"
    machine="$(od -An -tu1 -j 18 -N 2 "$pathname")"
    read -r -a fields <<< "$machine"
    case "$arch" in
        amd64) actual="62 0"; [[ "${fields[0]-} ${fields[1]-}" == "$actual" && "${bytes##* }" == "1" ]] ;;
        arm64) actual="183 0"; [[ "${fields[0]-} ${fields[1]-}" == "$actual" && "${bytes##* }" == "1" ]] ;;
        s390x) actual="0 22"; [[ "${fields[0]-} ${fields[1]-}" == "$actual" && "${bytes##* }" == "2" ]] ;;
    esac || packaging_error "ELF $pathname không phù hợp với kiến trúc linux/$arch."
}

packaging_check_go_binary() {
    local binary="$1" arch="$2" metadata
    packaging_require_command go
    metadata="$(go version -m "$binary")" || packaging_error "Không đọc được Go build metadata: $binary"
    printf '%s\n' "$metadata" | grep -Eq '^[[:space:]]*build[[:space:]]+CGO_ENABLED=1$' \
        || packaging_error "Binary x-ui chưa xác nhận CGO_ENABLED=1; SQLite sẽ không hoạt động với CGO=0."
    printf '%s\n' "$metadata" | grep -Eq '^[[:space:]]*build[[:space:]]+GOOS=linux$' \
        || packaging_error "Binary x-ui không được build cho Linux."
    printf '%s\n' "$metadata" | grep -Eq "^[[:space:]]*build[[:space:]]+GOARCH=$arch$" \
        || packaging_error "GOARCH trong Go metadata không phải $arch."
    printf '%s\n' "$metadata" | grep -Eq '^[[:space:]]*dep[[:space:]]+github.com/mattn/go-sqlite3[[:space:]]' \
        || packaging_error "Binary x-ui không khai báo driver SQLite mong đợi."
}
