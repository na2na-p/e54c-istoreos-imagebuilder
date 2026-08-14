#!/bin/sh
# ビルド済み SD イメージを開いて中身を検証する。実機起動の CI 再現は不可能
# (RK3582 は QEMU にマシンモデルが無く、BootROM → U-Boot のチェーンを再現できない) なため、
# 「ビルドは通るが中身が欠ける」型の退行をイメージの静的検証で捕まえる。
set -eu

workdir="${RUNNER_TEMP:-/tmp}/smoke-test"
mkdir -p "${workdir}"

set -- imagebuilder/bin/targets/rockchip/armv8/*.img.gz
img_gz="$1"
if [ "$#" -ne 1 ] || [ ! -f "${img_gz}" ]; then
  echo "expected exactly one built image, got: $*" >&2
  exit 1
fi

# OpenWrt イメージは末尾にメタデータを持ち、gunzip が trailing garbage (exit 2) を返すため許容する
gunzip -c "${img_gz}" > "${workdir}/disk.img" || [ "$?" -eq 2 ]

# rootfs (squashfs) は第 2 パーティションにある前提。レイアウト変化に気づけるよう magic で裏取りする
start=$(sfdisk -J "${workdir}/disk.img" | jq '.partitiontable.partitions[1].start')
offset=$((start * 512))
magic=$(dd if="${workdir}/disk.img" skip="${offset}" bs=1 count=4 2>/dev/null)
if [ "${magic}" != "hsqs" ]; then
  echo "partition 2 does not look like squashfs (magic: ${magic})" >&2
  exit 1
fi

# 全展開はデバイスノード作成が非 root で失敗するため、検証対象のパスだけ取り出す
extract="${workdir}/rootfs"
baked_files=$(find files -type f | sed 's|^files/||')
# shellcheck disable=SC2086 # baked_files は空白を含まないパス列の意図的な単語分割
unsquashfs -q -d "${extract}" -o "${offset}" "${workdir}/disk.img" \
  usr/lib/opkg/status ${baked_files}

fail=0

# shellcheck disable=SC2086
for f in ${baked_files}; do
  if [ -f "${extract}/${f}" ]; then
    echo "baked file OK: /${f}"
  else
    echo "::error::baked file missing in image: /${f}"
    fail=1
  fi
done

for pkg in $(grep -v '^#' packages.txt | xargs -n1); do
  if grep -qx "Package: ${pkg}" "${extract}/usr/lib/opkg/status"; then
    echo "package OK: ${pkg}"
  else
    echo "::error::package missing in image: ${pkg}"
    fail=1
  fi
done

exit "${fail}"
