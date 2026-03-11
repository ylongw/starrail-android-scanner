#!/usr/bin/env python3
"""
convert_pcap.py — Fix PCAPdroid LinkType for reliquary-archiver

PCAPdroid captures traffic via Android VPNService (TUN interface),
producing pcap files with LinkType 101 (Raw IP, no Ethernet header).
reliquary-archiver expects LinkType 1 (Ethernet).

This script prepends a fake 14-byte Ethernet header to every packet
and updates the global pcap header, making the file compatible.

Usage:
    python3 convert_pcap.py input.pcap output.pcap
    python3 convert_pcap.py input.pcap            # writes input_eth.pcap
"""

import struct
import sys
import os

# Fake Ethernet header: dst MAC + src MAC + EtherType 0x0800 (IPv4)
ETH_HEADER = bytes.fromhex("000000000002" + "000000000001" + "0800")

LINKTYPE_RAW_IP   = 101
LINKTYPE_ETHERNET = 1


def convert(src_path: str, dst_path: str) -> int:
    with open(src_path, "rb") as fin, open(dst_path, "wb") as fout:
        raw_header = fin.read(24)
        if len(raw_header) < 24:
            raise ValueError("File too small — not a valid pcap")

        magic, ver_maj, ver_min, thiszone, sigfigs, snaplen, network = struct.unpack(
            "<IHHiIII", raw_header
        )

        if magic not in (0xA1B2C3D4, 0xD4C3B2A1):
            raise ValueError(f"Not a pcap file (magic=0x{magic:08x})")

        if network != LINKTYPE_RAW_IP:
            print(
                f"Warning: input LinkType is {network}, expected {LINKTYPE_RAW_IP} (Raw IP). "
                "Proceeding anyway — Ethernet header will still be prepended."
            )

        # Write new global header with LinkType = Ethernet
        new_header = struct.pack(
            "<IHHiIII",
            magic, ver_maj, ver_min, thiszone, sigfigs,
            snaplen + 14,          # snaplen grows by Ethernet header size
            LINKTYPE_ETHERNET,
        )
        fout.write(new_header)

        count = 0
        while True:
            rec = fin.read(16)
            if not rec:
                break
            ts_sec, ts_usec, incl_len, orig_len = struct.unpack("<IIII", rec)
            payload = fin.read(incl_len)

            fout.write(struct.pack("<IIII", ts_sec, ts_usec, incl_len + 14, orig_len + 14))
            fout.write(ETH_HEADER)
            fout.write(payload)
            count += 1

    return count


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    src = sys.argv[1]
    if len(sys.argv) >= 3:
        dst = sys.argv[2]
    else:
        base, ext = os.path.splitext(src)
        dst = base + "_eth" + (ext or ".pcap")

    print(f"Input:  {src}  ({os.path.getsize(src):,} bytes)")
    count = convert(src, dst)
    print(f"Output: {dst}  ({os.path.getsize(dst):,} bytes)")
    print(f"Converted {count:,} packets  (LinkType {LINKTYPE_RAW_IP} → {LINKTYPE_ETHERNET})")


if __name__ == "__main__":
    main()
