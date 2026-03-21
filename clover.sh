#!/bin/bash
set -o pipefail

if [ -f .env ]; then
  set -o allexport
  source .env
  set +o allexport
fi

# ================= TIMEZONE =================
echo "🕒 Switching system timezone to Asia/Kolkata (IST)"
sudo rm -f /etc/localtime
sudo ln -s /usr/share/zoneinfo/Asia/Kolkata /etc/localtime

if [ -z "$TT" ] || [ -z "$PVCI" ] || [ -z "$UP" ] || [ -z "$PD" ] ; then
    echo "❌ Missing required environment variables in .env"
	exit 1
fi

echo "🕒 Current system time: $(date)"
# ================= ROM INFO =================
ROM_NAME="The Clover Project"
DEVICE="spartan"
BUILD_TYPE="user"
ANDROID_VERSION="v16 QPR2"
SECURITY_PATCH="March ASB 2026"
ROM_VERSION="v3.8"
MAINTAINER="provasish"

OUT_DIR="out/target/product/${DEVICE}"
START_TIME=$(date +%s)

# ================= TELEGRAM =================
tg_send() {
    curl -s -X POST "https://api.telegram.org/bot${TT}/sendMessage" \
        -d "chat_id=${PVCI}" \
        -d "parse_mode=HTML" \
        -d "disable_web_page_preview=true" \
        --data-urlencode "text=$1" >/dev/null
}

tg_upload() {
    curl -s -X POST "https://api.telegram.org/bot${TT}/sendMessage" \
        -d "chat_id=${UP}" \
        -d "parse_mode=HTML" \
        -d "disable_web_page_preview=true" \
        --data-urlencode "text=$1" >/dev/null
}
# ================= PIXELDRAIN =================
pixeldrain_upload() {
    local FILE="$1"
    [ ! -f "$FILE" ] && echo "NOT_FOUND" && return
    RESP=$(curl -sS -T "$FILE" -u :$PD https://pixeldrain.com/api/file/)
    ID=$(echo "$RESP" | grep -oP '(?<="id":")[^"]+')
    [ -n "$ID" ] && echo "https://pixeldrain.com/u/$ID" || echo "UPLOAD_FAILED"
}

# ================= GOFILE =================
gofile_upload() {
    local FILE="$1"
    for S in store2 store3 store4 store5; do
        RESP=$(curl -s -F "file=@${FILE}" "https://${S}.gofile.io/uploadFile")
        echo "$RESP" | grep -q '"status":"ok"' && \
        echo "$RESP" | grep -oP '(?<=downloadPage":")[^"]+' && return
    done
    echo "UPLOAD_FAILED"
}

# ================= FAIL =================
on_fail() {
    ERR_LINK="N/A"
    [ -f out/error.log ] && ERR_LINK=$(gofile_upload out/error.log)

    tg_send "❎ ${ROM_NAME} build failed
📱 Codename: ${DEVICE}
📄 Check Build Logs"

    tg_upload "❎ ${ROM_NAME} build failed
📱 Codename: ${DEVICE}
🔧 Step: Build
📄 Error log: ${ERR_LINK}"

    exit 1
}
# ================= BUILD START =================
tg_send "✨ ${ROM_NAME} started
📱 Codename: ${DEVICE}
🧪 Build Type: ${BUILD_TYPE}
⚙️ Version: ${ROM_VERSION}
⚓️ Android: ${ANDROID_VERSION}
🛡 Patch: ${SECURITY_PATCH}
👤 Maintainer: ${MAINTAINER}
🌏 $(date +"%d %b %Y %I:%M %p IST")"

# ================= BUILD =================
 echo "Starting remove repositories..."
rm -rf device/realme
rm -rf vendor/realme
rm -rf kernel/realme
rm -rf hardware/oplus
rm -rf hardware/dolby
rm -rf vendor/oplus
rm -rf vendor/clover-priv*


echo ">>>> [STEP] Repo Init"
repo init -u https://github.com/The-Clover-Project/manifest.git -b 16-qpr2 --git-lfs --depth=1

echo ">>>> [STEP] Local Manifests"
git clone https://github.com/provasish/manifest.git .repo/local_manifests

echo ">>>> [STEP] Repo Sync"
if [ -f /opt/crave/resync.sh ]; then
    /opt/crave/resync.sh
else
    repo sync -c --force-sync --no-tags --no-clone-bundle -j$(nproc --all)
fi

echo ">>>> [STEP] Export info & Build"
. build/envsetup.sh
export TZ=Asia/Kolkata
export BUILD_USERNAME=hunt3r
export BUILD_HOSTNAME=pro
lunch clover_spartan-bp4a-user
mka installclean
mka clover -j$(nproc --all) 2>&1 | tee build.log
[ "${PIPESTATUS[0]}" -ne 0 ] && on_fail

# ================= SUCCESS =================
END_TIME=$(date +%s)
DUR=$((END_TIME - START_TIME))

BUILD_ID="UNKNOWN"
ROM_ZIP=$(ls -1 ${OUT_DIR}/*.zip 2>/dev/null | sort | tail -n 1)

if [ -n "$ROM_ZIP" ]; then
    BUILD_ID=$(basename "$ROM_ZIP" .zip)
    ROM_SIZE=$(du -h "$ROM_ZIP" | awk '{print $1}')
else
    ROM_SIZE="Unknown"
fi

tg_send "🌠 Buildbot finished it's job
📱 Codename: ${DEVICE}
🧩 Build Type: ${BUILD_TYPE}
🆔 Build ID: <code>${BUILD_ID}</code>
📦 Size: ${ROM_SIZE}
👤 Maintainer: ${MAINTAINER}
⏳ <i>Compilation took $((DUR/3600))h $(((DUR%3600)/60))min</i>"

tg_send "🚨 Compiler gave up arguing. Uploading artifacts…"

# ================= UPLOAD =================
echo ">>>> [STEP] Upload Artifacts"

PRIVATE_MSG="📦 ${ROM_NAME} Uploads
📱 Device: ${DEVICE}
🧩 Build Type: ${BUILD_TYPE}

"

for ZIP in ${OUT_DIR}/Clover*.zip; do
    [ -f "$ZIP" ] || continue

    PRIVATE_MSG+="📄 ROM: $(basename "$ZIP")
GoFile: $(gofile_upload "$ZIP")
PixelDrain: $(pixeldrain_upload "$ZIP")

"
done

for IMG in boot.img recovery.img; do
    FILE="${OUT_DIR}/${IMG}"
    [ -f "$FILE" ] && PRIVATE_MSG+="🧩 ${IMG}
GoFile: $(gofile_upload "$FILE")
PixelDrain: $(pixeldrain_upload "$FILE")

"
done

for OTA_JSON in ${OUT_DIR}/*.json; do
    [ -f "$OTA_JSON" ] || continue

    PRIVATE_MSG+="📑 OTA JSON: $(basename "$OTA_JSON")
GoFile: $(gofile_upload "$OTA_JSON")
PixelDrain: $(pixeldrain_upload "$OTA_JSON")

"
done

tg_upload "$PRIVATE_MSG"
tg_send "🥀 Artifacts released into the wild."
