#!/bin/bash

exit

#Probably just going to use gparted + dd
# using gparted, resize the main Linux partition (second partition of drive) to ~200MB+ larger than the actual data on drive
# For our example, we'll say 4700 (which is MB)
# Apply and run: dd if=/dev/sdb of=/tmp/t/NEMS/NEMS_v1.4.1-Pine64-Build2.img bs=1M count=4701
# note the count is 1 block larger than the actual data to avoid truncating any actual data.

# Because disk may have more than one partition, instead:
# Copy the Last Sector of the last partition within gparted
# Run: dd if=/dev/sdb of=/tmp/t/NEMS/NEMS_v1.4.1-Pine64-Build2.img bs=512 count=[ceil(last sector * 512)]

# The below script resulted in a non-bootable image, but the above commands worked... so will have to re-work this.
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: You are not root" 2>&1
  exit 1
else
    # Specify dependencies
    declare -a depends=("parted")

    # do not continue of there are errors
    set -e

    device=$1
    imgfile=$2
    linux_partition=${device}2

    # sanity checks on the command line parameters
    if [ "${device}" == "" ]; then
        echo "Please specify device, e.g. $0 /dev/sda <filename>" 1>&2;
        exit 1;
    fi;
    
    if [ "${imgfile}" == "" ]; then
        echo "Please specify filename, e.g. $0 <device> myimage.img" 2>&1;
        exit 1;
    fi;
    
    # Check for, install, and verify dependencies
    if [ $(command -v yum) ]; then
      PACMAN="$(command -v yum) --y install "
    fi
    if [ $(command -v apt-get) ]; then
      PACMAN="$(command -v apt-get) --allow-unauthenticated --yes install "
    fi

    for i in "${depends[@]}"
      do
          echo Testing dependency \"$i\"...
          if [ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ] && [ $(rpm -qa 2>/dev/null | grep -c $i) -eq 0 ]; then
              echo "Not installed. Installing $i..."
              $PACMAN $i
              if [ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ] && [ $(rpm -qa 2>/dev/null | grep -c $i) -eq 0 ]; then
                echo "Installation of $i failed. Please install it manually and run this script again."
                exit 1;
              else
                echo "$i was successfully installed."
              fi
          else
            echo "$i is installed. Proceeding."
          fi
      done
   
    fdisk -l ${device} | grep -q "${device}2.*Linux"
    if [ "$?" != "0" ]; then
        echo 'The second partition is expected to be Linux' 1>&1;
        exit 1;
    fi;
    
    # converts and pads given bytes into MB
    # Takes the given number in bytes and (by nature of integer division) rounds
    # the number of bytes down to the nearest hundred bytes.  That value is then
    # padded by 200MB.  The padding was determined by trial and error when
    # attempting to image a 1.6GB linux partition.
    # TODO: determine a better way to calculate the padding.
    function convert_bytes()
    {
        local bytes=$1
        local rounded=0
    
        let rounded="((${bytes}/100000000)+2)*100"
    
        echo ${rounded}
    }
    
    # start the dangerous stuff
    
    e2fsck -f ${linux_partition}
    
    # call resize2fs to shrink the partition down to the minimum size it needs to be.
    # parse the output to know how big the partition is in bytes
    let bytes=`resize2fs -M ${linux_partition} 2>&1 | grep -i -e "The filesystem .*is .*blocks long" | sed -e 's/.*is [^ ]* \([0-9]*\).* blocks.*/\1*4096/'`
    
    # convert the value in bytes returned by resize2fs to MB
    let megs_rounded=`convert_bytes ${bytes}`
    
    # use parted to shrink the partition down.
    # when shrinking the partition down parted will prompt for confirmation.  the
    # following post notes to append yes to the operation:
    # https://bugs.launchpad.net/ubuntu/+source/parted/+bug/1270203/comments/2
    parted --align optimal ${device} unit MB resizepart 2 ${megs_rounded} yes
    
    # use last value in the `End` column to know how much to image
    let total_bytes=`parted ${device} unit B print | grep -v '^$' | awk '{print $3}' | tail -n 1 | sed -e 's/B//'`;
    let total_megs_rounded=`convert_bytes ${total_bytes}`
    
    
    # drop the .img to disk
    dd bs=1M if=${device} of=${imgfile} count=${total_megs_rounded}

    # create md5
    printf "Creating MD5 checksum..."
    md5sum ${imgfile} > ${imgfile}.md5
    echo " Done."

    # expand the filesystem back
    full_size=$(parted ${device} print | grep "Disk ${device}" | awk '{print $3}')
    parted ${device} resizepart 2 ${full_size}
    
    # wait up to 10 seconds for the linux partition to show up
    for i in {0..9}; do
        [ -e ${linux_partition} ] && break
        sleep 1
    done;
    
    # if the linux partition didn't show up, this will fail
    resize2fs ${linux_partition}

fi
