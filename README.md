# tempwatch

A single-file bash temperature monitor for Linux servers. Reads CPU, board, NIC,
NVMe and SATA sensors, lays them out side by side in the terminal, and pings
Telegram when something actually changes state.

```
nas  2026-02-14 21:40:07
up 6 days, 3 hours, load 0.42 0.51 0.55

  DISKS                                           BOARD
  sda  ACME HD4000-A               36.0°C OK      it8688 temp1                     30.0°C OK
  sdb  ACME HD4000-A               35.0°C OK      it8688 temp2                     38.0°C OK
  sdc  ACME HD8000-B               41.0°C OK      it8688 temp3                     44.0°C OK
  sdd  ACME HD8000-B               39.0°C OK      it8688 temp4                     33.0°C OK
  sde  ACME HD12000-C              49.0°C OK      it8688 temp5                     27.0°C OK
  sdf  ACME HD12000-C              46.0°C OK      it8688 temp6                     46.0°C OK
  sdg  ACME HD4000-A               34.0°C OK
  sdh  ACME HD16000-D              43.0°C OK      CPU
  sdi  ACME HD16000-D              44.0°C OK      Tctl                             45.2°C OK
  sdj  ACME HD8000-B               38.0°C OK      Tccd1                            43.8°C OK
  sdk  ACME HD12000-C              47.0°C OK
  sdl  ACME HD4000-A                 --   idle    NVMe
                                                  nvme0n1  ACME NV1000-X           34.9°C OK
  NETWORK                                         nvme1n1  ACME NV2000-Y           38.9°C OK
  r8169 temp1                      42.5°C OK
                                                  FANS
                                                  fan3  chassis / drive array      1038 rpm

   All clear — hottest 49°C (sde  ACME HD12000-C)
```

The layout adapts to your terminal: one column under ~78 chars, two up to ~115,
three beyond that. A 12-drive box fits on one screen instead of scrolling.

## Why

`sensors` tells you the numbers. `tempwatch` tells you whether they're a problem,
keeps SATA drives in the same picture as the CPU, and shouts once when a fan
stops — rather than every five minutes forever.

## What it does

- **One picture.** hwmon sysfs (CPU/board/NIC/NVMe) plus `smartctl` for SATA/SAS,
  in one grouped view.
- **Never wakes a sleeping disk.** Uses `smartctl -n standby`; spun-down drives
  show as `idle`, and are not alerted on.
- **Per-drive NVMe limits.** NVMe drives report their own warn/crit points and
  those win over the configured fallback.
- **Fan monitoring that isn't noise.** Empty fan headers read 0 rpm forever, so a
  header is only watched once it has been seen spinning. A 0 after that is a real
  stopped fan.
- **Alerts on state change, not on schedule.** Cron mode is silent until
  something crosses a threshold, then silent again until it changes back.

## Requirements

- Linux with `/sys/class/hwmon` (any kernel that has `lm-sensors` working)
- `bash` 4.3+, `awk`, `curl`
- `smartctl` + `jq` — optional, only for SATA/SAS disk temps
- Fan RPM needs a Super-I/O driver: `it87` (many Gigabyte/ASRock boards),
  `nct6775`, and so on. Without one you still get every temperature.

## Install

```sh
git clone https://github.com/pklooster/tempwatch
cd tempwatch
sudo ./install.sh
```

Installs to `/usr/local/bin` and seeds `~/.config/tempwatch/`. Use
`PREFIX=~/.local ./install.sh` for a user install, `./install.sh --uninstall`
to remove it. Or just copy the `tempwatch` file anywhere on your `PATH` — it has
no other moving parts.

## Usage

| Command | What it does |
| --- | --- |
| `tempwatch` | one-shot readout |
| `tempwatch -w [secs]` | live view, default 5s refresh |
| `tempwatch -c` | check mode: silent unless state changed, pings Telegram |
| `tempwatch -j` | JSON, one object per sensor |
| `tempwatch -t` | send a test Telegram message |
| `tempwatch -V` | version |

Exit codes for `-c` and the default view: `0` all clear, `1` something is warm,
`2` something is critical. Handy in a healthcheck.

Set `TEMPWATCH_COLS=160` to override terminal-width detection, which is useful
for screenshots and for `watch`-style wrappers that don't pass a tty.

## Configuration

Everything lives in `~/.config/tempwatch/` (override with `TEMPWATCH_CFG`).

**`thresholds.conf`** — warn/crit per sensor group, sourced as shell. See
[`examples/thresholds.conf`](examples/thresholds.conf). Changes apply on the next
run; there is no daemon to restart.

The defaults are deliberately conservative. Set `HDD_WARN` to just above what
your array actually idles at — a threshold that fires every night is a threshold
you'll learn to ignore.

**`fans.conf`** — fan headers are board-specific, and which one is the CPU fan
differs per model. Name them so an alert is readable:

```
it8688.fan3 = chassis / drive array
it8688.fan5 = CPU
```

Find yours with `grep . /sys/class/hwmon/hwmon*/fan*_input`. Unnamed headers fall
back to their raw sysfs name.

**`telegram.env`** — bot credentials, `chmod 600`:

```sh
TELEGRAM_BOT_TOKEN=123456789:AA...
TELEGRAM_CHAT_ID=-1001234567890
```

Already have these somewhere else? Point at them from `thresholds.conf` with
`ENV_FILE=/path/to/telegram.env` instead of keeping a second copy.

Without credentials everything still works — alerts print to stdout instead.

## Alerting

```sh
sudo cp examples/tempwatch.cron /etc/cron.d/tempwatch    # every 5 minutes
```

Check mode compares against the previous run's state in
`~/.config/tempwatch/state.txt` and only sends when a sensor changes state:

```
🌡️ nas temperature
🔥 CRITICAL: sde  ACME HD12000-C 59.0°C (crit 58°C)
🛑 FAN STOPPED: fan5  CPU — 0 rpm
```

While a sensor stays critical it re-pings every `CRIT_REPEAT` seconds (default
30 minutes) so a real problem doesn't scroll away, then sends a `✅ back to
normal` when it clears.

## Notes

- Board sensor labels are whatever your Super-I/O chip exposes, which is often
  `temp1`…`temp6` with no clue which is the VRM. Watch them for a few days
  before setting a threshold you trust.
- `acpitz` reads a fixed nonsense value on a lot of boards, so it is hidden by
  default. `SHOW_ACPITZ=1` brings it back.
- On Gigabyte boards, `gigabyte_wmi` duplicates the IT86xx/IT87xx sensors over
  WMI. tempwatch prefers the real driver when it's loaded.

## License

MIT — see [LICENSE](LICENSE).
