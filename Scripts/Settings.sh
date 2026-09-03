#!/bin/bash

# SPDX-License-Identifier: MIT

# Copyright (C) 2026 VIKINGYFY


# ============================================================
# H5000M 固件默认参数
# ============================================================

# MTK 闭源 WiFi 两个频段名称
MTWIFI_SSID_2G="Hiveton-2G"
MTWIFI_SSID_5G="Hiveton-5G"


# ============================================================
# LuCI
# ============================================================

# lede 与 immortalwrt 的 luci 目录结构不完全一样
# 所有 sed 都先判断文件是否存在

COLLECTIONS=$(find ./feeds/luci/collections/ \
    -type f \
    -name "Makefile" \
    2>/dev/null)

if [ -n "$COLLECTIONS" ]; then

    # 移除 luci-app-attendedsysupgrade
    sed -i "/attendedsysupgrade/d" $COLLECTIONS

    # 修改默认主题
    sed -i \
        "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" \
        $COLLECTIONS

fi


# ============================================================
# 修改 immortalwrt.lan 关联 IP
# ============================================================

FLASH_JS=$(find ./feeds/luci/modules/luci-mod-system/ \
    -type f \
    -name "flash.js" \
    2>/dev/null)

if [ -n "$FLASH_JS" ]; then

    sed -i \
        "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" \
        $FLASH_JS

fi


# ============================================================
# 添加编译日期标识
# ============================================================

SYS_JS=$(find ./feeds/luci/modules/luci-mod-status/ \
    -type f \
    -name "10_system.js" \
    2>/dev/null)

if [ -n "$SYS_JS" ]; then

    sed -i \
        "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" \
        $SYS_JS

fi


# ============================================================
# 普通 mac80211 WiFi
#
# 这个主要作为其它平台兼容逻辑。
# H5000M 实际使用下面单独处理的 MTK 闭源 mtwifi。
# ============================================================

WIFI_SH=$(find \
    ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ \
    -type f \
    -name "*set-wireless.sh" \
    2>/dev/null)

WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"

if [ -n "$WIFI_SH" ] && [ -f "$WIFI_SH" ]; then

    # 普通无线默认名称
    sed -i \
        "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" \
        "$WIFI_SH"

    # 普通无线默认密码
    sed -i \
        "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" \
        "$WIFI_SH"

elif [ -f "$WIFI_UC" ]; then

    # 普通无线默认名称
    sed -i \
        "s/ssid='.*'/ssid='$WRT_SSID'/g" \
        "$WIFI_UC"

    # 普通无线默认密码
    sed -i \
        "s/key='.*'/key='$WRT_WORD'/g" \
        "$WIFI_UC"

fi


# ============================================================
# H5000M MTK 闭源 MT7992 WiFi
#
# 237 源码默认：
#
#   2.4G = ImmortalWrt-2.4G
#   5G   = ImmortalWrt-5G
#   encryption = none
#
# 修改为：
#
#   2.4G = Hiveton-2G
#   5G   = Hiveton-5G
#   WPA2-PSK + CCMP(AES)
#   密码 = WRT_WORD
# ============================================================

MTWIFI_SH="./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh"

if [ -f "$MTWIFI_SH" ]; then

    echo "========================================"
    echo " Configure H5000M MT7992 WiFi"
    echo "========================================"

    # --------------------------------------------------------
    # 2.4GHz SSID
    # --------------------------------------------------------

    sed -i \
        's|ssid="ImmortalWrt-2.4G"|ssid="Hiveton-2G"|g' \
        "$MTWIFI_SH"

    # --------------------------------------------------------
    # 5GHz SSID
    # --------------------------------------------------------

    sed -i \
        's|ssid="ImmortalWrt-5G"|ssid="Hiveton-5G"|g' \
        "$MTWIFI_SH"

    # --------------------------------------------------------
    # 加密：
    #
    # psk2+ccmp
    #
    # = WPA2-PSK + AES
    #
    # 同时增加 WiFi 密码
    # --------------------------------------------------------

    sed -i \
        's|^\(\s*\)set wireless\.\(default_${dev}\)\.encryption=none|\1set wireless.\2.encryption=psk2+ccmp\n\1set wireless.\2.key='"$WRT_WORD"'|' \
        "$MTWIFI_SH"


    # ========================================================
    # 修改结果检查
    #
    # 如果 237 上游以后改了 mtwifi.sh，
    # 导致 SSID 没有替换成功，直接停止编译。
    # 防止刷机以后才发现还是默认名称。
    # ========================================================

    if grep -Fq \
        'ssid="Hiveton-2G"' \
        "$MTWIFI_SH"; then

        echo "[ OK ] 2.4G SSID = Hiveton-2G"

    else

        echo "ERROR: 2.4G SSID 修改失败"

        exit 1

    fi


    if grep -Fq \
        'ssid="Hiveton-5G"' \
        "$MTWIFI_SH"; then

        echo "[ OK ] 5G SSID = Hiveton-5G"

    else

        echo "ERROR: 5G SSID 修改失败"

        exit 1

    fi


    if grep -Fq \
        'encryption=psk2+ccmp' \
        "$MTWIFI_SH"; then

        echo "[ OK ] WiFi Encryption = WPA2-PSK + CCMP(AES)"

    else

        echo "ERROR: WiFi 加密方式修改失败"

        exit 1

    fi


    if grep -Fq \
        "key=$WRT_WORD" \
        "$MTWIFI_SH"; then

        echo "[ OK ] WiFi password configured"

    else

        echo "ERROR: WiFi 密码修改失败"

        exit 1

    fi


    echo
    echo "===== MTWiFi final config ====="

    grep -E \
        'ssid=|encryption=|key=' \
        "$MTWIFI_SH" \
        || true

    echo "=============================="

else

    echo "ERROR: 没有找到 MTK mtwifi.sh"

    exit 1

fi


# ============================================================
# 修改默认 LAN IP 和主机名
# ============================================================

CFG_FILE="./package/base-files/files/bin/config_generate"

if [ -f "$CFG_FILE" ]; then

    # 默认 LAN：
    #
    # 192.168.99.1
    #
    # 实际值取 H5000m.yml 中的 WRT_IP

    sed -i \
        "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" \
        "$CFG_FILE"

    # 默认主机名

    sed -i \
        "s/hostname='.*'/hostname='$WRT_NAME'/g" \
        "$CFG_FILE"

fi


# ============================================================
# LuCI 配置
# ============================================================

echo "CONFIG_PACKAGE_luci=y" >> ./.config

echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config


# ------------------------------------------------------------
# 默认主题
#
# 当前 H5000m.yml：
#
# WRT_THEME: argon
# ------------------------------------------------------------

echo \
    "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" \
    >> ./.config

echo \
    "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" \
    >> ./.config


# ============================================================
# Aurora
#
# Argon 继续作为默认主题。
# Aurora + Aurora Config 同时编进固件。
# ============================================================

echo \
    "CONFIG_PACKAGE_luci-theme-aurora=y" \
    >> ./.config

echo \
    "CONFIG_PACKAGE_luci-app-aurora-config=y" \
    >> ./.config

echo \
    "CONFIG_PACKAGE_luci-i18n-aurora-config-zh-cn=y" \
    >> ./.config


# ============================================================
# 私有扩展配置
# ============================================================

if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then

    echo "Applying private configurations from PRIVATE.txt..."

    cat \
        "$GITHUB_WORKSPACE/Config/PRIVATE.txt" \
        >> ./.config

fi


# ============================================================
# 手动调整插件
# ============================================================

if [ -n "$WRT_PACKAGE" ]; then

    echo -e \
        "$WRT_PACKAGE" \
        >> ./.config

fi


# ============================================================
# 无 WiFi 配置标志
# ============================================================

if [[ "${WRT_CONFIG,,}" == *"wifi"* && \
      "${WRT_CONFIG,,}" == *"no"* ]]; then

    echo \
        "WRT_WIFI=wifi-no" \
        >> "$GITHUB_ENV"

fi


# ============================================================
# 高通平台调整
# ============================================================

DTS_PATH="./target/linux/qualcommax/dts/"

if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]] && \
   [ -d "$DTS_PATH" ]; then

    # 无 WiFi 配置调整 Q6 大小

    if [[ "${WRT_CONFIG,,}" == *"wifi"* && \
          "${WRT_CONFIG,,}" == *"no"* ]]; then

        find \
            "$DTS_PATH" \
            -type f \
            ! -iname '*nowifi*' \
            -exec sed -i \
            's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' \
            {} +

        echo \
            "qualcommax set up nowifi successfully!"

    fi

fi


exit 0
