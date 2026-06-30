#!/bin/sh
set -eu

# Run this script on macOS/Linux. It downloads current GL-MT3000 PassWall
# packages and proxy cores locally, then copies an offline installer bundle to
# the OpenWrt router.

ROUTER="root@192.168.8.1"
REMOTE_DIR="/tmp/gl-mt3000-toolbox"
BUILD_DIR="/tmp/gl-mt3000-toolbox-bundle"
ARCH="aarch64_cortex-a53"
OPENWRT_SERIES="21.02"
SOURCEFORGE_BASE="https://sourceforge.net/projects/openwrt-passwall-build/files/releases/packages-${OPENWRT_SERIES}/${ARCH}"

WITH_OPTIONAL=0
UPLOAD_ONLY=0
NO_UPLOAD=0

usage() {
  cat <<EOF
Usage: sh $0 [options]

Options:
  --router USER@HOST    Router scp target. Default: ${ROUTER}
  --remote-dir DIR      Router destination directory. Default: ${REMOTE_DIR}
  --build-dir DIR       Local temporary build directory. Default: ${BUILD_DIR}
  --with-optional       Also download optional NaiveProxy/SSR/simple-obfs packages
  --upload-only         Reuse existing build dir and only upload it
  --no-upload           Download/build only, do not copy to router
  -h, --help            Show this help

Examples:
  sh $0
  sh $0 --router root@192.168.8.1 --with-optional
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --router)
      [ "$#" -ge 2 ] || { echo "Missing value for --router" >&2; exit 1; }
      ROUTER="$2"
      shift 2
      ;;
    --remote-dir)
      [ "$#" -ge 2 ] || { echo "Missing value for --remote-dir" >&2; exit 1; }
      REMOTE_DIR="$2"
      shift 2
      ;;
    --build-dir)
      [ "$#" -ge 2 ] || { echo "Missing value for --build-dir" >&2; exit 1; }
      BUILD_DIR="$2"
      shift 2
      ;;
    --with-optional)
      WITH_OPTIONAL=1
      shift
      ;;
    --upload-only)
      UPLOAD_ONLY=1
      shift
      ;;
    --no-upload)
      NO_UPLOAD=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

need_cmd curl
need_cmd scp
need_cmd ssh
need_cmd tar
need_cmd unzip
need_cmd python3

mkdir_clean() {
  rm -rf "$1"
  mkdir -p "$1"
}

github_asset_url() {
  repo="$1"
  match="$2"
  python3 - "$repo" "$match" <<'PY'
import json
import sys
import urllib.request

repo, match = sys.argv[1], sys.argv[2]
url = f"https://api.github.com/repos/{repo}/releases/latest"
with urllib.request.urlopen(url, timeout=30) as resp:
    data = json.load(resp)

for asset in data.get("assets", []):
    name = asset.get("name", "")
    if match in name:
        print(data.get("tag_name", ""))
        print(name)
        print(asset["browser_download_url"])
        raise SystemExit(0)

raise SystemExit(f"No asset matching {match!r} in {repo}")
PY
}

github_asset_field() {
  repo="$1"
  match="$2"
  field="$3"
  python3 - "$repo" "$match" "$field" <<'PY'
import json
import sys
import urllib.request

repo, match, field = sys.argv[1], sys.argv[2], sys.argv[3]
url = f"https://api.github.com/repos/{repo}/releases/latest"
with urllib.request.urlopen(url, timeout=30) as resp:
    data = json.load(resp)

for asset in data.get("assets", []):
    name = asset.get("name", "")
    if match in name:
        if field == "tag":
            print(data.get("tag_name", ""))
        elif field == "name":
            print(name)
        elif field == "url":
            print(asset["browser_download_url"])
        else:
            raise SystemExit(f"Unknown field: {field}")
        raise SystemExit(0)

raise SystemExit(f"No asset matching {match!r} in {repo}")
PY
}

download() {
  url="$1"
  out="$2"
  echo "[download] $out"
  curl -fL --retry 3 --retry-delay 2 -o "$out" "$url"
}

sf_latest_file() {
  subdir="$1"
  prefix="$2"
  html="$BUILD_DIR/index-${subdir}.html"
  url="${SOURCEFORGE_BASE}/${subdir}/"

  [ -s "$html" ] || curl -fsSL "$url" -o "$html"
  grep -oE "${prefix}_[A-Za-z0-9._+~:-]+_(all|${ARCH})\\.ipk" "$html" | sort -u | tail -n 1
}

download_sf_pkg() {
  subdir="$1"
  prefix="$2"
  dest_dir="${3:-$BUILD_DIR/ipk/common}"
  file="$(sf_latest_file "$subdir" "$prefix" || true)"

  if [ -z "$file" ]; then
    echo "[skip] cannot find ${prefix}_*.ipk"
    return 0
  fi

  mkdir -p "$dest_dir"
  download "${SOURCEFORGE_BASE}/${subdir}/${file}/download" "$dest_dir/$file"
}

download_proxy_cores() {
  mkdir -p "$BUILD_DIR/cores"

  sing_box_tag="$(github_asset_field "SagerNet/sing-box" "linux-arm64-musl.tar.gz" tag)"
  sing_box_name="$(github_asset_field "SagerNet/sing-box" "linux-arm64-musl.tar.gz" name)"
  sing_box_url="$(github_asset_field "SagerNet/sing-box" "linux-arm64-musl.tar.gz" url)"
  download "$sing_box_url" "$BUILD_DIR/$sing_box_name"
  mkdir_clean "$BUILD_DIR/sing-box-extract"
  tar -xzf "$BUILD_DIR/$sing_box_name" -C "$BUILD_DIR/sing-box-extract"
  find "$BUILD_DIR/sing-box-extract" -type f -name sing-box -exec cp {} "$BUILD_DIR/cores/sing-box" \;
  chmod +x "$BUILD_DIR/cores/sing-box"
  rm -rf "$BUILD_DIR/sing-box-extract" "$BUILD_DIR/$sing_box_name"

  xray_tag="$(github_asset_field "XTLS/Xray-core" "linux-arm64-v8a.zip" tag)"
  xray_name="$(github_asset_field "XTLS/Xray-core" "linux-arm64-v8a.zip" name)"
  xray_url="$(github_asset_field "XTLS/Xray-core" "linux-arm64-v8a.zip" url)"
  download "$xray_url" "$BUILD_DIR/$xray_name"
  mkdir_clean "$BUILD_DIR/xray-extract"
  unzip -o "$BUILD_DIR/$xray_name" -d "$BUILD_DIR/xray-extract" >/dev/null
  cp "$BUILD_DIR/xray-extract/xray" "$BUILD_DIR/cores/xray"
  chmod +x "$BUILD_DIR/cores/xray"
  rm -rf "$BUILD_DIR/xray-extract" "$BUILD_DIR/$xray_name"

  hysteria_tag="$(github_asset_field "apernet/hysteria" "hysteria-linux-arm64" tag)"
  hysteria_name="$(github_asset_field "apernet/hysteria" "hysteria-linux-arm64" name)"
  hysteria_url="$(github_asset_field "apernet/hysteria" "hysteria-linux-arm64" url)"
  download "$hysteria_url" "$BUILD_DIR/cores/hysteria"
  chmod +x "$BUILD_DIR/cores/hysteria"

  cat > "$BUILD_DIR/versions.txt" <<EOF
sing-box ${sing_box_tag} ${sing_box_name}
xray ${xray_tag} ${xray_name}
hysteria ${hysteria_tag} ${hysteria_name}
EOF
}

download_passwall_packages() {
  mkdir -p "$BUILD_DIR/ipk/common" "$BUILD_DIR/ipk/passwall1" "$BUILD_DIR/ipk/passwall2"

  download_sf_pkg "passwall_luci" "luci-app-passwall" "$BUILD_DIR/ipk/passwall1"
  download_sf_pkg "passwall_luci" "luci-i18n-passwall-zh-cn" "$BUILD_DIR/ipk/passwall1"
  download_sf_pkg "passwall2" "luci-app-passwall2" "$BUILD_DIR/ipk/passwall2"
  download_sf_pkg "passwall2" "luci-i18n-passwall2-zh-cn" "$BUILD_DIR/ipk/passwall2"

  download_sf_pkg "passwall_packages" "v2ray-geoip"
  download_sf_pkg "passwall_packages" "v2ray-geosite"
  download_sf_pkg "passwall_packages" "chinadns-ng"
  download_sf_pkg "passwall_packages" "dns2socks"
  download_sf_pkg "passwall_packages" "microsocks"
  download_sf_pkg "passwall_packages" "tcping"
  download_sf_pkg "passwall_packages" "ipt2socks"

  if [ "$WITH_OPTIONAL" -eq 1 ]; then
    download_sf_pkg "passwall_packages" "naiveproxy"
    download_sf_pkg "passwall_packages" "simple-obfs-client"
    download_sf_pkg "passwall_packages" "shadowsocksr-libev-ssr-check"
    download_sf_pkg "passwall_packages" "shadowsocksr-libev-ssr-local"
    download_sf_pkg "passwall_packages" "shadowsocksr-libev-ssr-redir"
  fi
}

write_manifest() {
  {
    echo "created_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "arch=${ARCH}"
    echo "openwrt_series=${OPENWRT_SERIES}"
    echo
    echo "[versions]"
    cat "$BUILD_DIR/versions.txt" 2>/dev/null || true
    echo
    echo "[ipk]"
    find "$BUILD_DIR/ipk" -type f -name '*.ipk' | sed "s#^$BUILD_DIR/ipk/##" | sort
  } > "$BUILD_DIR/manifest.txt"
}

if [ "$UPLOAD_ONLY" -eq 0 ]; then
  mkdir_clean "$BUILD_DIR"
  mkdir -p "$BUILD_DIR/ipk/common" "$BUILD_DIR/ipk/passwall1" "$BUILD_DIR/ipk/passwall2" "$BUILD_DIR/cores"

  download_proxy_cores
  download_passwall_packages
  cp "$(dirname "$0")/install_gl_mt3000_offline_bundle.sh" "$BUILD_DIR/install_gl_mt3000_offline_bundle.sh"
  chmod +x "$BUILD_DIR/install_gl_mt3000_offline_bundle.sh"
  write_manifest
  rm -f "$BUILD_DIR"/index-*.html "$BUILD_DIR/versions.txt"
fi

echo
if [ "$NO_UPLOAD" -eq 1 ]; then
  echo "[no-upload] Bundle prepared at: $BUILD_DIR"
  echo "To upload later:"
  echo "  sh $0 --upload-only"
  exit 0
fi

echo "[upload] $BUILD_DIR -> ${ROUTER}:${REMOTE_DIR}"
ssh "$ROUTER" "rm -rf '$REMOTE_DIR' && mkdir -p '$REMOTE_DIR'"
scp -r "$BUILD_DIR"/. "${ROUTER}:${REMOTE_DIR}/"

echo
echo "Done. The bundle was uploaded to the router, not to this Mac."
echo "Next run these commands:"
echo "  ssh ${ROUTER}"
echo "  sh ${REMOTE_DIR}/install_gl_mt3000_offline_bundle.sh"
