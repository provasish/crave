#!/bin/bash

# =========================================================
# CONFIG
# =========================================================
TG_BOT_TOKEN="8614247175:AAHQzSIbrgB1pNXQ-J2vyUsQUbpOWvQ_6Qc"
TG_BUILD_CHAT_ID="-1001989043437"
DEVICE_CODE="spartan"
BUILD_TARGET="Evolution-X"
ANDROID_VERSION="16.2"

export TZ="Asia/Kolkata"

# =========================================================
# TELEGRAM
# =========================================================
send_telegram() {
  local message="$1"
  curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TG_BUILD_CHAT_ID}" \
    -d "text=${message}" \
    -d "parse_mode=HTML" \
    -d "disable_web_page_preview=true" > /dev/null
}

send_telegram_button() {
  local text="$1"
  local url="$2"

  curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TG_BUILD_CHAT_ID}" \
    -d "text=${text}" \
    -d "parse_mode=HTML" \
    -d "reply_markup={\"inline_keyboard\":[[{\"text\":\"⬇️ Download ROM\",\"url\":\"$url\"}]]}" \
    -d "disable_web_page_preview=true" > /dev/null
}

# =========================================================
# PROGRESS BAR + ETA
# =========================================================
generate_bar() {
  local percent=$1
  local total=20
  local filled=$((percent * total / 100))
  local empty=$((total - filled))

  printf "["
  for ((i=0;i<filled;i++)); do printf "#"; done
  for ((i=0;i<empty;i++)); do printf "-"; done
  printf "]"
}

estimate_eta() {
  local percent=$1
  local elapsed=$2

  if (( percent >= 99 )); then
    echo "Done"
    return
  fi

  if (( percent > 0 )); then
    total=$((elapsed * 100 / percent))
    remaining=$((total - elapsed))
    printf "%02dh %02dm" $((remaining/3600)) $(( (remaining%3600)/60 ))
  else
    echo "--"
  fi
}

# =========================================================
# EDITABLE PROGRESS MESSAGE
# =========================================================
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

# =========================================================
# TIME FORMAT
# =========================================================
format_duration() {
  local T=$1
  printf "%02d min %02d sec" $((T/60)) $((T%60))
}

# =========================================================
# MAIN
# =========================================================
start_build_process() {

  START_TIME=$(date +%s)

  send_telegram "⚙️ <b>ROM Build Started</b>
<b>ROM:</b> $BUILD_TARGET
<b>Android:</b> $ANDROID_VERSION
<b>Device:</b> $DEVICE_CODE"

  # =========================================================
  # SYNC
  # =========================================================
  repo init -u https://github.com/Evolution-X/manifest -b bq2 --depth=1
  repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags

  # =========================================================
  # SETUP
  # =========================================================
  . build/envsetup.sh
  lunch lineage_spartan-bp4a-user

  # =========================================================
  # BUILD WITH PROGRESS
  # =========================================================
  BUILD_LOG=build.log
  : > $BUILD_LOG

  (
    m evolution -j$(nproc --all) 2>&1 | tee $BUILD_LOG
  ) &

  BUILD_PID=$!
  LAST_PERCENT=0

  while kill -0 $BUILD_PID 2>/dev/null; do
    PERCENT=$(grep -oP '\[\s*\K[0-9]+(?=%)' $BUILD_LOG | tail -n 1)

    NOW=$(date +%s)
    ELAPSED=$((NOW - START_TIME))

    if [[ ! -z "$PERCENT" ]]; then
      if (( PERCENT >= LAST_PERCENT + 3 )); then
        send_or_edit_progress "$PERCENT" "$ELAPSED"
        LAST_PERCENT=$PERCENT
      fi
    fi

    sleep 15
  done

  wait $BUILD_PID
  BUILD_STATUS=$?

  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  # =========================================================
  # RESULT
  # =========================================================
  if [[ $BUILD_STATUS -eq 0 ]]; then
    send_telegram "✅ <b>Build Finished</b>
<b>Duration:</b> $(format_duration $DURATION)"
  else
    send_telegram "❌ <b>Build Failed</b>"
    exit 1
  fi

  # =========================================================
  # UPLOAD
  # =========================================================
  wget -q https://raw.githubusercontent.com/chime-A13/tools-gofile/refs/heads/private/go-up
  chmod +x go-up

  ZIP_FILE=$(ls out/target/product/spartan/Evolution*spartan*.zip 2>/dev/null | head -n 1)

  if [[ -z "$ZIP_FILE" ]]; then
    send_telegram "❌ <b>No ZIP found to upload</b>"
    exit 1
  fi

  UPLOAD_OUTPUT=$(./go-up "$ZIP_FILE" 2>&1)

  echo "$UPLOAD_OUTPUT"

  # 🔥 FIXED LINK EXTRACTION
  UPLOAD_LINK=$(echo "$UPLOAD_OUTPUT" | grep -oP '(?<=Link: ).*')

  # fallback if format different
  if [[ -z "$UPLOAD_LINK" ]]; then
    UPLOAD_LINK=$(echo "$UPLOAD_OUTPUT" | grep 'gofile.io' | tail -n 1)
  fi

  if [[ -n "$UPLOAD_LINK" ]]; then
    send_telegram_button "📦 <b>Build Uploaded</b>
<b>ROM:</b> $BUILD_TARGET
<b>Device:</b> $DEVICE_CODE" "$UPLOAD_LINK"
  else
    send_telegram "❌ <b>Upload failed</b>
<pre>$UPLOAD_OUTPUT</pre>"
  fi
}

# =========================================================
# RUN
# =========================================================
start_build_process
