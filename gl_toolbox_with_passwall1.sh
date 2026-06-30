#!/bin/sh
set -u

# GL-iNet toolbox launcher with a PassWall 1 installer for GL-MT3000.
# Intended one-line usage:
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/ZzyYoung/gl-mt3000-toolbox/passwall-toolbox/gl_toolbox_with_passwall1.sh)"

HTTP_HOST="https://cafe.cpolar.cn/wkdaily/gl/raw/branch/main"
SCRIPT_DIR="/tmp/gl-scripts"

PASSWALL_ARCH="aarch64_cortex-a53"
PASSWALL_OPENWRT_SERIES="21.02"
PASSWALL_DEST_DIR="/tmp/passwall1-ipk"
PASSWALL_PROJECT_BASE="https://sourceforge.net/projects/openwrt-passwall-build/files/releases/packages-${PASSWALL_OPENWRT_SERIES}/${PASSWALL_ARCH}"

red() { printf "\033[31m\033[01m%s\033[0m\n" "$1"; }
green() { printf "\033[32m\033[01m%s\033[0m\n" "$1"; }
yellow() { printf "\033[33m\033[01m%s\033[0m\n" "$1"; }
blue() { printf "\033[34m\033[01m%s\033[0m\n" "$1"; }
magenta() { printf "\033[95m\033[01m%s\033[0m\n" "$1"; }

get_router_name() {
  if [ -r /tmp/sysinfo/model ]; then
    cat /tmp/sysinfo/model
  else
    echo "Unknown"
  fi
}

download_and_run_script() {
  script_name="$1"
  mkdir -p "$SCRIPT_DIR"
  script_path="$SCRIPT_DIR/$script_name"

  green "正在下载 $script_name..."
  if ! wget -O "$script_path" "$HTTP_HOST/$script_name"; then
    red "下载 $script_name 失败"
    return 1
  fi

  chmod +x "$script_path"
  green "正在启动 $script_name..."
  sh "$script_path"
}

auto_detect_and_run() {
  gl_name="$(get_router_name)"
  echo "检测到路由器型号: $gl_name"

  case "$gl_name" in
    *BE6500*|*be6500*) download_and_run_script "be6500.sh" ;;
    *BE9300*|*be9300*) download_and_run_script "be9300.sh" ;;
    *BE3600*|*be3600*) download_and_run_script "be3600.sh" ;;
    *MT5000*|*mt5000*) download_and_run_script "mt5000.sh" ;;
    *MT3600*|*mt3600*) download_and_run_script "mt3600.sh" ;;
    *E5800*|*e5800*|*Mudi*|*mudi*) download_and_run_script "mudi7.sh" ;;
    *MT-3000*|*mt3000*|*MT3000*|*MT-6000*|*mt6000*|*MT6000*)
      if grep -q "OP24" /etc/openwrt_release 2>/dev/null; then
        download_and_run_script "gl-inet-op24.sh"
      else
        download_and_run_script "gl-inet.sh"
      fi
      ;;
    *MT-2500*|*mt2500*|*MT2500*) download_and_run_script "gl-inet.sh" ;;
    *)
      red "抱歉，暂不支持该机型: $gl_name"
      echo "您可以手动选择机型运行对应脚本。"
      return 1
      ;;
  esac
}

select_model() {
  echo
  echo "请选择您的路由器型号:"
  green " 1. GL-iNet BE-6500"
  green " 2. GL-iNet BE-9300"
  green " 3. GL-iNet BE-3600"
  green " 4. GL-iNet MT-5000"
  green " 5. GL-iNet MT-3600"
  green " 6. GL-iNet Mudi 7 (GL-E5800)"
  green " 7. GL-iNet MT-2500A"
  green " 8. GL-iNet MT-3000"
  green " 9. GL-iNet MT-6000"
  green "10. GL-iNet MT-3000 (OP24 固件)"
  green "11. GL-iNet MT-6000 (OP24 固件)"
  green "12. MT-3000 换分区助手 (U盘扩容)"
  echo
  echo " Q. 退出"
  echo
  read -r -p "请输入选项: " choice

  case "$choice" in
    1) download_and_run_script "be6500.sh" ;;
    2) download_and_run_script "be9300.sh" ;;
    3) download_and_run_script "be3600.sh" ;;
    4) download_and_run_script "mt5000.sh" ;;
    5) download_and_run_script "mt3600.sh" ;;
    6) download_and_run_script "mudi7.sh" ;;
    7|8|9) download_and_run_script "gl-inet.sh" ;;
    10|11) download_and_run_script "gl-inet-op24.sh" ;;
    12) download_and_run_script "mt-3000/mt3000.sh" ;;
    q|Q) echo "退出"; exit 0 ;;
    *) red "无效选项，请重新选择" ;;
  esac
}

passwall_check_environment() {
  if ! command -v opkg >/dev/null 2>&1; then
    red "未找到 opkg，这个安装器需要在 OpenWrt 上执行。"
    return 1
  fi

  if ! opkg print-architecture | grep -q "$PASSWALL_ARCH"; then
    yellow "警告: opkg print-architecture 未显示 ${PASSWALL_ARCH}。"
    yellow "当前 PassWall 包是给 GL-MT3000 / ${PASSWALL_ARCH} 准备的。"
    read -r -p "仍然继续吗？[y/N]: " confirm
    case "$confirm" in
      y|Y) ;;
      *) return 1 ;;
    esac
  fi

  if [ -r /etc/openwrt_release ]; then
    openwrt_release="$(sed -n "s/^DISTRIB_RELEASE='\{0,1\}\([^']*\)'\{0,1\}/\1/p" /etc/openwrt_release | head -n 1)"
    case "$openwrt_release" in
      21.02*|"") ;;
      *)
        yellow "警告: 当前固件版本看起来是 ${openwrt_release}，包目录是 ${PASSWALL_OPENWRT_SERIES}。"
        yellow "如果你的固件不是基于 21.02，可能会有依赖不匹配。"
        read -r -p "仍然继续吗？[y/N]: " confirm
        case "$confirm" in
          y|Y) ;;
          *) return 1 ;;
        esac
        ;;
    esac
  fi
}

passwall_download_pkg() {
  subdir="$1"
  file="$2"
  required="${3:-1}"
  url="${PASSWALL_PROJECT_BASE}/${subdir}/${file}/download"

  if [ -s "$file" ]; then
    echo "[skip] $file"
    return 0
  fi

  echo "[download] $file"
  if ! wget -O "$file" "$url"; then
    rm -f "$file"
    if [ "$required" -eq 1 ]; then
      red "必要包下载失败: $file"
      echo "URL: $url"
      return 1
    fi
    yellow "可选包下载失败，已跳过: $file"
    return 1
  fi
}

passwall_download_latest_pkg() {
  subdir="$1"
  prefix="$2"
  required="${3:-0}"
  index_file="/tmp/passwall-sf-${subdir}.html"
  dir_url="${PASSWALL_PROJECT_BASE}/${subdir}/"

  echo "[lookup] ${prefix}_*.ipk"
  if ! wget -O "$index_file" "$dir_url"; then
    [ "$required" -eq 1 ] && red "读取目录失败: $dir_url" && return 1
    yellow "无法读取目录，已跳过: $prefix"
    return 1
  fi

  file="$(grep -o "${prefix}_[A-Za-z0-9._+~:-]*_\\(all\\|${PASSWALL_ARCH}\\)\\.ipk" "$index_file" | sort -u | tail -n 1 || true)"
  rm -f "$index_file"

  if [ -z "$file" ]; then
    [ "$required" -eq 1 ] && red "找不到必要包: ${prefix}_*.ipk" && return 1
    yellow "找不到可选包，已跳过: ${prefix}"
    return 1
  fi

  passwall_download_pkg "$subdir" "$file" "$required"
}

install_passwall1() {
  passwall_check_environment || return 1

  echo
  blue "PassWall 1 安装选项"
  echo "1. 基础安装 (推荐)"
  echo "2. 基础安装 + SSR/simple-obfs"
  echo "3. 基础安装 + NaiveProxy"
  echo "4. 只下载安装包，不安装"
  echo
  read -r -p "请输入选项 [1]: " mode
  mode="${mode:-1}"

  with_ssr=0
  with_obfs=0
  with_naive=0
  install_after_download=1

  case "$mode" in
    1) ;;
    2) with_ssr=1; with_obfs=1 ;;
    3) with_naive=1 ;;
    4) install_after_download=0 ;;
    *) red "无效选项"; return 1 ;;
  esac

  mkdir -p "$PASSWALL_DEST_DIR"
  cd "$PASSWALL_DEST_DIR" || return 1

  passwall_download_pkg "passwall_luci" "luci-app-passwall_26.6.2_all.ipk" 1 || return 1
  passwall_download_pkg "passwall_luci" "luci-i18n-passwall-zh-cn_26.6.2_all.ipk" 1 || return 1

  passwall_download_latest_pkg "passwall_packages" "v2ray-geoip" 0 || true
  passwall_download_latest_pkg "passwall_packages" "v2ray-geosite" 0 || true
  passwall_download_latest_pkg "passwall_packages" "chinadns-ng" 0 || true
  passwall_download_latest_pkg "passwall_packages" "dns2socks" 0 || true
  passwall_download_latest_pkg "passwall_packages" "microsocks" 0 || true
  passwall_download_latest_pkg "passwall_packages" "tcping" 0 || true
  passwall_download_latest_pkg "passwall_packages" "ipt2socks" 0 || true

  if [ "$with_ssr" -eq 1 ]; then
    passwall_download_latest_pkg "passwall_packages" "shadowsocksr-libev-ssr-check" 0 || true
    passwall_download_latest_pkg "passwall_packages" "shadowsocksr-libev-ssr-local" 0 || true
    passwall_download_latest_pkg "passwall_packages" "shadowsocksr-libev-ssr-redir" 0 || true
  fi

  if [ "$with_obfs" -eq 1 ]; then
    passwall_download_latest_pkg "passwall_packages" "simple-obfs-client" 0 || true
  fi

  if [ "$with_naive" -eq 1 ]; then
    passwall_download_latest_pkg "passwall_packages" "naiveproxy" 0 || true
  fi

  echo
  echo "已下载的安装包:"
  ls -1 ./*.ipk 2>/dev/null || true

  if [ "$install_after_download" -eq 1 ]; then
    echo
    green "开始安装 PassWall 1..."
    opkg install ./*.ipk
    /etc/init.d/uhttpd restart 2>/dev/null || true
    green "完成。请刷新 LuCI 页面查看 PassWall 菜单。"
  else
    echo
    yellow "已下载但未安装。后续可执行:"
    echo "cd $PASSWALL_DEST_DIR && opkg install ./*.ipk"
  fi
}

show_main_menu() {
  gl_name="$(get_router_name)"
  clear
  echo "***********************************************************************"
  echo "*                                                                     *"
  echo "*        GL-iNet 路由器一键安装工具箱 + PassWall 1                    *"
  echo "*                                                                     *"
  echo "***********************************************************************"
  green "当前路由器型号: $gl_name"
  echo
  echo "支持以下操作:"
  magenta " A. 自动检测并运行 GL-iNet 工具箱脚本 (推荐)"
  magenta " B. 手动选择 GL-iNet 机型"
  magenta " P. 安装 PassWall 1 for GL-MT3000"
  echo
  echo " Q. 退出"
  echo
}

while true; do
  show_main_menu
  read -r -p "请输入选项: " main_choice
  case "$main_choice" in
    a|A) auto_detect_and_run ;;
    b|B) select_model ;;
    p|P) install_passwall1 ;;
    q|Q) echo "退出"; exit 0 ;;
    *) red "无效选项，请重新选择" ;;
  esac
  echo
  read -r -p "按 Enter 键返回主菜单..." _
done
