To revert from OpenWrt back to the Tp-Link firmware we can't use the files provided by Tp-Link as those have a different internal structure. The firmware file needs to be prepared with specific parts that can be obtained from the original firmware. `binwalk` and `dd` will be the required tools for the task.

Start by downloading any MR500v1 firmware release of your choosing from Tp-Link's website and inspect it with `binwalk`:

	binwalk Archer_MR500\(\)v1_1.10.0_0.9.1_\[241219-rel42593\]_up_boot_All_Release_2024-12-19_13.44.08.bin

	DECIMAL       HEXADECIMAL     DESCRIPTION
	--------------------------------------------------------------------------------
	76596         0x12B34         U-Boot version string, "U-Boot 1.1.3 (Dec 19 2024 - 11:40:31)"
	132096        0x20400         uImage header, header size: 64 bytes, header CRC: 0x961A1D4B, created: 2024-12-19 03:42:48, image size: 1944688 bytes, Data Address: 0x81001000, Entry Point: 0x813CFDC0, data CRC: 0xA1A2C33F, OS: Linux, CPU: MIPS, image type: OS Kernel Image, compression type: lzma, image name: "Linux Kernel Image"
	132160        0x20440         LZMA compressed data, properties: 0x5D, dictionary size: 33554432 bytes, uncompressed size: 5606272 bytes
	2228736       0x220200        Squashfs filesystem, little endian, version 4.0, compression:xz, size: 9346756 bytes, 692 inodes, blocksize: 131072 bytes, created: 2024-12-19 03:50:03
	16515584      0xFC0200        Zip archive data, at least v1.0 to extract, name: bin/
	16515646      0xFC023E        Zip archive data, at least v1.0 to extract, name: lib/
	16515708      0xFC027C        Zip archive data, at least v2.0 to extract, compressed size: 27484, uncompressed size: 237716, name: lib/NetIspInfo.ini
	16543504      0xFC6F10        End of Zip archive, footer length: 22
	16543526      0xFC6F26        gzip compressed data, from Unix, last modified: 2024-07-10 08:44:36
	
To build a reversion image we need the first 512 bytes which is a Tp-Link specific header that OpenWrt will ignore and cut out when flashing (since OpenWrt includes its own 512 bytes header in firmware images), the uImage/LZMA data (kernel) and Squashfs filesystem (the rootfs). We copy these over with _dd_ (we can get the kernel and rootfs together in one go) while skipping u-boot (the bootloader).

> [!CAUTION]
> * Be careful using `dd` as it's capable of directly writing to devices and erasing disks or partitions. Always double/triple-check the destination (`of=` parameter) before proceeding with _dd_ operations.

	dd if=Archer_MR500\(\)v1_1.10.0_0.9.1_\[241219-rel42593\]_up_boot_All_Release_2024-12-19_13.44.08.bin of=header.bin bs=1 count=512
	dd if=Archer_MR500\(\)v1_1.10.0_0.9.1_\[241219-rel42593\]_up_boot_All_Release_2024-12-19_13.44.08.bin of=kernel_rootfs.bin bs=1 skip=132096 count=16383488
	
where 16383488 = 16515584 (start of the zip containing the modem firmware which we definitely don't want) - 132096 (start of the kernel / end of the bootloader)

Then proceed to combine the parts into the final binary:

	cat header.bin kernel_rootfs.bin > mr500v1_recovery_rel42593.bin

Based on the firmware binary above, the end result should be:

	binwalk mr500v1_recovery_rel42593.bin

	DECIMAL       HEXADECIMAL     DESCRIPTION
	--------------------------------------------------------------------------------
	512           0x200           uImage header, header size: 64 bytes, header CRC: 0x961A1D4B, created: 2024-12-19 03:42:48, image size: 1944688 bytes, Data Address: 0x81001000, Entry Point: 0x813CFDC0, data CRC: 0xA1A2C33F, OS: Linux, CPU: MIPS, image type: OS Kernel Image, compression type: lzma, image name: "Linux Kernel Image"
	576           0x240           LZMA compressed data, properties: 0x5D, dictionary size: 33554432 bytes, uncompressed size: 5606272 bytes
	2097152       0x200000        Squashfs filesystem, little endian, version 4.0, compression:xz, size: 9346756 bytes, 692 inodes, blocksize: 131072 bytes, created: 2024-12-19 03:50:03
	
Only the first 512 marker needs to be in the right place, the other can vary since kernel size can change between firmware releases. However, ensure all 3 signatures (uImage, LZMA and Squashfs) are present in the final file. We can also check the ending of the file to verify that we haven't lost data along the way:

	tail -c 128 mr500v1_recovery_rel42593.bin | xxd
	00000000: 0000 0000 0000 0000 0000 0000 0000 0000  ................
	00000010: 0000 0000 0000 0000 0000 0000 0000 0000  ................
	00000020: 0000 0000 0000 0000 0000 0000 0000 0000  ................
	00000030: 0000 0000 0000 0000 0000 0000 0000 0000  ................
	00000040: 0000 0000 0000 0000 0000 0000 0000 0000  ................
	00000050: 0000 0000 0000 0000 0000 0000 0000 0000  ................
	00000060: 0000 0000 0000 0000 0000 0000 0000 0000  ................
	00000070: 00ff ffff ffff ffff ffff ffff ffff ffff  ................

We want the final bits to be `ff`s as that's used for padding files to a specific size. If we see zeros or random data then we may have cut the file too soon and lost data from the root filesystem. 	

If all is good we can flash this firmware file in OpenWrt - which will warn about invalid/missing signature and incompatible firmware. We'll have to force flashing over this warning. 

![force-update](images/force-update.jpg)