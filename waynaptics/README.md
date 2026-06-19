# waynaptics (touchpad driver)

[waynaptics](https://github.com/kekekeks/waynaptics) ports the classic X11
`xf86-input-synaptics` touchpad driver to Wayland. A root daemon grabs the
touchpad's evdev device and re-emits it as a virtual mouse via `/dev/uinput`,
giving synaptics-style behaviour (acceleration, edge/two-finger scrolling,
click zones, tap actions) under Hyprland.

This directory is a self-contained Arch package recipe. It is **not** a stow
package and is intentionally left out of the top-level `install.sh` stow list.

## Install

```bash
./install.sh          # = makepkg -sif, then pacman installs it
```

The post-install hook enables **and starts** `waynaptics.service`, so the
touchpad is driven by waynaptics immediately and on every boot.

GUI configuration tool:

```bash
waynaptics-config
```

## Uninstall / rollback

```bash
sudo pacman -Rns waynaptics
```

This stops + disables the service and removes every installed file (pacman owns
them). Your touchpad reverts to normal libinput handling on next login/reboot.
Temporarily stop it instead with `sudo systemctl disable --now waynaptics`.

## Notes / gotchas

- **Device matching:** the service runs with `--device-name Touchpad`, a
  substring match on evdev names. On this ThinkPad it uniquely matches
  `ELAN0676:00 04F3:3195 Touchpad` (event8). If you move to a laptop whose
  touchpad name lacks "Touchpad", edit `ExecStart` in `waynaptics.service`.
- **`-fpermissive`:** the PKGBUILD adds this because upstream `synaptics.c`
  trips GCC 14+'s `-Werror=incompatible-pointer-types`. Upstream CI builds on
  Debian 12 (GCC 12) where it is only a warning. The affected code is the stock
  `InputDriverRec` registration struct — functionally unchanged.
- **Pinned commits:** waynaptics `de8c112`, xf86-input-synaptics `42ac305`.
  These are the exact revisions inspected for safety and tested on this machine.
- **Scroll direction:** the virtual device looks like a generic mouse, so
  Hyprland's `touchpad { natural_scroll }` no longer applies to it. waynaptics
  has its own scroll handling; tweak in `waynaptics-config` if direction/speed
  feels off.
- **Safety:** the control socket is local-only (`AF_UNIX`, `/var/run/waynaptics.sock`),
  no network code. It is world-accessible (chmod 0666) so the unprivileged GUI
  can reach the root daemon; on a single-user machine this is fine. See the
  full inspection notes in `~/waynaptics-setup/INSTALL_LOG.md`.
