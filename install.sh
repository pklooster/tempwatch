#!/bin/bash
# tempwatch installer — copies the script to PREFIX and seeds a config dir.
#   ./install.sh                 install to /usr/local/bin
#   PREFIX=~/.local ./install.sh install somewhere else
#   ./install.sh --uninstall     remove the script (config is left alone)
set -euo pipefail

PREFIX="${PREFIX:-/usr/local}"
BIN="$PREFIX/bin"
CFG="${TEMPWATCH_CFG:-${XDG_CONFIG_HOME:-$HOME/.config}/tempwatch}"
SRC="$(cd "$(dirname "$0")" && pwd)"

if [ "${1:-}" = "--uninstall" ]; then
  rm -f "$BIN/tempwatch"
  echo "removed $BIN/tempwatch (config in $CFG left in place)"
  exit 0
fi

install -d "$BIN"
install -m 0755 "$SRC/tempwatch" "$BIN/tempwatch"
echo "installed $BIN/tempwatch"

install -d "$CFG"
for f in thresholds.conf fans.conf; do
  if [ ! -e "$CFG/$f" ]; then
    install -m 0644 "$SRC/examples/$f" "$CFG/$f"
    echo "seeded  $CFG/$f"
  else
    echo "kept    $CFG/$f (already exists)"
  fi
done

echo
missing=""
for c in awk curl; do command -v "$c" >/dev/null 2>&1 || missing="$missing $c"; done
[ -n "$missing" ] && echo "! required, not found:$missing"
opt=""
for c in smartctl jq; do command -v "$c" >/dev/null 2>&1 || opt="$opt $c"; done
[ -n "$opt" ] && echo "  optional, not found:$opt  (SATA/SAS disk temps will be skipped)"
lsmod 2>/dev/null | grep -qE '^(it87|nct6775|nct6683) ' || \
  echo "  no fan driver loaded — fan RPM needs it87/nct6775 for many boards"

cat <<TXT

Next:
  tempwatch                 one-shot readout
  tempwatch -w              live view
  \$EDITOR $CFG/thresholds.conf

For Telegram alerts, add credentials and wire up cron:
  cp $SRC/examples/telegram.env.example $CFG/telegram.env
  chmod 600 $CFG/telegram.env
  tempwatch -t              send a test message
  cp $SRC/examples/tempwatch.cron /etc/cron.d/tempwatch
TXT
