#!/bin/bash

# =========================================================
# CONFIGURATION
# =========================================================
TG_BOT_TOKEN="8614247175:AAHQzSIbrgB1pNXQ-J2vyUsQUbpOWvQ_6Qc"
TG_BUILD_CHAT_ID="-1003529010804"
DEVICE_CODE="spartan"
BUILD_TARGET="Evolution-X"
ANDROID_VERSION="16.2"

export TZ="Asia/Kolkata"
export BUILD_USERNAME=hunt3r
export BUILD_HOSTNAME=pro

# =========================================================
# TELEGRAM FUNCTIONS
# =========================================================

# Normal message
send_telegram() {
  local message="$1"

  curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TG_BUILD_CHAT_ID}" \
    -d "text=${message}" \
    -d "parse_mode=HTML" \
    -d "disable_web_page_preview=true" > /dev/null
}

# Message with button
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
# TIME FORMAT
# =========================================================
format_duration() {
    local T=$1
    local H=$((T/3600))
    local M=$(( (T%3600)/60 ))
    local S=$((T%60))
    printf "%02d hours, %02d minutes, %02d seconds" $H $M $S
}

# =========================================================
# BUILD FUNCTION
# =========================================================
start_build_process() {

    START_TIME=$(date +%s)

    # 🔔 START MESSAGE
    send_telegram "⚙️ <b>ROM Build Started!</b>
<b>ROM:</b> $BUILD_TARGET
<b>Android:</b> $ANDROID_VERSION
<b>Device:</b> $DEVICE_CODE
<b>Start Time:</b> $(date '+%Y-%m-%d %H:%M:%S %Z')"

    # =========================================================
    # BUILD STEPS
    # =========================================================

    repo init -u https://github.com/Evolution-X/manifest -b bq2 --git-lfs --depth=1
    /opt/crave/resync.sh
    repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags

    rm -rf device/realme vendor/realme kernel/realme hardware/oplus hardware/dolby
    rm -rf out/target/product/spartan
    rm -rf vendor/*priv* vendor/evolution/*priv* vendor/*lineage-priv*

    git clone https://github.com/EvoX-Spartan/android_device_realme_spartan device/realme/spartan
    git clone https://github.com/EvoX-Spartan/android_device_realme_sm8250-common device/realme/sm8250-common
    git clone https://github.com/EvoX-Spartan/proprietary_vendor_realme_spartan vendor/realme/spartan
    git clone https://github.com/EvoX-Spartan/proprietary_vendor_realme_sm8250-common vendor/realme/sm8250-common --depth=1
    git clone https://github.com/EvoX-Spartan/android_kernel_realme_sm8250 -b bka kernel/realme/sm8250 --depth=1
    git clone https://github.com/EvoX-Spartan/hardware_dolby hardware/dolby --depth=1
    git clone https://github.com/EvoX-Spartan/android_hardware_oplus hardware/oplus
    git clone https://gitlab.com/provasishh/proprietary_vendor_oplus_camera.git vendor/oplus/camera --depth=1

    git clone https://github.com/Evolution-X/vendor_evolution-priv_keys-template vendor/evolution-priv/keys --depth 1
    chmod +x vendor/evolution-priv/keys/keys.sh
    pushd vendor/evolution-priv/keys
    ./keys.sh
    popd

    . build/envsetup.sh
    lunch lineage_spartan-bp4a-user

    m evolution -j$(nproc --all)
    BUILD_STATUS=$?

    # =========================================================
    # BUILD RESULT
    # =========================================================

    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    DURATION_FORMATTED=$(format_duration $DURATION)

    if [[ $BUILD_STATUS -eq 0 ]]; then
        status_icon="✅"
        status_text="Success"
    else
        status_icon="❌"
        status_text="Failed"
    fi

    send_telegram "${status_icon} <b>Build Finished!</b>
<b>ROM:</b> $BUILD_TARGET
<b>Android:</b> $ANDROID_VERSION
<b>Device:</b> $DEVICE_CODE
<b>Duration:</b> $DURATION_FORMATTED
<b>Status:</b> $status_text"

    # =========================================================
    # UPLOAD SECTION
    # =========================================================

    if [[ $BUILD_STATUS -eq 0 ]]; then

        rm -rf go-up*
        wget -q https://raw.githubusercontent.com/chime-A13/tools-gofile/refs/heads/private/go-up
        chmod +x go-up

        echo "Uploading build..."

        ZIP_FILE=$(ls out/target/product/spartan/Evolution*spartan*.zip 2>/dev/null | head -n 1)

        if [[ -z "$ZIP_FILE" ]]; then
            send_telegram "❌ <b>No ZIP found to upload!</b>"
            exit 1
        fi

        UPLOAD_OUTPUT=$(./go-up "$ZIP_FILE" 2>&1)

        echo "$UPLOAD_OUTPUT"

        UPLOAD_LINK=$(echo "$UPLOAD_OUTPUT" | grep -Eo 'https?://[^ ]+' | head -n 1)

        if [[ -n "$UPLOAD_LINK" ]]; then
            send_telegram_button "📦 <b>Build Uploaded!</b>
<b>ROM:</b> $BUILD_TARGET
<b>Device:</b> $DEVICE_CODE" "$UPLOAD_LINK"
        else
            send_telegram "❌ <b>Upload failed!</b>
<pre>$UPLOAD_OUTPUT</pre>"
        fi
    fi

    cat out/error.log
}

# =========================================================
# RUN
# =========================================================
start_build_process
