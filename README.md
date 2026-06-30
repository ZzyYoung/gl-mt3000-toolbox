# GL-MT3000 toolbox with PassWall

This repository contains two workflows:

- a recommended offline bundle flow where your Mac downloads the latest files,
  copies them to the router, and the router installs everything locally
- an online router menu that keeps the original wkdaily GL-iNet toolbox launcher
  and adds PassWall helpers

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

The Mac script downloads the current upstream proxy cores, PassWall 1 and
PassWall 2 LuCI packages, shared dependency IPKs for `aarch64_cortex-a53`, and
copies everything to:

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

The router-side installer asks which PassWall version to install. The default is
PassWall 2, which is recommended when testing sing-box, Hysteria2, and newer
Reality-style nodes. It stops/disables the other PassWall service before
starting the selected one.

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

The offline installer downloads packages from:

```text
https://sourceforge.net/projects/openwrt-passwall-build/files/releases/packages-21.02/aarch64_cortex-a53/
```

It installs the selected LuCI package, Chinese translation, common DNS helpers,
geo data, `geoview`, `microsocks`, `tcping`, and `ipt2socks`. SSR,
simple-obfs, and NaiveProxy can be included with `--with-optional`.

## Proxy cores and data

The offline Mac script resolves latest releases at runtime:

- sing-box official `linux-arm64-musl`
- Xray-core official `linux-arm64-v8a`
- Hysteria official `hysteria-linux-arm64`

GeoIP and Geosite are installed as PassWall packages. PassWall 2 also depends
on `geoview`; when it is missing from the OpenWrt 21.02 package directory, the
offline script downloads the same-architecture fallback from the OpenWrt 23.05
PassWall package directory and copies it to the router with the rest of the
offline bundle.
