### AnyKernel3 Ramdisk Mod Script
## OnePlus 9 Pro (lemonadep) - OpenWrt 5.4.254 kernel
##
## The stock boot image is header v3 with a gzip-compressed ramdisk.
## dump_boot/write_boot preserves that ramdisk, including the Magisk patch.

properties() { '
kernel.string=OnePlus 9 Pro OpenWrt Kernel 5.4.254
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=lemonadep
device.name2=OnePlus9Pro
device.name3=lemonade
device.name4=LE2120
device.name5=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; }

BLOCK=/dev/block/bootdevice/by-name/boot;
IS_SLOT_DEVICE=1;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

. tools/ak3-core.sh;

dump_boot;
write_boot;
