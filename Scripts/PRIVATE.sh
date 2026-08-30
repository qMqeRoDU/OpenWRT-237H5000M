#!/bin/bash
#
# PRIVATE.sh —— 编译期内置 OpenClash 内核与 Geo 数据
#
# 由 Scripts/Packages.sh 在末尾 source 执行，此时工作目录是 wrt/package/
# 注：wmsxwd 插件已停止编译，相关逻辑整段移除
#

echo ""
echo "=================================================="
echo " OpenClash 内核 + Geo 数据（编译时内置）"
echo "=================================================="

# files/ 在源码树根目录，当前工作目录是 wrt/package/
OC_FILES="../files"

oc_say()  { echo "[openclash] $*"; }
oc_warn() { echo "[openclash][警告] $*" >&2; }

# ---- 按平台选内核架构 ----
# WRT_TARGET 由 WRT-CORE.yml 从 Config/*.txt 的第一条 CONFIG_TARGET_xxx=y 取得
#   x86        -> amd64-compatible
#   mediatek   -> arm64（MT7986A / MT7981 均为 Cortex-A53 64 位）
#   qualcommax -> arm64
# 取不到就跳过，绝不猜——下错架构的二进制在设备上根本跑不起来，
# 而且 OpenClash 只会报“内核不可用”，很难定位。
# 需要手动指定时，在 workflow 里设 OC_ARCH_FORCE 环境变量即可覆盖。
case "${OC_ARCH_FORCE:-${WRT_TARGET:-}}" in
	amd64-compatible|arm64|armv7|armv5|mipsle-softfloat|mips-softfloat)
		OC_ARCH="${OC_ARCH_FORCE}" ;;
	x86)
		OC_ARCH="amd64-compatible" ;;
	mediatek|qualcommax|rockchip|sunxi|armsr|bcm27xx)
		OC_ARCH="arm64" ;;
	*)
		OC_ARCH="" ;;
esac

OC_BRANCH="master"
OC_TYPE="meta"

if [ -z "$OC_ARCH" ]; then
	oc_warn "无法从 WRT_TARGET='${WRT_TARGET:-未设置}' 判断内核架构，跳过内置，刷机后需在面板手动下载"
else
	OC_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/${OC_BRANCH}/${OC_TYPE}/clash-linux-${OC_ARCH}.tar.gz"
	oc_say "平台 ${WRT_TARGET:-?} -> 内核架构 ${OC_ARCH}"

	OC_TMP="$(mktemp -d)"
	if curl -fsSL --connect-timeout 20 --max-time 600 --retry 3 --retry-delay 5 \
		-o "$OC_TMP/core.tar.gz" "$OC_URL" && [ -s "$OC_TMP/core.tar.gz" ]; then

		if tar -xzf "$OC_TMP/core.tar.gz" -C "$OC_TMP" && [ -f "$OC_TMP/clash" ]; then
			mkdir -p "$OC_FILES/etc/openclash/core"
			mv -f "$OC_TMP/clash" "$OC_FILES/etc/openclash/core/clash_meta"
			chmod 755 "$OC_FILES/etc/openclash/core/clash_meta"
			oc_say "内核已内置：/etc/openclash/core/clash_meta （${OC_BRANCH}/${OC_TYPE}/${OC_ARCH}，$(du -h "$OC_FILES/etc/openclash/core/clash_meta" | cut -f1)）"
		else
			oc_warn "内核解包失败，本次固件不含内核，刷机后需在面板手动下载"
		fi
	else
		oc_warn "内核下载失败，本次固件不含内核，刷机后需在面板手动下载"
	fi
	rm -rf "$OC_TMP"
fi

# ---- Geo 数据：每次编译抓上游最新 ----
# 路径与 SSR+ / PassWall / OpenClash 官方脚本一致
GEO_TMP="$(mktemp -d)"
mkdir -p "$OC_FILES/usr/share/v2ray" "$OC_FILES/usr/share/shadowsocksr" "$OC_FILES/etc/openclash"

geo_fetch() {
	local name="$1" url="$2" dest="$3"
	if curl -fsSL --connect-timeout 20 --max-time 600 --retry 3 --retry-delay 5 \
		-o "$GEO_TMP/$name" "$url" && [ -s "$GEO_TMP/$name" ]; then
		mv -f "$GEO_TMP/$name" "$dest"
		echo "[geo] $name -> ${dest#$OC_FILES}  （$(du -h "$dest" | cut -f1)）"
	else
		echo "[geo][警告] $name 下载失败，跳过" >&2
	fi
}

# 用完整版 geoip.dat（PassWall 也依赖它，不能用 cn-only 那份覆盖）
geo_fetch "geoip.dat" \
	"https://github.com/Loyalsoldier/geoip/releases/latest/download/geoip.dat" \
	"$OC_FILES/usr/share/v2ray/geoip.dat"

geo_fetch "geosite.dat" \
	"https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat" \
	"$OC_FILES/usr/share/v2ray/geosite.dat"

geo_fetch "Country.mmdb" \
	"https://github.com/alecthw/mmdb_china_ip_list/releases/latest/download/Country-lite.mmdb" \
	"$OC_FILES/usr/share/shadowsocksr/Country.mmdb"

# OpenClash 读的是 /etc/openclash/ 下这三份，复制一份过去
for OC_PAIR in \
	"$OC_FILES/usr/share/v2ray/geoip.dat:$OC_FILES/etc/openclash/GeoIP.dat" \
	"$OC_FILES/usr/share/v2ray/geosite.dat:$OC_FILES/etc/openclash/GeoSite.dat" \
	"$OC_FILES/usr/share/shadowsocksr/Country.mmdb:$OC_FILES/etc/openclash/Country.mmdb" ; do
	OC_SRC="${OC_PAIR%%:*}"
	OC_DST="${OC_PAIR##*:}"
	if [ -s "$OC_SRC" ]; then
		cp -f "$OC_SRC" "$OC_DST" && chmod 644 "$OC_DST"
		echo "[geo] $(basename "$OC_DST") -> /etc/openclash/"
	fi
done

rm -rf "$GEO_TMP"

echo "=================================================="
echo ""
