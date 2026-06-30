#!/bin/sh
set -eu

# Run this script on the OpenWrt router after the local bundle has been copied
# to /tmp/gl-mt3000-toolbox by prepare_gl_mt3000_offline_bundle.sh.

BUNDLE_DIR="${1:-/tmp/gl-mt3000-toolbox}"
IPK_DIR="$BUNDLE_DIR/ipk"
COMMON_IPK_DIR="$IPK_DIR/common"
PASSWALL1_IPK_DIR="$IPK_DIR/passwall1"
PASSWALL2_IPK_DIR="$IPK_DIR/passwall2"
CORE_DIR="$BUNDLE_DIR/cores"
ARCH="aarch64_cortex-a53"

red() { printf "\033[31m\033[01m%s\033[0m\n" "$1"; }
green() { printf "\033[32m\033[01m%s\033[0m\n" "$1"; }
yellow() { printf "\033[33m\033[01m%s\033[0m\n" "$1"; }

if ! command -v opkg >/dev/null 2>&1; then
  red "opkg was not found. Run this installer on the OpenWrt router, not on this Mac."
  echo "Example:"
  echo "  ssh root@192.168.8.1"
  echo "  sh ${BUNDLE_DIR}/install_gl_mt3000_offline_bundle.sh"
  exit 1
fi

if ! opkg print-architecture | grep -q "$ARCH"; then
  yellow "警告: 当前 opkg 架构列表没有 ${ARCH}。"
  yellow "该离线包是为 GL-MT3000 / ${ARCH} 准备的。"
  read -r -p "仍然继续吗？[y/N]: " confirm
  case "$confirm" in
    y|Y) ;;
    *) exit 1 ;;
  esac
fi

if [ ! -d "$BUNDLE_DIR" ]; then
  red "找不到离线包目录: $BUNDLE_DIR"
  exit 1
fi

echo "离线包目录: $BUNDLE_DIR"
[ -r "$BUNDLE_DIR/manifest.txt" ] && cat "$BUNDLE_DIR/manifest.txt"

install_ipk_dir() {
  dir="$1"
  label="$2"

  if [ ! -d "$dir" ]; then
    yellow "没有找到 ${label} 目录: $dir"
    return 0
  fi

  ipk_count="$(find "$dir" -type f -name '*.ipk' | wc -l | tr -d ' ')"
  if [ "$ipk_count" -gt 0 ]; then
    green "安装 ${label} IPK 包..."
    opkg install "$dir"/*.ipk || {
      yellow "部分 IPK 安装失败。请检查上方 opkg 依赖错误。"
    }
  else
    yellow "没有找到 ${label} IPK 包: $dir"
  fi
}

echo
echo "请选择要安装/更新的 PassWall 版本:"
echo "  1. PassWall 1"
echo "  2. PassWall 2 (推荐用于 sing-box / HY2 / Reality 测试)"
echo "  3. 只安装核心和通用依赖，不安装 LuCI 主包"
read -r -p "请输入选项 [2]: " passwall_choice
passwall_choice="${passwall_choice:-2}"

install_ipk_dir "$COMMON_IPK_DIR" "通用依赖"

case "$passwall_choice" in
  1)
    if [ -x /etc/init.d/passwall2 ]; then
      /etc/init.d/passwall2 stop 2>/dev/null || true
      /etc/init.d/passwall2 disable 2>/dev/null || true
    fi
    install_ipk_dir "$PASSWALL1_IPK_DIR" "PassWall 1"
    ;;
  2)
    if [ -x /etc/init.d/passwall ]; then
      /etc/init.d/passwall stop 2>/dev/null || true
      /etc/init.d/passwall disable 2>/dev/null || true
    fi
    install_ipk_dir "$PASSWALL2_IPK_DIR" "PassWall 2"
    ;;
  3)
    yellow "跳过 LuCI 主包安装。"
    ;;
  *)
    red "无效选项: $passwall_choice"
    exit 1
    ;;
esac

install_core() {
  name="$1"
  src="$CORE_DIR/$name"
  dst="/usr/bin/$name"

  if [ ! -s "$src" ]; then
    yellow "跳过 ${name}: 未找到 $src"
    return 0
  fi

  green "安装核心: $name"
  cp "$src" "$dst"
  chmod +x "$dst"
}

if [ -d "$CORE_DIR" ]; then
  install_core sing-box
  install_core xray
  install_core hysteria
else
  yellow "没有找到核心目录: $CORE_DIR"
fi

echo
green "版本检查:"
command -v sing-box >/dev/null 2>&1 && sing-box version | head -n 1 || yellow "sing-box 未安装"
command -v xray >/dev/null 2>&1 && xray version | head -n 1 || yellow "xray 未安装"
command -v hysteria >/dev/null 2>&1 && hysteria version | head -n 1 || yellow "hysteria 未安装"

case "$passwall_choice" in
  1)
    [ -x /etc/init.d/passwall ] && /etc/init.d/passwall restart || true
    ;;
  2)
    [ -x /etc/init.d/passwall2 ] && /etc/init.d/passwall2 restart || true
    ;;
  3)
    [ -x /etc/init.d/passwall ] && /etc/init.d/passwall restart || true
    [ -x /etc/init.d/passwall2 ] && /etc/init.d/passwall2 restart || true
    ;;
esac

if [ -x /etc/init.d/uhttpd ]; then
  /etc/init.d/uhttpd restart || true
fi

green "完成。请刷新 LuCI，并在对应 PassWall 页面中重新导入订阅/启动节点。"
