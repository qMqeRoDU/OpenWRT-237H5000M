#!/bin/bash
# SPDX-License-Identifier: MIT

# Copyright (C) 2026 VIKINGYFY

#安装和更新软件包

UPDATE_PACKAGE() {

local PKG_NAME=$1

local PKG_REPO=$2

local PKG_BRANCH=$3

local PKG_SPECIAL=$4

local PKG_LIST=("$PKG_NAME" $5) # 第5个参数为自定义名称列表

local REPO_NAME=${PKG_REPO#*/}

echo " "

# 删除本地可能存在的不同名称的软件包
for NAME in "${PKG_LIST[@]}"; do

# 查找匹配的目录
echo "Search directory: $NAME"

local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

# 删除找到的目录
if [ -n "$FOUND_DIRS" ]; then

while read -r DIR; do

rm -rf "$DIR"

echo "Delete directory: $DIR"

done <<< "$FOUND_DIRS"

else

echo "Not fonud directory: $NAME"

fi

done

# 克隆 GitHub 仓库
git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"

# 处理克隆的仓库
if [[ "$PKG_SPECIAL" == "pkg" ]]; then

find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;

rm -rf ./$REPO_NAME/

elif [[ "$PKG_SPECIAL" == "name" ]]; then

mv -f $REPO_NAME $PKG_NAME

fi

}

# UPDATE_PACKAGE "包名" "项目地址" "项目分支" "pkg/name，可选，pkg为从大杂烩中单独提取包名插件；name为重命名为包名"

#===============================================

# Argon 主题继续使用 237 / ImmortalWrt feeds/luci 自带版本
# 不从 jerrykuku 官方 master 拉取，避免闭源 SDK 树兼容问题

#UPDATE_PACKAGE "argon" "jerrykuku/luci-theme-argon" "master"
#UPDATE_PACKAGE "argon-config" "jerrykuku/luci-app-argon-config" "master"

#===============================================
# H5000M 专属插件
#===============================================

# FAN789 H5000M 风扇控制
UPDATE_PACKAGE "h5000m-fancontrol" "FAN789/luci-app-h5000m-fancontrol" "main"

#===============================================
# Aurora 主题
#
# 主题：
# https://github.com/eamonxg/luci-theme-aurora
#
# 配置界面：
# https://github.com/eamonxg/luci-app-aurora-config
#
# 两个仓库都是标准 LuCI package，
# 直接 clone 到 package/ 下参与编译。
#===============================================

UPDATE_PACKAGE "luci-theme-aurora" \
"eamonxg/luci-theme-aurora" \
"master"

UPDATE_PACKAGE "luci-app-aurora-config" \
"eamonxg/luci-app-aurora-config" \
"master"

#===============================================
# 检查 Aurora 是否正确拉取
#===============================================

if [ ! -f "./luci-theme-aurora/Makefile" ]; then

echo "ERROR: luci-theme-aurora 下载失败"

exit 1

fi

if [ ! -f "./luci-app-aurora-config/Makefile" ]; then

echo "ERROR: luci-app-aurora-config 下载失败"

exit 1

fi

echo "===== Aurora ====="

grep -E \
'LUCI_TITLE|LUCI_DEPENDS|PKG_VERSION|PKG_RELEASE' \
./luci-theme-aurora/Makefile \
./luci-app-aurora-config/Makefile \
|| true

echo "=================="

# UPDATE_PACKAGE 是在 feeds install 之后才删 feeds 目录的，
# 会留下断链的符号链接，这里再清一次

find ../package/feeds/ -xtype l -exec rm -f {} + 2>/dev/null || true

#引入私有扩展脚本

if [ -f "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh" ]; then

source "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh"

fi
