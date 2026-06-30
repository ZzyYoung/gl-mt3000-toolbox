# GL-iNet toolbox with PassWall 1

This script keeps the original wkdaily GL-iNet toolbox launcher and adds a
PassWall 1 installer for GL-MT3000 / aarch64_cortex-a53.

## One-line install

After uploading `gl_toolbox_with_passwall1.sh` to GitHub, run this on the
OpenWrt router:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/<user>/<repo>/main/gl_toolbox_with_passwall1.sh)"
```

Replace `<user>` and `<repo>` with your GitHub account and repository name.

## Menu

- `A`: auto-detect router model and run the original GL-iNet toolbox script
- `B`: manually choose a GL-iNet model
- `P`: install PassWall 1 for GL-MT3000
- `Q`: quit

## PassWall package source

The PassWall 1 installer downloads packages from:

```text
https://sourceforge.net/projects/openwrt-passwall-build/files/releases/packages-21.02/aarch64_cortex-a53/
```

It installs the LuCI package, Chinese translation, common DNS helpers, geo data,
`microsocks`, `tcping`, and `ipt2socks`. SSR, simple-obfs, and NaiveProxy are
available from the interactive PassWall menu.
