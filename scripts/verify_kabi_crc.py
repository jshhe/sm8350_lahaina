#!/usr/bin/env python3
"""Verify that out/Module.symvers matches every symbol CRC required by the
99 prebuilt vendor/vendor_boot .ko modules on OnePlus 9 Pro LE2120_14.0.0.1901.
"""
import json
import pathlib
import sys


def main():
    if len(sys.argv) != 3:
        print("Usage: verify_kabi_crc.py <Module.symvers> <phone_kabi_crc.json>")
        sys.exit(2)

    symvers_path = pathlib.Path(sys.argv[1])
    golden_path = pathlib.Path(sys.argv[2])

    built = {}
    for line in symvers_path.read_text(encoding="utf-8", errors="replace").splitlines():
        parts = line.split()
        if len(parts) >= 3:
            crc_str, sym, mod = parts[0], parts[1], parts[2]
            if mod == "vmlinux":
                built[sym] = int(crc_str, 16)

    golden = json.loads(golden_path.read_text(encoding="utf-8"))
    missing = []
    mismatched = []

    for sym, info in sorted(golden.items()):
        exp_crc = int(info["crc"], 16)
        users = info.get("users", [])
        if sym not in built:
            missing.append((sym, exp_crc, users))
        elif built[sym] != exp_crc:
            mismatched.append((sym, exp_crc, built[sym], users))

    print(f"KABI check: vmlinux exports={len(built)}, required by phone modules={len(golden)}")
    print(f"  matched   : {len(golden) - len(missing) - len(mismatched)}/{len(golden)}")
    print(f"  missing   : {len(missing)}")
    print(f"  mismatched: {len(mismatched)}")

    for sym, exp, users in missing[:30]:
        print(f"  MISSING  {sym:<38} expected=0x{exp:08x} users={users}")
    for sym, exp, got, users in mismatched[:30]:
        print(f"  MISMATCH {sym:<38} expected=0x{exp:08x} built=0x{got:08x} users={users}")

    if missing or mismatched:
        print("ERROR: KABI verification FAILED — refusing to package boot-breaking kernel!")
        sys.exit(1)

    print("SUCCESS: 100% KABI CRC match with all 99 stock phone modules!")


if __name__ == "__main__":
    main()
