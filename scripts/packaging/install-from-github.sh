#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'HELP'
Tai goi cai dat tu GitHub Releases cua CHINH ban Viet hoa do ban quan ly.

  sudo bash scripts/packaging/install-from-github.sh OWNER/REPO [TAG]

Vi du: sudo bash scripts/packaging/install-from-github.sh myname/x-ui-vi v0.3.2-vi.1
Neu khong co TAG, su dung latest release. Repo phai la public; repo private
can tai goi bang GitHub CLI da xac thuc, roi chay install.sh truc tiep.

Script chi tai archive va SHA256SUMS tu repo duoc CHI DINH, xac minh SHA256
truoc khi giai nen install.sh. Bo cai sau do khong tai ma nguon tu GitHub.
HELP
}

if [[ "${1:-}" == -h || "${1:-}" == --help ]]; then usage; exit 0; fi
[[ $# -ge 1 && $# -le 2 ]] || { usage >&2; exit 2; }
[[ $EUID -eq 0 ]] || { echo 'Can quyen root (sudo).' >&2; exit 1; }
repo="$1"
tag="${2:-}"
[[ "$repo" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$ ]] \
    || { echo 'Repo phai co dinh dang OWNER/REPO.' >&2; exit 2; }
if [[ -n "$tag" ]]; then
    [[ "$tag" =~ ^v[0-9][A-Za-z0-9._-]*$ ]] \
        || { echo 'Tag khong hop le.' >&2; exit 2; }
fi

for tool in curl tar sha256sum mktemp grep awk; do
    command -v "$tool" >/dev/null 2>&1 || { echo "Thieu lenh: $tool" >&2; exit 1; }
done

case "$(uname -m)" in
    x86_64|amd64) arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) echo 'Hien chi co Release amd64 va arm64.' >&2; exit 1 ;;
esac

file="x-ui-linux-${arch}.tar.gz"
if [[ -n "$tag" ]]; then
    base="https://github.com/${repo}/releases/download/${tag}"
else
    base="https://github.com/${repo}/releases/latest/download"
fi

umask 077
work_dir="$(mktemp -d)"
trap 'rm -rf -- "$work_dir"' EXIT
cd -- "$work_dir"
echo "Tai $file tu GitHub Release cua $repo"
curl --fail --location --show-error --silent --retry 3 --connect-timeout 20 \
    --output "$file" "$base/$file"
curl --fail --location --show-error --silent --retry 3 --connect-timeout 20 \
    --output SHA256SUMS "$base/SHA256SUMS"

# Chi lay checksum cua kien truc can cai; release chua hai kien truc.
awk -v wanted="$file" '
    substr($0, 67) == wanted { print; count++ }
    END { if (count != 1) exit 1 }
' SHA256SUMS > expected.sha256 || { echo 'Thieu SHA256 hop le cho archive.' >&2; exit 1; }
sha256sum --check --status expected.sha256 \
    || { echo 'SHA256 archive khong khop; khong cai dat.' >&2; exit 1; }

# Khong thuc thi install.sh neu khong nam trong archive da xac minh.
tar -xOf "$file" x-ui/install.sh > install.sh \
    || { echo 'Archive thieu install.sh.' >&2; exit 1; }
chmod 700 install.sh
bash install.sh "$work_dir/$file"
