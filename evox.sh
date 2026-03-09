#!/bin/bash

rm -rf .repo/local_manifests

repo init -u https://github.com/Evolution-X/manifest -b bq2 --git-lfs --depth=1

/opt/crave/resync.sh

rm -rf device/realme
rm -rf vendor/realme
rm -rf kernel/realme
rm -rf hardware/dolby
rm -rf hardware/oplus
rm -rf vendor/oplus
rm -rf out/target/product/spartan
rm -rf vendor/lineage-priv/keys

# Deivce Trees
git clone https://github.com/EvoX-Spartan/android_device_realme_spartan device/realme/spartan
git clone https://github.com/EvoX-Spartan/android_device_realme_sm8250-common device/realme/sm8250-common

# Vendor Trees
git clone https://github.com/EvoX-Spartan/proprietary_vendor_realme_spartan vendor/realme/spartan
git clone https://github.com/EvoX-Spartan/proprietary_vendor_realme_sm8250-common vendor/realme/sm8250-common --depth=1

# Kernel Tree
git clone https://github.com/EvoX-Spartan/android_kernel_realme_sm8250 kernel/realme/sm8250 --depth=1

# Hardware Trees
git clone https://github.com/EvoX-Spartan/hardware_dolby hardware/dolby --depth=1
git clone https://github.com/EvoX-Spartan/android_hardware_oplus hardware/oplus

# Oplus Camera
git clone https://gitlab.com/provasishh/proprietary_vendor_oplus_camera.git vendor/oplus/camera --depth=1

# Sign Keys
git clone https://github.com/olzhas0986/keys vendor/lineage-priv/keys

export TZ=Asia/Kolkata
export BUILD_USERNAME=hunt3r
export BUILD_HOSTNAME=crave
export WITH_GMS=true
export TARGET_BUILD_VARIANT=user

. build/envsetup.sh
lunch lineage_spartan-bp4a-user
m installclean
m evolution
