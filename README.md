# GL-iNet toolbox with PassWall 1

This script keeps the original wkdaily GL-iNet toolbox launcher and adds a
PassWall 1 installer for GL-MT3000 / aarch64_cortex-a53.

## One-line install

Run this on the OpenWrt router:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ZzyYoung/gl-mt3000-toolbox/passwall-toolbox/gl_toolbox_with_passwall1.sh)"
```

## Menu

- `A`: auto-detect router model and run the original GL-iNet toolbox script
- `B`: manually choose a GL-iNet model
- `P`: install PassWall 1 for GL-MT3000
- `C`: install/update PassWall proxy cores: sing-box, Xray, and Hysteria
- `Q`: quit

## PassWall package source

The PassWall 1 installer downloads packages from:

```text
https://sourceforge.net/projects/openwrt-passwall-build/files/releases/packages-21.02/aarch64_cortex-a53/
```

It installs the LuCI package, Chinese translation, common DNS helpers, geo data,
`microsocks`, `tcping`, and `ipt2socks`. SSR, simple-obfs, and NaiveProxy are
available from the interactive PassWall menu.

## Proxy cores

The core installer currently uses these official upstream releases:

- sing-box `1.13.14`
- Xray-core `26.3.27`
- Hysteria `2.9.3`

GeoIP and Geosite are installed as PassWall packages. `GeoView` is not included
as a separate package because it is not published in the current PassWall
`aarch64_cortex-a53` package directory.
