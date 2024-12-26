# My OpenWrt on Tp-Link MR500v1 (EU) adventure


Ever since I got this router I encountered connection stability issues (well reported on the Tp-Link forums here, here, here...), and as soon as I took it apart and discovered it uses an OpenWrt supported platform (MT7621 / mipsel_24kc) I looked into finding a way to bring OpenWrt on it (and hopefully resolve the disconnection issues, or at least find a better workaround than daily router reboots). 


**The MR500 v1 (EU) is nearly identical with its (supported) bigger brother, MR600v2 which uses a different LTE modem.**

### Identification:

Since Tp-Link really enjoys versioning out their devices and mix-matching the hardware used in them it's necessary to first identify your device.

Software signature:

![software-version](images/software.png)

Hardware label:

![hardware-label](images/hardware-label.jpg)

_My device initially ran operator-specific firmware, hence the (ROORG) labelling._

### Specifications:

* SoC: [Mediatek MT7621DAT 880MHz](photos/PIC_20240106_200715.JPG)
* RAM: 128MB DDR3
* Flash: 16MB SPI NOR flash [(EN25)QH128A-104HIP](photos/PIC_20240106_200626.JPG)
* LTE Modem: [**Fibocom FG621-EA**](photos/PIC_20240106_200843.JPG)
* WiFi 5GHz: [Mediatek MT7613BEN](photos/PIC_20240106_200807.JPG)
* WiFi 2.4GHz: [Mediatek MT7603EN](photos/PIC_20240106_200817.JPG)
* Ethernet: MT7530, 4x 1000Base-T.
* UART: [Serial console (115200 8n1), J1(GND:3)](photos/PIC_20240106_201317.JPG)
* Buttons: Reset, WPS.
* LED: Power, WAN, 4G+, single WiFi (2GHz and/or? 5GHz), LAN, Signal1, Signal2, Signal3 

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

---
## Installation

> [!IMPORTANT]  
> I have **only** used the serial console method as described in the [MR600's commit message](https://git.openwrt.org/?p=openwrt/openwrt.git;a=commitdiff;h=78110c3b5fce119d13cd45dadd33ca396c8ce197) to install OpenWrt on the MR500.  
> While a `factory` image exists, the MR600 does not have a device page yet so I cannot confirm if it is possible to migrate to OpenWrt directly through the Tp-Link web interface. Perhaps [this discussion](https://forum.openwrt.org/t/tp-link-archer-mr600-exploration/65489?page=5) holds the answer.
> If that is already supported, the same `factory` image may or may not work with MR500's OEM web interface to allow for firmware migration - this will remain your test to take. 

1. Download the [MR600v2 OpenWrt initramfs-image](https://firmware-selector.openwrt.org/?version=23.05.5&target=ramips%2Fmt7621&id=tplink_mr600-v2-eu) (either 23.05.x or 24.10.x will do)

Place it into a TFTP server root directory and rename it to `test.bin`  
Configure the TFTP server to listen at 192.168.0.5/24. Connect to the router using one of the 3 LAN ports.

3. Connect to the serial console.

Attach power and interrupt the U-Boot boot procedure when prompted (type `tpl`).

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

				 <--- around here type 'tpl' quickly

4: System Enter Boot Command Line Interface.

U-Boot 1.1.3 (Nov 22 2023 - 16:37:42)
MT7621 #
```

If you want to poke around the OEM firmware first, the login credentials are _admin / 1234_

4. Transfer the firmware via TFTP and then configure U-Boot to boot OpenWrt from ram:
    
    ```
    # tftpboot
    # bootm
    ```
    
5. With OpenWrt booted in _recovery (initramfs)_ mode, use the web interface (or console) to install the `sysupgrade` OpenWrt firmware.

---
## LTE

> [!NOTE]
> The Fibocom FG621 modem runs in NCM mode (internally [mode 36](usb-modes.md)), not QMI as the modem on MR600 does, so the initial WWAN network setup is incorrect.

Use the package manager to install
	
    luci-proto-ncm
	
This will in turn also install the required dependencies:

	chat
	comgt
	kmod-usb-serial
	kmod-usb-serial-wwan
	kmod-usb-serial-option
	kmod-usb-net-cdc-ether
	kmod-usb-net-cdc-ncm
	kmod-usb-net-huawei-cdc-ncm
	comgt-ncm
    
Reboot the router. After the reboot there is a new network device available as `eth1`.

Use LuCI to delete pre-configured `wwan0`.  
Create a new `wwan0` interface with protocol `DHCP` and attached to the new `eth1` device.  
Or do it manually in `/etc/config/network`:

	config interface 'wwan0'
		option proto 'dhcp'
		option device 'eth1'

![wwan0-interface](images/wwan0-eth1.png)

The modem should automatically figure out the required APN from the SIM/network (at least it did for me).  
At this point the mobile connection should be up and running (check if the wwan0 interface receives an IP address from the ISP). This process may take up to several minutes after (re)boot or a modem restart. 

### Advanced LTE

For signal monitoring and band selection/locking **4IceG**'s awesome [luci-app-3ginfo-lite](https://github.com/4IceG/luci-app-3ginfo-lite) and [luci-app-modemband](https://github.com/4IceG/luci-app-3ginfo-lite) will do miracles.  
However, the Fibocom modem is not supported in the current (as of December 2024) builds and will require a bit of manual tinkering. 

The install processes for both are best described in their respective repos, but for convenience I have included the versions I successfully tested and tweaked in the [`lte-advanced/`](lte-advanced/) folder on this repo (in the appropriately numbered order).

In the same folder are also the necessary tweaked and new files that are required for modem support.

#### 3ginfo-lite

1. Install the apropiate achitecture `sms-tool` ipk.

2. Install `luci-app-3ginfo-lite` ipk. 

Force refresh or logout/login to LuCI and navigate to the **Modem > Information ...** submenu.  
Switch to the **Configuration** tab and set:

- _Interface_ option to `wwan0`
- _Port for modem_ to `/dev/ttyUSB0

Save and Apply.

You'll notice there is still no information on the **Details** tab. 

3. Patch [3ginfo.sh](lte-advanced/usr_share/3ginfolite/3ginfo.sh)

Use SCP or the console to explore the router's filesystem and navigate to `/usr/share/3ginfo-lite/`.  
Here, edit `3ginfo.sh`, look for 
	
	O=$(sms_tool -D -d $DEVICE at "AT+CPIN?;+CSQ;+COPS=3,0;+COPS?;+COPS=3,2;+COPS?;+CREG=2;+CREG?")
	
and replace with

	O=$(sms_tool -D -d $DEVICE at "AT+CSQ;+COPS=3,0;+COPS?;+COPS=3,2;+COPS?;+CREG=2;+CREG?")
	
then save the changes.

4. Add modem-specific file

Also here, identify the `modem` subfolder. Inside create a new file named **`2cb70a05`** (the VID/PID of the modem) with [this content](lte-advanced/usr_share/3ginfolite/modem/2cb70a05).

Once both files are edited/created successfully, the details should finally be displayed in LuCI.

![3ginfolite](images/3ginfo-telekom.png)

#### modemband

1. Install the `modemband` apk.

2. Install `luci-app-modemband` apk. 

Force refresh or logout/login to LuCI and navigate to the **Modem > Prefered Bands** submenu.  
Switch to the **Configuration** tab and set:

- _Interface_ option to `wwan0`
- _Port for modem_ to `/dev/ttyUSB0`
	
If you choose to enable modem restart after bands change, to ensure successful change, adjust the preset restart command to 

	AT+CFUN=15

Save and Apply.

You'll notice an error message and lack of information on the **Preferred LTE bands** tab. 

3. Use SCP or the console to explore the router's filesystem and navigate to `/usr/share/modemband/`.

Inside create a new file named **`2cb70a05`** (the VID/PID of the modem) with [this content](lte-advanced/usr_share/modemband/2cb70a05).

Complete modem initialization after a band change can take up to several minutes, so be patient if the information pages don't work for a while (even if the mobile connection is working). 

![modemband](images/modemband.png)

#### Signal level LEDs

Next leg of the adventure...