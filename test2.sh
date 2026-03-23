#!/bin/bash

# CONFIG
TG_BOT_TOKEN="8614247175:AAHQzSIbrgB1pNXQ-J2vyUsQUbpOWvQ_6Qc"
TG_BUILD_CHAT_ID="-1001989043437"
DEVICE_CODE="spartan"
BUILD_TARGET="Evolution-X"
ANDROID_VERSION="16.2"

export TZ="Asia/Kolkata"

# TELEGRAM BASIC
send_telegram() {
  local message="$1"
  curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TG_BUILD_CHAT_ID}" \
    -d "text=${message}" \
    -d "parse_mode=HTML" > /dev/null
}

send_telegram_button() {
  local text="$1"
  local url="$2"

  curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TG_BUILD_CHAT_ID}" \
    -d "text=${text}" \
    -d "parse_mode=HTML" \
    -d "reply_markup={\"inline_keyboard\":[[{\"text\":\"⬇️ Download ROM\",\"url\":\"$url\"}]]}" > /dev/null
}

# PROGRESS BAR
generate_bar() {
  local percent=$1
  local total=20
  local filled=$((percent * total / 100))
  local empty=$((total - filled))

  printf "["
  for ((i=0;i<filled;i++)); do printf "█"; done
  for ((i=0;i<empty;i++)); do printf "░"; done
  printf "]"
}

# ETA CALC
estimate_eta() {
  local percent=$1
  local elapsed=$2

  if (( percent > 0 )); then
    total=$((elapsed * 100 / percent))
    remaining=$((total - elapsed))
    printf "%02dh %02dm" $((remaining/3600)) $(( (remaining%3600)/60 ))
  else
    echo "--"
  fi
}

# PROGRESS MESSAGE
send_or_edit_progress() {
  local percent="$1"
  local elapsed="$2"

  BAR=$(generate_bar "$percent")
  ETA=$(estimate_eta "$percent" "$elapsed")

  TEXT="📊 <b>Build Progress:</b> ${percent}%
${BAR}
⏱️ ETA: ~${ETA}"

  if [[ -z "$PROGRESS_MSG_ID" ]]; then
    RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TG_BUILD_CHAT_ID}" \
      -d "text=${TEXT}" \
      -d "parse_mode=HTML")

    PROGRESS_MSG_ID=$(echo "$RESPONSE" | grep -oP '"message_id":\K[0-9]+')
  else
    curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/editMessageText" \
      -d "chat_id=${TG_BUILD_CHAT_ID}" \
      -d "message_id=${PROGRESS_MSG_ID}" \
      -d "text=${TEXT}" \
      -d "parse_mode=HTML" > /dev/null
  fi
}

# MAIN
START_TIME=$(date +%s)

send_telegram "⚙️ <b>Build Started</b>
<b>ROM:</b> $BUILD_TARGET
<b>Device:</b> $DEVICE_CODE"

repo init -u https://github.com/Evolution-X/manifest -b bq2 --depth=1
repo sync -c -j$(nproc --all)

. build/envsetup.sh
lunch lineage_spartan-bp4a-user

# BUILD
BUILD_LOG=build.log
: > $BUILD_LOG

(
  m evolution -j$(nproc --all) 2>&1 | tee $BUILD_LOG
) &

PID=$!
LAST=0

while kill -0 $PID 2>/dev/null; do
  PERCENT=$(grep -oP '\[\s*\K[0-9]+(?=%)' $BUILD_LOG | tail -n 1)

  NOW=$(date +%s)
  ELAPSED=$((NOW - START_TIME))

  if [[ ! -z "$PERCENT" ]]; then
    if (( PERCENT >= LAST + 3 )); then
      send_or_edit_progress "$PERCENT" "$ELAPSED"
      LAST=$PERCENT
    fi
  fi

  sleep 15
done

wait $PID
STATUS=$?

END=$(date +%s)
DUR=$((END - START_TIME))

if [[ $STATUS -eq 0 ]]; then
  send_telegram "✅ <b>Build Finished</b>
Duration: $((DUR/60)) min"
else
  send_telegram "❌ <b>Build Failed</b>"
fi

# UPLOAD
if [[ $STATUS -eq 0 ]]; then
  wget -q https://raw.githubusercontent.com/chime-A13/tools-gofile/refs/heads/private/go-up
  chmod +x go-up

  ZIP=$(ls out/target/product/spartan/*.zip | head -n1)

  OUT=$(./go-up "$ZIP")
  LINK=$(echo "$OUT" | grep -Eo 'https?://[^ ]+' | head -n1)

  send_telegram_button "📦 <b>Build Uploaded</b>" "$LINK"
fi
