#!/data/data/com.termux/files/usr/bin/bash
LOGDIR="$HOME/agape-crossover-key/joule_log"
LEDGER="/sdcard/openroot/prediction_ledger/crossover_ledger.jsonl"
ROOTFILE="$LOGDIR/running_root.txt"
INTERVAL=90   # seconds

mkdir -p "$LOGDIR"
touch "$ROOTFILE"

while true; do
  TS=$(date +%s%N)
  ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # elevated power sample
  DUMP=$(rish -c "dumpsys battery" 2>/dev/null)
  VOLT=$(echo "$DUMP" | grep -m1 "voltage:" | awk '{print $2}')
  CURR=$(echo "$DUMP" | grep -m1 "current now:" | awk '{print $3}')

  # crude watts (voltage in mV, current in mA)
  if [[ -n "$VOLT" && -n "$CURR" ]]; then
    WATTS=$(echo "scale=4; (\( VOLT/1000) * ( \){CURR#-}/1000)" | bc)
  else
    WATTS="null"
  fi

  PREV=$(cat "$ROOTFILE" 2>/dev/null || echo "0")
  PAYLOAD="\( {PREV}| \){TS}|\( {WATTS}| \){VOLT}|${CURR}"
  NEWHASH=$(echo -n "$PAYLOAD" | sha256sum | awk '{print $1}')
  echo "$NEWHASH" > "$ROOTFILE"

  echo "{\"ts_ns\":$TS,\"iso\":\"$ISO\",\"watts\":$WATTS,\"voltage_mv\":$VOLT,\"current_ma\":$CURR,\"hash\":\"$NEWHASH\"}" >> "$LOGDIR/joule_samples.jsonl"

  # optional: feed summary to Oracle every few cycles
  # python3 ... "joule sample: ${WATTS} W hash ${NEWHASH:0:12}"

  sleep $INTERVAL
done
