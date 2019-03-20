#!/usr/bin/zsh
#
# mktsusbstick
# Configure a specific disk as a ThinStation USB Stick
#

zmodload zsh/zutil

###
#  FUNCTIONS
#

#
#  Create ThinStation USB Stick (SYSLINUX).
#
#  --ts-repo <repo_path>
#    REQUIRED. The path to your ThinStation repository clone, which
#    was used to build your SYSLINUX image.  This is the repository
#    root, not any directory within.
#
#  --disk-id <disk_id>
#    REQUIRED.  The ID of the drive device, as shown in
#    `ls /dev/disk/by-id`.  It must link to the device for the disk,
#    not a partition within the disk.
#
#  --new-volume-name [volume_name]
#    OPTIONAL.  The name to be given to the FAT32 filesystem which
#    is created on your drive during this process.
#    Default: "THINSTATION"
#
function mktsusbstick # --mbr-path </usr/lib/syslinux/mbr/mbr.bin> --boot-dir-path </media/ubuntu/THINSTATION/boot> --disk-id <usb-SanDisk_Ultra_USB_3.0_UUID-0:0> --new-volume-name [THINSTATION]
{
    zparseopts -A MKTSUSBSTICK_OPTIONS  \
        -mbr-path:                      \
        -boot-dir-path:                 \
        -disk-id:                       \
        -new-volume-name::
    
    [[ -v MKTSUSBSTICK_OPTIONS[--mbr-path]      ]] || { echo ; echo '[ERROR]  Missing argument: --mbr-path.'      ; return 1 ; }
    [[ -v MKTSUSBSTICK_OPTIONS[--boot-dir-path] ]] || { echo ; echo '[ERROR]  Missing argument: --boot-dir-path.' ; return 2 ; }
    [[ -v MKTSUSBSTICK_OPTIONS[--disk-id]       ]] || { echo ; echo '[ERROR]  Missing argument: --disk-id.'       ; return 3 ; }

    local       MBR_PATH=${MKTSUSBSTICK_OPTIONS[--mbr-path]}
    local  BOOT_DIR_PATH=${MKTSUSBSTICK_OPTIONS[--boot-dir-path]}
    local        DISK_ID=${MKTSUSBSTICK_OPTIONS[--disk-id]}
    local PARTITION_NAME=${MKTSUSBSTICK_OPTIONS[--new-volume-name]:-'THINSTATION'}

    local DEV_DISK_PATH="/dev/disk/by-id/${DISK_ID}"
    [[ -e "${DEV_DISK_PATH}" ]] || { echo ; echo '[ERROR]  Specified disk not found.  Check that your destination disk or USB stick is connected.' ; return 10 ; }
    
    local DEV_SD_PATH=$(readlink -f "${DEV_DISK_PATH}")
    [[ -e "${DEV_SD_PATH}" ]]   || { echo ; echo '[ERROR]  Disk device not found.' ; return 20 ; }
    
    [[ -e "${MBR_PATH}" ]]      || { echo ; echo '[ERROR]  mbr.bin not found at path specified after --mbr-path.' ; return 30 ; }
    [[ -d "${BOOT_DIR_PATH}" ]] || { echo ; echo '[ERROR]  Boot files directory specified after --boot-dir-path does not exist.' ; return 40 ; }

    local TEMP_MOUNT_POINT="/mnt/${PARTITION_NAME}"
    local DEV_PARTITION_PATH="${DEV_SD_PATH}1"
    
    umount ${DEV_SD_PATH}?* || true ; sync
    
    dd        if=/dev/zero           of=${DEV_SD_PATH}  bs=1M count=2
    parted    --script                 "${DEV_SD_PATH}" mklabel msdos               && sync
    parted    --script --align optimal "${DEV_SD_PATH}" mkpart  primary '0%' '100%' && sync
    mkfs.vfat -n "${PARTITION_NAME}"   "${DEV_PARTITION_PATH}"                      && sync
    syslinux  --install                 ${DEV_PARTITION_PATH}                       && sync
    parted    --script                  ${DEV_SD_PATH}  set 1 boot on               && sync
    dd        if=${MBR_PATH}         of=${DEV_SD_PATH}  conv=notrunc bs=440 count=1 && sync

    mkdir "${TEMP_MOUNT_POINT}"
    mount  ${DEV_PARTITION_PATH} ${TEMP_MOUNT_POINT}

    cp -v -R ${BOOT_DIR_PATH} ${TEMP_MOUNT_POINT}/.

    umount -v ${DEV_SD_PATH}?* || true && sync
    rm -rf    ${TEMP_MOUNT_POINT}

    echo ; echo "[INFO]  ThinStation USB Stick preparation complete.  Please remove the USB drive."
}

echo
echo '[INFO]  Function loaded.  Usage example: # mktsusbstick --mbr-path /usr/lib/syslinux/mbr/mbr.bin --boot-dir-path /media/ubuntu/THINSTATION/boot --disk-id usb-SanDisk_Ultra_USB_3.0_UUID-0:0'
echo


