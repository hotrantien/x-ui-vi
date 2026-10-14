#!/usr/bin/env bash
set -euo pipefail

# Cai mot lan tren VPS moi; chi tai ban x-ui VI co dinh v0.3.2-vi.5.
repo='hotrantien/x-ui-vi'
tag='v0.3.2-vi.5'
source_url="https://raw.githubusercontent.com/${repo}/${tag}/scripts/packaging/install-from-github.sh"

if (( EUID != 0 )); then
    echo 'Can quyen root. Dung: curl -fsSL URL | sudo bash' >&2
    exit 1
fi

for command in curl mktemp bash; do
    command -v "$command" >/dev/null 2>&1 || {
        echo "Thieu cong cu: $command" >&2
        exit 1
    }
done

if ! (: </dev/tty) 2>/dev/null; then
    echo 'Can terminal SSH tuong tac de nhap tai khoan, mat khau va cong quan tri.' >&2
    exit 1
fi

umask 077
work_dir="$(mktemp -d)"
trap 'rm -rf -- "$work_dir"' EXIT

curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 \
    --output "$work_dir/installer.sh" "$source_url"

# Khoi phuc stdin tu terminal: script cai can read -p va read -s.
# Neu khong co chuyen huong nay, `curl | sudo bash` se nuot stdin cua prompt.
bash "$work_dir/installer.sh" "$repo" "$tag" </dev/tty
