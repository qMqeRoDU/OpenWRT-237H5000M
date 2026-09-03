#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)  # 第5个参数为自定义名称列表
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
# 主题：沿用本项目原有做法，只用 argon，
#   且取源码树 feeds/luci 自带的那一份，不额外 clone。
# 其余插件全部走 feeds
# 不要在这里再加 passwall / openclash / mosdns
# 否则会和 feeds 里的同名包冲突
#===============================================
# argon 主题改用源码树 feeds/luci 自带的版本（2.4.3-20250722），
# 不再从 jerrykuku 拉取——官方 master(2.4.7) 与闭源 SDK 树有冲突。
# 需要换回官方版时，取消下面两行注释，并把 WRT-CORE.yml 里
# 删除 feeds/luci/{themes/luci-theme-argon,applications/luci-app-argon-config}
# 的两行 rm 加回去。
#UPDATE_PACKAGE "argon" "jerrykuku/luci-theme-argon" "master"
#UPDATE_PACKAGE "argon-config" "jerrykuku/luci-app-argon-config" "master"

#===============================================
# H5000M 专属插件
#   luci-app-h5000m-fancontrol 的 Makefile 在仓库根目录（平级结构），
#   当 src-git feed 用会报 "target pattern contains no '%'"，
#   只能 clone 到 package/ 下。
#   luci-app-mt5700m 是嵌套结构，已在 WRT-CORE.yml 里当 feed 接入，
#   不要在这里重复 clone，否则 package/ 与 package/feeds/ 下同名包冲突。
#===============================================
UPDATE_PACKAGE "h5000m-fancontrol" "FAN789/luci-app-h5000m-fancontrol" "main"

# UPDATE_PACKAGE 是在 feeds install 之后才删 feeds 目录的，
# 会留下断链的符号链接，这里再清一次
find ../package/feeds/ -xtype l -exec rm -f {} + 2>/dev/null || true

#引入私有扩展脚本
if [ -f "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh" ]; then
	source "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh"
fi
