# OpenWrt on Tp-Link MR500v1 (EU) adventure

Ever since I got this router I encountered connection stability issues (well reported on the Tp-Link forums 
[here](https://community.tp-link.com/en/home/forum/topic/649224), 
[here](https://community.tp-link.com/en/home/forum/topic/605538), 
[here](https://community.tp-link.com/en/home/forum/topic/616946), 
[here](https://community.tp-link.com/en/home/forum/topic/603938)...), and as soon as I took it apart and discovered it uses an OpenWrt supported platform (MT7621 / mipsel_24kc) I looked into finding a way to bring OpenWrt on it (and hopefully resolve the disconnection issues, or at least find a better workaround than scheduled daily router reboots). 

**The MR500 v1 (EU) is identical on first look at the PCB with its (supported) bigger brother MR600v2, but uses a different LTE modem.**

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

Since Tp-Link really enjoys versioning out their devices and mix-matching the hardware used in them it's necessary to first identify your device properly.

Software signature:

![software-version](images/software.png)

Hardware label:

![hardware-label](images/hardware-label.jpg)

_My device initially ran operator-specific firmware, hence the (ROORG) labeling._

---
> [!CAUTION]
> **Don't proceed unless you create full flash backups, are comfortable around flash programmers and/or bricked devices or can easily afford to buy a new router.**
> **Opening the device to access the serial console will also most likely void your warranty (and definitely break some/all plastic clips)**

## Installation

> [!IMPORTANT]  
> I have **only** used the serial console method as described in the [MR600's commit message](https://git.openwrt.org/?p=openwrt/openwrt.git;a=commitdiff;h=78110c3b5fce119d13cd45dadd33ca396c8ce197) to install OpenWrt on the MR500.  
> While a `factory` image exists, the MR600 does not have a device page yet so I cannot confirm if it is possible to migrate to OpenWrt directly through the Tp-Link web interface. Perhaps [this discussion](https://forum.openwrt.org/t/tp-link-archer-mr600-exploration/65489?page=5) holds the answer.
> If that is already supported, the same `factory` image may or may not work with MR500's OEM web interface to allow for firmware migration - this will remain your test to take. 

1. Start a TFTP server - [Tftpd64](https://pjo2.github.io/tftpd64/) will do just fine

Configure the computer's network adapter and the TFTP server to listen on 192.168.0.5/24. Connect to the router using one of the 3 LAN ports.

2. Download the [MR600v2 OpenWrt initramfs (kernel) image](https://firmware-selector.openwrt.org/?version=23.05.5&target=ramips%2Fmt7621&id=tplink_mr600-v2-eu) from the ImageBuilder (either 23.05.x or 24.10.x will do)

Place it into the TFTP server's root directory and rename it to `test.bin`

3. Connect to the router's serial console with a USB/TTL adapter.

If you want to poke around the Tp-Link firmware first, the login credentials are _admin / 1234_

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

4. Transfer the firmware [via TFTP](logs/tftp-flash-log.txt) and then instruct U-Boot to boot OpenWrt from ram:
    
    ```
    # tftpboot
	
	...transfer happens here...
	
    # bootm
    ```

The router will boot the kernel image and start OpenWrt in _recovery mode_.
	
5. With OpenWrt booted in **_recovery (initramfs)_** mode, use the web interface or console to install the `sysupgrade` OpenWrt firmware (which you can also obtain from the ImageBuilder).

After another reboot you should find yourself in the permanently installed OpenWrt firmware.

### Status

**What works:**
- WAN and LAN 1-3 ports are correctly identified and work as expected.
- Both 2.4G and 5G wirelesses are recognized and functional (I didn't do throughput tests as I mostly focused on getting the mobile connection up and running, which provides nowhere near the wireless bandwidth capabilities). 
- LEDs are all functional (and also configurable through LuCI):
	- Power, WAN, LAN and WIFI work out-of-the-box. The single WIFI led is attached to the 5G wireless by default, but can be reassigned in LuCI. 
	- The 4G+ led can be configured to indicate WWAN status (but no longer differentiates between 4G and 4G+ connectivity as with the retail firmware).
	- _The mobile signal leds are a task for another day._
- Individual signal numbers seem in the correct range, but I have no precise way of confirming them.
- At least some of the LTE status info is confirmed correct (Operator, MCC, NMC, Cell ID, Primary band, Modem firmware model and version).
- Carrier aggregation and second band info works ([(1)](images/3ginfo-CA-3&20.png), [(2)](images/3ginfo-CA-7&20.png)) with the patched [3ginfolite script](lte-advanced/usr_share/3ginfolite/3ginfo.sh). 
	- Speeds are on par with another MT7621-based router running a Qualcomm EM12 modem placed side by side and on the same mobile operator and identical data plan.

**What doesn't work:**
- So far everything seems to work for basic functionality. Advanced LTE monitoring/band locking require additional steps as described below. 
	- ~_Secondary band functionality and reporting need to be tested with a CA-capable SIM/operator._~
	- 3ginfo status page fails randomly and after being left open and refreshing for a while. Force refreshing several times or logging out of LuCI and logging back in seems to return it to functioning order. I assume either the modem is slow to respond or randmly returns unexpected or garbage data. 
- Stability improvements remain to be tested... Watchcat can easily handle the modem restarts if it misbehaves like with the official firmware. 

![openwrt](images/openwrt.png)

---
## LTE

> [!NOTE]
> The Fibocom FG621 modem runs in NCM mode (internally [mode 36](usb-modes.md)) not QMI as the Qualcomm modem on MR600 does, so the initial WWAN network setup is incorrect.

_This initial step is easiest to do with wired WAN connectivity since LTE is not functional yet_

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
    
Reboot the router. After the reboot there is a new network device `eth1` available.

Use LuCI to delete pre-configured `wwan0`.  
Create a new `wwan0` interface with protocol `DHCP` and attached to the new `eth1` device.  
Or do this manually in `/etc/config/network`:

	config interface 'wwan0'
		option proto 'dhcp'
		option device 'eth1'

![wwan0-interface](images/wwan0-eth1.png)

The modem should automatically work out the required APN from the SIM/network (at least it did for me - but I'ave had it configured and working with the official firmware before).  
To get the existing APN/PDP configuration, the `AT+CGDCONT?` AT command can be used.

At this point the mobile connection should be up and running (check if the wwan0 interface receives an IP address from the ISP). This process may take up to several minutes after (re)boot or a modem restart. 

### Advanced LTE

For signal monitoring and band selection/locking **4IceG**'s awesome [luci-app-3ginfo-lite](https://github.com/4IceG/luci-app-3ginfo-lite) and [luci-app-modemband](https://github.com/4IceG/luci-app-3ginfo-lite) will do miracles.  
However, the Fibocom modem is not supported in the current (as of December 2024) builds and will require a bit of manual tinkering. 

The install processes for both are best described in their respective repos, but for convenience I have included the versions I successfully tested and tweaked in the [`lte-advanced/`](lte-advanced/) folder on this repo (in the appropriately numbered order). Download and use random files off the internet at your discretion. 

In the same folder are also the necessary tweaked and new files that are required for modem support.

#### 3ginfo-lite

1. Install the appropriate architecture `sms-tool` ipk.

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

Now locate the `modem` subfolder. Inside create a new file named **`2cb70a05`** (the VID/PID of the modem) with [this content](lte-advanced/usr_share/3ginfolite/modem/usb/2cb70a05).

Once both files are edited/created successfully, the details should finally be displayed in LuCI (after a while or a refresh).

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