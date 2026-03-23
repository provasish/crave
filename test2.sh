#!/bin/bash

# =========================================================
# CONFIGURATION
# =========================================================
TG_BOT_TOKEN="8614247175:AAHQzSIbrgB1pNXQ-J2vyUsQUbpOWvQ_6Qc"
TG_BUILD_CHAT_ID="-1003529010804"
DEVICE_CODE="spartan"
BUILD_TARGET="Evolution-X"
ANDROID_VERSION="16.2"

# SHELL CONFIGURATION
export TZ="Asia/Kolkata"
export BUILD_USERNAME=hunt3r
export BUILD_HOSTNAME=pro

# =========================================================
# TELEGRAM FUNCTIONS
# =========================================================

send_telegram() {
  local chat_id="$1"
  local message="$2"

  local escaped_message=$(echo "$message" | sed \
    -e 's/\*/\*TEMP\*/g' \
    -e 's/_/\_TEMP\_/g' \
    -e 's/\[/\\[/g' \
    -e 's/\]/\\]/g' \
    -e 's/(/\\(/g' \
    -e 's/)/\\)/g' \
    -e 's/~/\\~/g' \
    -e 's/`/\`/g' \
    -e 's/>/\\>/g' \
    -e 's/#/\\#/g' \
    -e 's/+/\\+/g' \
    -e 's/-/\\-/g' \
    -e 's/=/\\=/g' \
    -e 's/|/\\|/g' \
    -e 's/{/\\{/g' \
    -e 's/}/\\}/g' \
    -e 's/\./\\./g' \
    -e 's/!/\\!/g')

  local re_escaped_message=$(echo "$escaped_message" | sed \
    -e 's/\*TEMP\*/\*/g' \
    -e 's/\_TEMP\_/\_/g')
  
  local encoded_message=$(echo "$re_escaped_message" | sed \
    -e 's/%/%25/g' \
    -e 's/&/%26/g' \
    -e 's/+/%2b/g' \
    -e 's/ /%20/g' \
    -e 's/\"/%22/g' \
    -e 's/'"'"'/%27/g' \
    -e 's/\n/%0A/g')
    
  curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${chat_id}" \
    -d "text=${encoded_message}" \
    -d "parse_mode=HTML" \
    -d "disable_web_page_preview=true" > /dev/null
}

format_duration() {
    local T=$1
    local H=$((T/3600))
    local M=$(( (T%3600)/60 ))
    local S=$((T%60))
    printf "%02d hours, %02d minutes, %02d seconds" $H $M $S
}

# =========================================================
# BUILD LOGIC FUNCTION
# =========================================================

start_build_process() {

    START_TIME=$(date +%s)

    local initial_msg="⚙️ *ROM Build Started!*
    *ROM:* $BUILD_TARGET
    *Android:* $ANDROID_VERSION
    *Device:* $DEVICE_CODE
    *Start Time:* $(date '+%Y-%m-%d %H:%M:%S %Z')"
    send_telegram "$TG_BUILD_CHAT_ID" "$initial_msg"

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

    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    DURATION_FORMATTED=$(format_duration $DURATION)

    if [[ $BUILD_STATUS -eq 0 ]]; then
        status_icon="✅"
        status_text="Success"
    else
        status_icon="❌"
        status_text="Failure (Exit Code: $BUILD_STATUS)"
    fi

    final_msg="${status_icon} *Build Finished!*
    *ROM:* $BUILD_TARGET
    *Android:* $ANDROID_VERSION
    *Device:* $DEVICE_CODE
    *Duration:* $DURATION_FORMATTED
    *Status:* $status_text"
    send_telegram "$TG_BUILD_CHAT_ID" "$final_msg"

    # =========================================================
    # ✅ UPDATED UPLOAD + TELEGRAM LINK PART
    # =========================================================
    if [[ $BUILD_STATUS -eq 0 ]]; then
        rm -rf go-up*
        wget https://raw.githubusercontent.com/chime-A13/tools-gofile/refs/heads/private/go-up
        chmod +x go-up

        echo "Uploading build..."

        UPLOAD_OUTPUT=$(./go-up out/target/product/spartan/Evolution*spartan*.zip)

        echo "$UPLOAD_OUTPUT"

        UPLOAD_LINK=$(echo "$UPLOAD_OUTPUT" | grep -Eo 'https?://[^ ]+' | head -n 1)

        if [[ -n "$UPLOAD_LINK" ]]; then
            upload_msg="📦 <b>Build Uploaded!</b>
            <b>ROM:</b> $BUILD_TARGET
            <b>Android:</b> $ANDROID_VERSION
            <b>Device:</b> $DEVICE_CODE
            <b>Link:</b> <a href='$UPLOAD_LINK'>Download</a>"
        else
            upload_msg="⚠️ <b>Upload done but link not found!</b>
            Check logs manually."
        fi

        send_telegram "$TG_BUILD_CHAT_ID" "$upload_msg"
    fi

    cat out/error.log
}

# =========================================================
# MAIN EXECUTION
# =========================================================

start_build_process
