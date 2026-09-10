#!/usr/bin/env bash
set -euo pipefail

DEV="${1:-/dev/sdb}"

if [[ ! -b "$DEV" ]]; then
  echo "error: $DEV is not a block device" >&2
  exit 1
fi

DATA=""
for part in $(lsblk -lno PATH "$DEV"); do
  [[ "$part" == "$DEV" ]] && continue
  fstype="$(lsblk -nro FSTYPE "$part")"
  label="$(lsblk -nro LABEL "$part")"
  if [[ "$fstype" == "exfat" || "$label" == "Ventoy" ]]; then
    DATA="$part"
  fi
done

if [[ -z "$DATA" ]]; then
  echo "error: could not find the Ventoy data partition on $DEV" >&2
  exit 1
fi

SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/cynthia"
if [[ ! -f "$SRC/theme.txt" ]]; then
  echo "error: $SRC/theme.txt not found" >&2
  exit 1
fi

MNT="$(mktemp -d /tmp/ventoy-install.XXXXXX)"
trap 'umount "$MNT" >/dev/null 2>&1 || true; rmdir "$MNT" >/dev/null 2>&1 || true' EXIT

mount "$DATA" "$MNT"

rm -rf "$MNT/ventoy/theme/cynthia" "$MNT/ventoy/theme/lain"
mkdir -p "$MNT/ventoy/theme"
cp -r "$SRC" "$MNT/ventoy/theme/cynthia"

if [[ -f "$MNT/ventoy/ventoy.json" && ! -f "$MNT/ventoy/ventoy.json.bak" ]]; then
  cp -a "$MNT/ventoy/ventoy.json" "$MNT/ventoy/ventoy.json.bak"
  echo "backed up existing ventoy.json to ventoy.json.bak"
fi

cat > "$MNT/ventoy/ventoy.json" <<'EOF'
{
    "theme": {
        "file": "/ventoy/theme/cynthia/theme.txt",
        "gfxmode": "max",
        "display_mode": "GUI",
        "fonts": [
            "/ventoy/theme/cynthia/terminus_regular_14.pf2",
            "/ventoy/theme/cynthia/ubuntu_bold_20.pf2",
            "/ventoy/theme/cynthia/ubuntu_regular_17.pf2"
        ]
    }
}
EOF

sync
umount "$MNT"
echo "Cynthia theme installed on Ventoy ($DATA)."