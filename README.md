# rpi-mkimg #

### mkimg.sh ###
Create a distributable image from a Raspberry Pi SD card.

### mkimg-pine64.sh ###

Create a distributable image from a Pine64 SD card.
                                                          
**NOTE**: This script has **not** been used for imaging irreplaceable data.
While this script *should not* be destructive, it modifies the filesystem and
partition table.

## WARNING: ALWAYS BACKUP YOUR CARD FIRST ##

It can be run like this:

```
bash mkimg.sh /dev/sda sdcard.img.zip
```

My command for creating NEMS build for Raspberry Pi is:

```
./mkimg.sh /dev/sdc NEMS_v1.3.img.zip
```

My command for creating NEMS build for Pine64 is:

```
./mkimg-pine64.sh /dev/sdc NEMS_v1.3.img
```

## What does the script do ##

Under the hood the script performs the following operations:

- [mkimg.sh only] ensures the first partition is `fat32` and the second partition `ext4`
- fixes any errors on the filesystem
- shrinks the Linux filesystem to its smallest size
- shrinks the Linux partition to the size of the filesystem + small buffer
- creates a image from the given device
- [mkimg.sh only] compresses the image to a zip file
- [mkimg-pine64.sh only] create matching md5 checksum file
- expands the partition and filesystem back to their largest sizes


## Flash SD card with the image ##

### Linux ###

Replace `<device>` with the location of your SD card; e.g. `/dev/sda`:

```
unzip -p sdcard.img.zip | sudo dd bs=1M of=<device>
```


### Mac ###

Replace `<device>` with the location of your SD card; e.g. `/dev/rdisk1`:

```
unzip -p sdcard.img.zip | sudo dd bs=1m of=<device>
```


### Windows ###

Use the [WIN32 Disk Imager](https://sourceforge.net/projects/win32diskimager/) tool.
