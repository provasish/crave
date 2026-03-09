#!/bin/bash

rm -rf .repo/local_manifests

repo init -u https://github.com/The-Clover-Project/manifest.git -b 16-qpr2 --git-lfs --depth=1

/opt/crave/resync.sh

rm -rf device/realme
rm -rf vendor/realme
rm -rf kernel/realme
rm -rf hardware/dolby
rm -rf hardware/oplus
rm -rf vendor/oplus
rm -rf out/target/product/spartan
rm -rf vendor/clover-priv/keys

# Deivce Trees
git clone https://github.com/clover-spartan/android_device_realme_spartan device/realme/spartan
git clone https://github.com/clover-Spartan/android_device_realme_sm8250-common device/realme/sm8250-common

# Vendor Trees
git clone https://github.com/clover-Spartan/proprietary_vendor_realme_spartan vendor/realme/spartan
git clone https://github.com/clover-Spartan/proprietary_vendor_realme_sm8250-common vendor/realme/sm8250-common --depth=1

# Kernel Tree
git clone https://github.com/clover-spartan/android_kernel_realme_sm8250 kernel/realme/sm8250 --depth=1

# Hardware Trees
git clone https://github.com/clover-Spartan/hardware_dolby hardware/dolby --depth=1
git clone https://github.com/clover-Spartan/android_hardware_oplus hardware/oplus

# Oplus Camera
git clone https://github.com/clover-spartan/vendor_oplus_camera vendor/oplus/camera --depth=1

# Sign Keys
git clone https://github.com/olzhas0986/keys -b cl vendor/clover-priv/keys

export TZ=Asia/Kolkata
export BUILD_USERNAME=hunt3r
export BUILD_HOSTNAME=crave
export TARGET_BUILD_VARIANT=user

. build/envsetup.sh
lunch clover_spartan-bp4a-user
m installclean
mka clover -j$(nproc --all)
