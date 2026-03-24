# repo init
repo init -u https://github.com/The-Clover-Project/manifest.git -b 16-qpr2 --git-lfs --depth=1

# repo sync script
/opt/crave/resync.sh

# Remove old device specific repos
remove=(
device/realme
kernel/realme
vendor/realme
vendor/oplus
hardware/oplus
hardware/dolby
vendor/clover-priv/keys
out/target/product/spartan
)

rm -rf "${remove[@]}"

# Deivce Trees
git clone https://github.com/clover-spartan/android_device_realme_spartan device/realme/spartan
git clone https://github.com/clover-spartan/android_device_realme_sm8250-common device/realme/sm8250-common

# Vendor Trees
git clone https://github.com/clover-spartan/proprietary_vendor_realme_spartan vendor/realme/spartan
git clone https://github.com/clover-spartan/proprietary_vendor_realme_sm8250-common vendor/realme/sm8250-common --depth=1

# Kernel Tree
git clone https://github.com/clover-spartan/android_kernel_realme_sm8250 kernel/realme/sm8250 --depth=1

# Hardware Trees
git clone https://github.com/clover-spartan/android_hardware_dolby hardware/dolby
git clone https://github.com/clover-spartan/android_hardware_oplus hardware/oplus

# Oplus Camera
git clone https://gitlab.com/provasishh/proprietary_vendor_oplus_camera vendor/oplus/camera --depth=1

# My Keys
git clone https://github.com/Olzhas-Kdyr/keys -b cl vendor/clover-priv/keys


# Building 
. build/envsetup.sh
export BUILD_USERNAME=hunt3r
export BUILD_HOSTNAME=pro
lunch clover_spartan-bp4a-user
mka clover -j$(nproc --all)
