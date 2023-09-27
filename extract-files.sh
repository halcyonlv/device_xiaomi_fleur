#!/bin/bash
#
# SPDX-FileCopyrightText: 2016 The CyanogenMod Project
# SPDX-FileCopyrightText: 2017-2024 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=fleur
VENDOR=xiaomi

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

export TARGET_ENABLE_CHECKELF=true

export PATCHELF_VERSION=0_17_2

# If XML files don't have comments before the XML header, use this flag
# Can still be used with broken XML files by using blob_fixup
export TARGET_DISABLE_XML_FIXING=true

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

ONLY_FIRMWARE=
KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        --only-firmware)
            ONLY_FIRMWARE=true
            ;;
        -n | --no-cleanup)
            CLEAN_VENDOR=false
            ;;
        -k | --kang)
            KANG="--kang"
            ;;
        -s | --section)
            SECTION="${2}"
            shift
            CLEAN_VENDOR=false
            ;;
        *)
            SRC="${1}"
            ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup {
    case "$1" in
        system_ext/priv-app/ImsService/ImsService.apk)
            [ "$2" = "" ] && return 0
            apktool_patch "${2}" "${MY_DIR}/blob-patches/ImsService.patch" -r
            ;;
        system_ext/lib64/libsink.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --add-needed "libshim_sink.so" "$2"
            ;;
	system_ext/lib64/libsource.so)
            [ "$2" = "" ] && return 0
            grep -q "libui_shim.so" "${2}" || "${PATCHELF}" --add-needed "libui_shim.so" "${2}"
            ;;
	vendor/etc/init/android.hardware.neuralnetworks@1.3-service-mtk-neuron.rc)
            [ "$2" = "" ] && return 0
            sed -i 's/start/enable/' "$2"
            ;;
        vendor/etc/init/android.hardware.secure_element@1.2-service-mediatek.rc)
            [ "$2" = "" ] && return 0
            sed -i 's/sea/fleur/' "$2"
            ;;
        vendor/etc/init/android.hardware.bluetooth@1.1-service-mediatek.rc)
            [ "$2" = "" ] && return 0
            sed -i '/vts/Q' "$2"
            ;;
	vendor/etc/init/init.batterysecret.rc)
            [ "$2" = "" ] && return 0
            sed -i '/seclabel/d' "$2"
	    ;;
	vendor/etc/init/init.mi_thermald.rc)
            [ "$2" = "" ] && return 0
            sed -i '/seclabel/d' "$2"
	    ;;
	vendor/etc/camera/camerabooster.json)
            [ "$2" = "" ] && return 0
            sed -i 's/"sea"/"fleur"/' "$2"
            ;;
        vendor/bin/mnld|\
        vendor/lib*/libcam.utils.sensorprovider.so|\
        vendor/lib*/librgbwlightsensor.so|\
        vendor/lib*/libaalservice.so)
            [ "$2" = "" ] && return 0
            "$PATCHELF" --add-needed "libshim_sensors.so" "$2"
            ;;
        vendor/lib64/libmtkcam_stdutils.so|\
        vendor/lib64/hw/android.hardware.camera.provider@2.6-impl-mediatek.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --replace-needed "libutils.so" "libutils-v32.so" "${2}"
            ;;
        vendor/lib64/libmtkcam_featurepolicy.so)
            # evaluateCaptureConfiguration()
            sed -i "s/\x34\xE8\x87\x40\xB9/\x34\x28\x02\x80\x52/" "$2"
            ;;
        vendor/bin/hw/android.hardware.gnss-service.mediatek |\
        vendor/lib64/hw/android.hardware.gnss-impl-mediatek.so)
            [ "$2" = "" ] && return 0
            "$PATCHELF" --replace-needed "android.hardware.gnss-V1-ndk_platform.so" "android.hardware.gnss-V1-ndk.so" "$2"
            ;;
        vendor/bin/hw/android.hardware.media.c2@1.2-mediatek)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --add-needed "libstagefright_foundation-v33.so" "${2}"
            "${PATCHELF}" --replace-needed "libavservices_minijail_vendor.so" "libavservices_minijail.so" "${2}"
            ;;
        vendor/lib*/hw/vendor.mediatek.hardware.pq@2.15-impl.so)
            [ "$2" = "" ] && return 0
            "$PATCHELF" --replace-needed "libutils.so" "libutils-v32.so" "$2"
            ;;
        vendor/lib64/vendor.mediatek.hardware.power@1.1.so|\
        vendor/lib64/vendor.mediatek.hardware.power@2.0.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --add-needed "libshim_power.so" "${2}"
            ;;
        vendor/lib*/libwvhidl.so|\
        vendor/lib*/mediadrm/libwvdrmengine.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --replace-needed "libprotobuf-cpp-lite-3.9.1.so" "libprotobuf-cpp-full-3.9.1.so" "${2}"
            ;;
        vendor/lib64/libvendor.goodix.hardware.biometrics.fingerprint@2.1.so)
            "${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${2}"
            ;;
        vendor/lib64/libmnl.so)
            "${PATCHELF}" --add-needed "libcutils.so" "${2}"
            ;;
        vendor/lib*/libteei_daemon_vfs.so|\
        vendor/lib64/libSQLiteModule_VER_ALL.so|\
        vendor/lib64/lib3a.flash.so|\
        vendor/lib64/lib3a.ae.stat.so|\
        vendor/lib64/lib3a.sensors.color.so|\
        vendor/lib64/lib3a.sensors.flicker.so|\
        vendor/lib64/libaaa_ltm.so)
            "${PATCHELF}" --add-needed "liblog.so" "${2}"
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}

function blob_fixup_dry() {
    blob_fixup "${1}" ""
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

if [ -z "${ONLY_FIRMWARE}" ]; then
    extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

if [ -z "${SECTION}" ]; then
    extract_firmware "${MY_DIR}/proprietary-firmware.txt" "${SRC}"
fi

"${MY_DIR}/setup-makefiles.sh"
