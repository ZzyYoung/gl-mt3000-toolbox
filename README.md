# GL-MT3000 toolbox with PassWall 1

This repository contains two workflows:

- a recommended offline bundle flow where your Mac downloads the latest files,
  copies them to the router, and the router installs everything locally
- an online router menu that keeps the original wkdaily GL-iNet toolbox launcher
  and adds PassWall 1 helpers

## Recommended offline flow

Run this on your Mac:

```sh
sh prepare_gl_mt3000_offline_bundle.sh
```

Then SSH into the router and install from the uploaded bundle:

```sh
ssh root@192.168.8.1
sh /tmp/gl-mt3000-toolbox/install_gl_mt3000_offline_bundle.sh
```

The Mac script downloads the current upstream proxy cores, the current PassWall
IPK packages for `aarch64_cortex-a53`, and copies everything to:

```text
/tmp/gl-mt3000-toolbox
```

To use another router address:

```sh
sh prepare_gl_mt3000_offline_bundle.sh --router root@192.168.8.1
```

To also download optional NaiveProxy/SSR/simple-obfs packages:

```sh
sh prepare_gl_mt3000_offline_bundle.sh --with-optional
```

## Online router menu

If the router can access GitHub and SourceForge directly, you can still run:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ZzyYoung/gl-mt3000-toolbox/passwall-toolbox/gl_toolbox_with_passwall1.sh)"
```

Menu:

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

## Proxy cores and data

The offline Mac script resolves latest releases at runtime:

- sing-box official `linux-arm64-musl`
- Xray-core official `linux-arm64-v8a`
- Hysteria official `hysteria-linux-arm64`

GeoIP and Geosite are installed as PassWall packages. `GeoView` is not included
as a separate package because it is not published in the current PassWall
`aarch64_cortex-a53` package directory.
