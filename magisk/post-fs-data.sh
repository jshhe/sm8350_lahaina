#!/system/bin/sh
MODDIR=${0%/*}
# Load the out-of-tree Realtek r8152 v2.22.1 driver.
#
# If the running kernel already exports rtl8152_get_version(), the built-in
# r8152 (2.5G capable, as compiled into the custom OpenWrt kernel) owns the
# device.  Inserting the module then only fails with "exports duplicate
# symbol", so skip it.  On the stock kernel the symbol is absent and the
# module provides 2.5G support for RTL8156/RTL8156B.
if grep -q rtl8152_get_version /proc/kallsyms 2>/dev/null; then
    exit 0
fi
/system/bin/insmod "$MODDIR/system/lib/modules/r8152_2p5g.ko" 2>/dev/null
exit 0
