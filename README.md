# OpenWrt on Tp-Link MR500v1 (EU)

Ever since I got this router I encountered connection stability issues (well reported on the Tp-Link forums 
[here](https://community.tp-link.com/en/home/forum/topic/649224), 
[here](https://community.tp-link.com/en/home/forum/topic/605538), 
[here](https://community.tp-link.com/en/home/forum/topic/616946), 
[here](https://community.tp-link.com/en/home/forum/topic/603938)...), and as soon as I took it apart and discovered it uses an OpenWrt supported platform (MT7621 / mipsel_24kc) I looked into finding a way to bring OpenWrt on it (and hopefully resolve the disconnection issues, or at least find a better workaround than scheduled daily router reboots). 

**The MR500 v1 (EU) is identical on first look with its (supported) bigger brother MR600v2, but uses a different LTE modem.**

![mr600v2-vs-mr500v1](images/mr600v2-vs-mr500v1.jpg)
_MR600v2 photo thanks to [kernelpanic1](https://forum.openwrt.org/t/tp-link-archer-mr600-exploration/65489/160)_

### Specifications

* SoC: [Mediatek MT7621DAT 880MHz](photos/PIC_20240106_200715.JPG)
* RAM: 128MB DDR3
* Flash: 16MB SPI NOR flash [(EN25)QH128A-104HIP](photos/PIC_20240106_200626.JPG)
* LTE Modem: [**Fibocom FG621-EA**](photos/PIC_20240106_200843.JPG)
* WiFi 5GHz: [Mediatek MT7613BEN](photos/PIC_20240106_200807.JPG)
* WiFi 2.4GHz: [Mediatek MT7603EN](photos/PIC_20240106_200817.JPG)
* Ethernet: MT7530, 4x 1000Mbps
* UART: [Serial console (115200 8n1) @ J1](photos/PIC_20240106_201317.JPG)
* Buttons: Reset, WPS.
* LED: Power, WAN, 4G+, single WiFi, LAN, Signal1, Signal2, Signal3 

Board photos: [front](photos/PIC_20240106_200401.JPG), [back](photos/PIC_20240106_200119.JPG), [serial pins](photos/PIC_20240106_201317.JPG). 

### Hardware

    # lspci
    00:00.0 PCI bridge: Device 0e8d:0801 (rev 01)
    00:01.0 PCI bridge: Device 0e8d:0801 (rev 01)
    01:00.0 Network controller: MEDIATEK Corp. MT7603E 802.11bgn PCI Express Wireless Network Adapter
    02:00.0 Unclassified device [0002]: MEDIATEK Corp. Device 7663

    # lsusb
	Bus 001 Device 001: ID 1d6b:0002 Linux 6.6.67 xhci-hcd xHCI Host Controller
	Bus 001 Device 002: ID 2cb7:0a05 Fibocom FG621 Module
	Bus 002 Device 001: ID 1d6b:0003 Linux 6.6.67 xhci-hcd xHCI Host Controller

### Identification

Since Tp-Link really enjoys versioning out their devices and mix-matching the hardware used in them, it's necessary to first identify your device properly.

Software signature:

![software-version](images/software.png)

Hardware label:

![hardware-label](images/hardware-label.jpg)

_My device came with operator-specific firmware, hence the (ROORG) designation._

---
> [!CAUTION]
> **Don't proceed unless you create full flash backups, are comfortable around flash programmers and/or bricked devices or can easily afford to buy a new router.**
> **Opening the device to access the serial console will also most likely void your warranty (and definitely break some or all plastic clips)**

## Installation

> [!IMPORTANT]  
> I have tested **only** the serial console method as described in the [MR600 commit message](https://git.openwrt.org/?p=openwrt/openwrt.git;a=commitdiff;h=78110c3b5fce119d13cd45dadd33ca396c8ce197) to install OpenWrt on the MR500.
> While a `factory` image exists, the [MR600 device page](https://openwrt.org/toh/hwdata/tp-link/tp-link_archer_mr600_v2) still links to the initramfs image for factory install, so it is probably not possible to install OpenWrt directly from the Tp-Link web interface. Perhaps [this discussion](https://forum.openwrt.org/t/tp-link-archer-mr600-exploration/65489?page=5) holds the complete answer.
> Even if that is already supported, the same `factory` image may or may not work with the MR500 web interface to allow for firmware migration, and this is a scenario I have not tested.

> [!NOTE]
> If you want to poke around the Tp-Link firmware first, the login credentials for the serial console are `admin / 1234`.

**1.** Start a TFTP server - [Tftpd64](https://pjo2.github.io/tftpd64/) will do just fine.

Configure the computer's network adapter and the TFTP server to listen on 192.168.0.5/24. Connect to the router using one of the 3 LAN ports.

**2.** Download the MR600v2 OpenWrt initramfs (kernel) image from the [OpenWrt Firmware Selector](https://firmware-selector.openwrt.org/?target=ramips%2Fmt7621&id=tplink_mr600-v2-eu) (either 23.05.x or 24.10.x will do)

Place it into the TFTP server's root directory and rename it to `test.bin`

**3.** Connect to the router's serial console with a USB/UART adapter.

Attach power and interrupt the U-Boot boot process by quickly pressing `4` or typing `tpl` at the correct moment (see below).

```
U-Boot 1.1.3 (Nov 22 2023 - 16:37:42)

Board: Ralink APSoC DRAM:  128 MB
relocate_code Pointer at: 87fa0000

Config XHCI 40M PLL
******************************
Software System Reset Occurred
******************************
flash manufacture id: 1c, device id 70 18
find flash: EN25QH128A
*** Warning - bad CRC, using default environment

============================================
Ralink UBoot Version: 5.0.0.0
--------------------------------------------
ASIC MT7621A DualCore (MAC to MT7530 Mode)
DRAM_CONF_FROM: Auto-Detection
DRAM_TYPE: DDR3
DRAM bus: 16 bit
Xtal Mode=3 OCP Ratio=1/3
Flash component: SPI Flash
Date:Nov 22 2023  Time:16:37:42
============================================
icache: sets:256, ways:4, linesz:32 ,total:32768
dcache: sets:256, ways:4, linesz:32 ,total:32768

 ##### The CPU freq = 880 MHZ ####
 estimate memory size =128 Mbytes
#Reset_MT7530
set LAN/WAN WLLLL                                                             

				 <--- around here press 4 or type 'tpl' quickly

4: System Enter Boot Command Line Interface.

U-Boot 1.1.3 (Nov 22 2023 - 16:37:42)
MT7621 #
```

The default U-Boot menu is hidden (and quickly bypassed) but still partially available by pressing the corresponding number keys at the proper time:

	1: System Load Linux to SDRAM via TFTP.
	2: System Load Linux Kernel then write to Flash via TFTP.
	3: System Boot system code via Flash.
	4: System Enter Boot Command Line Interface. <--- triggered by the 'tpl' prompt

**4.** Transfer the firmware [through TFTP](logs/tftp-flash-log.txt) and then instruct U-Boot to boot OpenWrt from ram:

```    
# tftpboot

...transfer happens here...

# bootm
```

The router will boot the kernel image and start OpenWrt in _recovery mode_.
	
**5.** With OpenWrt booted in **_recovery (initramfs)_** mode, use the web interface or console to install the `sysupgrade` OpenWrt firmware (which you can also obtain from the ImageBuilder).

After another reboot you should find yourself in the permanently installed OpenWrt firmware.

### Status

**What works:**
- WAN and LAN 1-3 ports are correctly identified and work as expected.
- Both 2.4Ghz and 5Ghz wirelesses are recognized and appear functional (I didn't do throughput tests as I mostly focused on getting the mobile connection up and running, which provides nowhere near the wireless bandwidth capabilities).
- LEDs are all functional (and also configurable through LuCI):
	- Power, WAN, LAN and WIFI work out-of-the-box. The single WIFI led is attached to the 5Ghz wireless by default, but can be reassigned in LuCI.
	- The 4G+ led can be configured to indicate WWAN status (but no longer differentiates between 4G and 4G+ connectivity as with the retail firmware).
	- _The mobile signal leds are a task for another day._
- Individual signal numbers seem in the correct range, but I have no exact method of confirming them.
- At least some of the LTE status info is confirmed correct (Operator, MCC, NMC, Cell ID, Primary band, Modem firmware model and version).
- Carrier aggregation and second band info works ([(1)](images/3ginfo-CA-3&20.png), [(2)](images/3ginfo-CA-7&20.png)) with the patched [3ginfolite script](lte-advanced/usr_share/3ginfolite/3ginfo.sh). 
	- Speeds are on par with another MT7621-based router running a Qualcomm EM12 modem placed side by side and on the same mobile operator and identical data plan.

**What doesn't work:**
- So far everything seems to work for basic functionality. Advanced LTE monitoring and band selection require additional steps as described below. 
	- ~_Secondary band functionality and reporting need to be tested with a CA-capable SIM/operator._~
	- 3ginfo status page fails randomly and after being left open and refreshing for a while. Force refreshing several times or logging out of LuCI and logging back in seems to return it to functioning order. I assume either the modem is slow to respond or randomly returns unexpected or garbage data. 
- Stability improvements remain to be tested... Watchcat can easily handle the modem restarts if it misbehaves like with the official firmware. 

**Updates:**
- 17 days in, the router remains online, but carrier aggregation doesn't seem to kick in anymore (similar to what the router does with the official firmware). Restarting the modem with `AT+CFUN=15` restores carrier aggregation and improves speed slightly. 
- 25 days in, the router is still online, wwan lost connection and reconnected a couple of times (and reset its uptime) but didn't completely become unresponsive as with the default firmware (yet). One oddity is that the modem appears to do some kind of half NAT-ing of its own, with the wwan connection always using a gateway of 10.0.0.1 (which also appears as a hop in traffic). This doesn't happen on other routers with the same SIM/ISP. The LTE speed doesn't appear to degrade with uptime, varying mostly depending on time of day and network congestion.
- 100 days later, the router appears to work fine, although it doesn't have a 100 days uptime due to some power failures (and dataplan expiry). However, it didn't exhibit the failure mode I was experiencing with the OEM firmware (but that may be just due to the beta modem firmware it is running).
- _Later note_: ~Somehow I managed to lose the content of my device's mtd7 "radio" partition (and what else?)~ The OpenWrt build for MR600 [uses the wrong offset for the `radio` (mtd7) partition](https://forum.openwrt.org/t/tp-link-archer-mr600-exploration/65489/207) and this applies to MR500 as well, which results in low performance for 2.4Ghz and very low power (barely usable) for 5GHz. I haven't noticed this until I actually tried  to use the wirelesses while on decent LTE coverage. Restoring the "radio" partition with [this binary](https://forum.openwrt.org/t/tp-link-archer-mr600-exploration/65489/139) restored full signal and speed for both radios (I was too lazy to extract the device's original radio data from the full flash backup dump. I might still do that at some later date).
- _Aproximately 6 months later_: The modem seems ot run fine with 2 of the 3 operators available in the area. One of the working operators does not provide Carrier Aggregation (4G+), while the other does (the one I also used for testing the OEM firmware). The modem eventually lost connection and required a reboot with a third operator (that also supports CA/4G+). 
- _Aproximately 8 months later_: The router started [randomly freezing on boot](https://forum.openwrt.org/t/tp-link-archer-mr600-exploration/65489/188) on power failures and on cold boots. Investigating the serial console shows that it does complete the boot but the network subsystem is completely non-functional (link status messages are displayed in the console but running `ifconfig` or `service network restart` results in multiple _Command failed: Request timed out_ errors and no resolve). Additionally, at the times when it does boot fine it eventually starts experiencing out-of-memory errors (with various services on it getting killed by the kernel) and finally soft reboots. The memory crashes appear resolved after a clean update to OpenWrt 24.10.2. The random broken network on cold boot persists with 24.10.2.


![openwrt](images/openwrt.png)

> [!NOTE]
> I've kept the modem running firmware version `16121.1009.00.01.02.13` as installed by the `1.7.0 0.9.1 v0001.0 Build 231122 Rel.61263n_Beta` *beta* firmware. The latest non-beta firmware available at [Tp-Link](https://www.tp-link.com/en/support/download/archer-mr500/#Firmware) reverts the modem firmware to `16121.1009.00.01.02.12`. With other versions your results may vary from mine.  
> Release `1.10.0 0.9.1 241219 Rel.42593` appears to update the modem firmware to version `16121.1009.00.01.02.16`.

---
## LTE

> [!IMPORTANT]  
> The Fibocom FG621 modem runs in [RNDIS mode](https://openwrt.org/docs/guide-user/network/wan/wwan/ethernetoverusb_rndis) (internally [mode 38](usb-modes.md)) not QMI as the Qualcomm modem on MR600 does, so the initial WWAN network setup is incorrect. While RNDIS is usable with OpenWrt, for best results the modem should be switched to [NCM mode (mode 36)](usb-modes.md).

_This step is easiest to do with wired WAN connectivity since LTE is not functional yet_

For RNDIS mode use the package manager to install

	kmod-usb-net-rndis

For NCM mode install
	
    luci-proto-ncm
	
Which will in turn also install the required dependencies:

	chat
	comgt
	kmod-usb-serial
	kmod-usb-serial-wwan
	kmod-usb-serial-option
	kmod-usb-net-cdc-ether
	kmod-usb-net-cdc-ncm
	kmod-usb-net-huawei-cdc-ncm
	comgt-ncm
	 
Reboot the router. After the reboot there is a new network device `eth1` or `usb0` (NCM / RNDIS) available.

Use LuCI to delete or edit the pre-configured `wwan0`.  
Create/edit the `wwan0` interface with protocol `DHCP` and attach it to the new `eth1` / `usb0` device.
Or do this manually in `/etc/config/network`:

	config interface 'wwan0'
		option proto 'dhcp'
		option device 'eth1'
		
With RNDIS mode the device should be `usb0` instead.

![wwan0-interface](images/wwan0-eth1.png)

The modem should automatically work out the required APN from the SIM/network (at least it did for me - but I had it configured and working with this network operator in the official firmware before so that may play a part).  
To see the existing APN/PDP configuration, the `AT+CGDCONT?` AT command in `picocom /dev/ttyUSB0` can be used.

At this point the mobile connection should be up and running (check if the wwan0 interface receives an IP address from the ISP, usually in the 10.x.x.x range). This process may take up to several minutes after a (re)boot or a modem restart. 

> [!NOTE]
> If the modem happens to be non-responsive, try the commands suggested in the [4G-AX56 commit message](https://git.openwrt.org/?p=openwrt/openwrt.git;a=commitdiff;h=502916468e2871f7f19b14b521a10ebf28394006) (which uses the same modem):  
> `echo -e "AT+GTAUTOCONNECT=1\r\n" > /dev/ttyUSB0`  
> `echo -e "AT+GTRNDIS=1,1\r\n" > /dev/ttyUSB0`  

### Advanced LTE

For signal monitoring and band selection/locking **4IceG**'s awesome [luci-app-3ginfo-lite](https://github.com/4IceG/luci-app-3ginfo-lite) and [luci-app-modemband](https://github.com/4IceG/luci-app-3ginfo-lite) will do miracles.  
However, the Fibocom modem is not supported in the current (as of December 2024) builds and will require a bit of manual tinkering. 

The install processes for both are best described in their respective repos, but for convenience I have included the versions I successfully tested and modded in the [`lte-advanced/`](lte-advanced/) folder on this repo (in the appropriately numbered order).
Download and use random files off the internet at your discretion.

In the same folder are also the necessary tweaked and new files that are required for modem support.

#### 3ginfo-lite

1. Install the appropriate architecture `sms-tool` ipk.

2. Install `luci-app-3ginfo-lite` ipk. 

Force refresh or logout/login to LuCI and navigate to the **Modem > Information ...** submenu.  
Switch to the **Configuration** tab and set:

- _Interface_ option to `wwan0`
- _Port for modem_ to `/dev/ttyUSB0`

Save and Apply.

You'll notice there is still no information on the **Details** tab. 

3. Patch `/usr/share/3ginfo-lite/3ginfo.sh` using SCP or the console according to [these changes](https://github.com/4IceG/luci-app-3ginfo-lite/compare/main...thezedt:luci-app-3ginfo-lite:fg621?diff=split&w=#diff-bfb9df31e7c9175e9d10b5dca27891b6c20b9997ed0df263b257f34796d5067a).

4. Inside the `/usr/share/3ginfo-lite/modem/` subfolder create a new file named **`2cb70a05`** (the VID/PID of the modem) with [this content](https://github.com/4IceG/luci-app-3ginfo-lite/compare/main...thezedt:luci-app-3ginfo-lite:fg621?diff=split&w=#diff-81e9e3e254e33b574ed506eb3df71e979e8ca6c33126616a4eecc5c9050dbe60).

Once both files are edited/created successfully, the details should finally be displayed in LuCI (after a while or a refresh).

![3ginfolite](images/3ginfo-telekom.png)

#### modemband

1. Install the `modemband` apk.

2. Install `luci-app-modemband` apk. 

Force refresh or logout/login to LuCI and navigate to the **Modem > Prefered Bands** submenu.  
Switch to the **Configuration** tab and set:

- _Interface_ option to `wwan0`
- _Port for modem_ to `/dev/ttyUSB0`
	
If you choose to enable modem restart after bands change, to ensure successful change adjust the preset restart command to:

	AT+CFUN=15

Save and Apply.

You'll notice an error message and lack of information on the **Preferred LTE bands** tab.

3. Use SCP or the console to explore the router's filesystem and navigate to `/usr/share/modemband/`.

Inside create a new file named **`2cb70a05`** (the VID/PID of the modem) with [this content](lte-advanced/usr_share/modemband/2cb70a05).

Complete modem initialization after a band change can take up to several minutes, so be patient if the information pages don't work for a while (even if the mobile connection is working). 

![modemband](images/modemband.png)

#### Signal level LEDs

Probably starting from [this script](https://forum.openwrt.org/t/cellular-signal-level-indicator/60543/15), it can be adapted to read signal level with AT commands instead of (unavailable) `uqmi`. `3ginfo-lite` should be able to provide the inspiration for this. 

## MR500v1 dedicated OpenWrt build

I'm aiming to test the router (and modem) stability for about a month of uptime (that's about the maximum connection uptime I've had with the official beta firmwares before connectivity went bust) before putting the extra work in for the next steps.  

> [!TIP]
> While a dedicated firmware build for MR500v1 would be nice, if you don't care for the incorrect labelling in LuCI you can use the [OpenWrt Firmware Selector](https://firmware-selector.openwrt.org/?target=ramips%2Fmt7621&id=tplink_mr600-v2-eu) right now to build a MR600-based firmware that's usable out-of-the-box (and also after a configuration reset).  
> Simply select the desired OpenWrt release (from those available), then customize the packages list to include `luci-proto-ncm` (the builder will handle the necessary dependencies). You can remove the two existing _qmi_ packages to same some space.
> Then pre-configure the `wwan` network interface using the **first boot (uci-defaults)** script:  
> `uci set network.wwan0=interface`  
> `uci set network.wwan0.proto='dhcp'`  
> `uci set network.wwan0.device='eth1'`  
> `uci commit network`  
> Finally build and download the custom `sysupgrade` image and use it to flash the router at the second step (or later as an upgrade).

## Failsafe

If you need to boot the MR500 in [failsafe mode](https://openwrt.org/docs/guide-user/troubleshooting/failsafe_and_factory_reset), press the **Reset/WPS** button once or twice while the power led is blinking quickly after power-on. After a few seconds the led should start blinking even faster. 

Plug the network cable into the **LAN1 port** as that is the only one active in failsafe mode and connect to 192.168.1.1 via SSH.

## Reverting to OEM firmware

If you ever want to revert back to the Tp-Link firmware, reset the modem mode back to RNDIS and disable autoconnect beforehand:
	
	AT+GTAUTOCONNECT=0
	
	AT+GTRNDIS=0
	
	AT+GTUSBMODE=38

If you have perhaps enabled IP (by)pass to prevent double NAT under OpenWrt (like me), remember to also undo that. Check status and reset to `0` (default) if necessary:
	
	AT+GTIPPASS?
	
	AT+GTIPPASS=0

Finally restart the modem to apply changes:

	AT+CFUN=15
	
You can then use the [recovery image](/recovery/mr500v1_recovery_rel42593.bin) I prepared (or make your own) to flash directly from within LuCI (use the force option to bypass metadata check) or using `mtd -r write /tmp/mr500v1_recovery_rel42593.bin firmware` after copying the file over. 

For those who have completely messed up their flash, I have also uploaded a [full flash chip firmware dump](/oem-fw/flash-dump-20250803-retailfw-1.7.0-0.9.1-v0001.0-Build-231122-Rel.61263n_Beta-WORKING-factoryreset-noMACnoIMEI.bin) of an OEM retail release (it's a beta build but can be updated to a newer release). Keep in mind this contains device-specific information so I've censored my MAC address and IMEI in it. 
Use a hex editor and look for `F0F1F2F3F4F5F6` at address `0xFCF100` and replace that with your MAC, and `001122334455667` at address `0xFCF500` with your IMEI (I'm not sure if the modem actually uses this from the firmware, or it may there just to show it in the administration interface).


## Somewhat of a conclusion

The modem stability seems to have improved either in time (thanks to the firmware update installed by the beta build) or thanks to OpenWrt management, however the random network issues on boot prevent me from using this device in remote locations where access over its LTE link is needed for management.  
So for now I have decided to revert back to the OEM firmware (which has received two new releases in the meantime, including one that changes the modem firmware - perhaps also resolving/improving the LTE stability) and plan to use this router as one of several uplinks for a more stable OpenWrt device that I can remote into using the (still functional) uplinks.