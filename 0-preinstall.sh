#!/usr/bin/env bash
#-------------------------------------------------------------------------
#                        █                    ███                        
#   ██                 █      ████▒           █      █                 
#   ██                 █      █  ▒█░          █      █                 
#  ▒██▒   █▒██▒  ▓██▒  █▒██▒  █   ▒█  ███     █    █████   ███   ██▓█▓ 
#  ▓▒▒▓   ██  █ ▓█  ▓  █▓ ▒█  █    █ ▓▓ ▒█    █      █    █▓ ▓█  █▒█▒█ 
#  █░░█   █     █░     █   █  █    █ █   █    █      █    █   █  █ █ █ 
#  █  █   █     █      █   █  █    █ █████    █      █    █   █  █ █ █ 
# ▒████▒  █     █░     █   █  █   ▒█ █        █      █    █   █  █ █ █ 
# ▓▒  ▒▓  █     ▓█  ▓  █   █  █  ▒█░ ▓▓  █    █░     █░   █▓ ▓█  █ █ █ 
# █░  ░█  █      ▓██▒  █   █  ████▒   ███▒    ▒██    ▒██   ███   █ █ █                                                                      
#-------------------------------------------------------------------------
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
echo "-------------------------------------------------"
echo "Setting up mirrors for optimal download          "
echo "-------------------------------------------------"
iso=$(curl -4 ifconfig.co/country-iso)
timedatectl set-ntp true
pacman -S --noconfirm pacman-contrib terminus-font
setfont ter-v22b
sed -i 's/^#Para/Para/' /etc/pacman.conf
pacman -S --noconfirm reflector rsync grub
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
echo -e "-------------------------------------------------------------------------"
echo -e "                        █                    ███                        
echo -e "   ██                 █      ████▒           █      █                 
echo -e "   ██                 █      █  ▒█░          █      █                 
echo -e "  ▒██▒   █▒██▒  ▓██▒  █▒██▒  █   ▒█  ███     █    █████   ███   ██▓█▓ 
echo -e "  ▓▒▒▓   ██  █ ▓█  ▓  █▓ ▒█  █    █ ▓▓ ▒█    █      █    █▓ ▓█  █▒█▒█ 
echo -e "  █░░█   █     █░     █   █  █    █ █   █    █      █    █   █  █ █ █ 
echo -e "  █  █   █     █      █   █  █    █ █████    █      █    █   █  █ █ █ 
echo -e " ▒████▒  █     █░     █   █  █   ▒█ █        █      █    █   █  █ █ █ 
echo -e " ▓▒  ▒▓  █     ▓█  ▓  █   █  █  ▒█░ ▓▓  █    █░     █░   █▓ ▓█  █ █ █ 
echo -e " █░  ░█  █      ▓██▒  █   █  ████▒   ███▒    ▒██    ▒██   ███   █ █ █                                                                      
echo -e "-------------------------------------------------------------------------"
echo -e "-Setting up $iso mirrors for faster downloads"
echo -e "-------------------------------------------------------------------------"

reflector --latest 20 --protocol https --country India,Germany,Singapore --sort rate --save /etc/pacman.d/mirrorlist
mkdir /mnt


echo -e "\nInstalling prereqs...\n$HR"
pacman -S --noconfirm gptfdisk btrfs-progs

echo "-------------------------------------------------"
echo "-------select your disk to format----------------"
echo "-------------------------------------------------"
lsblk
echo "Please enter disk to work on: (example /dev/sda)"
read DISK
echo "THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK"
read -p "are you sure you want to continue (Y/N):" formatdisk
case $formatdisk in

y|Y|yes|Yes|YES)
echo "--------------------------------------"
echo -e "\nFormatting disk...\n$HR"
echo "--------------------------------------"

# disk prep
sgdisk -Z ${DISK} # zap all on disk
sgdisk -a 2048 -o ${DISK} # new gpt disk 2048 alignment

# create partitions
sgdisk -n 1::+300M --typecode=2:ef00 --change-name=1:'EFIBOOT' ${DISK} # partition 1 (UEFI Boot Partition)
sgdisk -n 2::+1G --typecode=2:8200 --change-name=2:'SWAP' ${DISK} # partition 2 (SWAP Partition), default start
sgdisk -n 3::-0 --typecode=3:8300 --change-name=3:'ROOT' ${DISK} # partition 3 (Root), default start, remaining
if [[ ! -d "/sys/firmware/efi" ]]; then
    sgdisk -A 1:set:1 ${DISK}
fi

# make filesystems
echo -e "\nCreating Filesystems...\n$HR"
if [[ ${DISK} =~ "nvme" ]]; then
mkfs.vfat -F32 -n "EFIBOOT" "${DISK}p1"
mkswap -L "SWAP" "${DISK}p2" -f
swapon "${DISK}p2"
mkfs.btrfs -L "ROOT" "${DISK}p3" -f
mount -t btrfs "${DISK}p3" /mnt

else
mkfs.vfat -F32 -n "EFIBOOT" "${DISK}1"
mkswap -L "SWAP" "${DISK}p2" -f
swapon "${DISK}p2"
mkfs.btrfs -L "ROOT" "${DISK}3" -f
mount -t btrfs "${DISK}3" /mnt
fi
ls /mnt | xargs btrfs subvolume delete
btrfs subvolume create /mnt/@
umount /mnt
;;
*)
echo "Rebooting in 3 Seconds ..." && sleep 1
echo "Rebooting in 2 Seconds ..." && sleep 1
echo "Rebooting in 1 Second ..." && sleep 1
reboot now
;;
esac

# mount target
mount -t btrfs -o subvol=@ -L ROOT /mnt
mkdir /mnt/boot
mkdir /mnt/boot/efi
mount -t vfat -L EFIBOOT /mnt/boot/efi

if ! grep -qs '/mnt' /proc/mounts; then
    echo "Drive is not mounted can not continue"
    echo "Rebooting in 3 Seconds ..." && sleep 1
    echo "Rebooting in 2 Seconds ..." && sleep 1
    echo "Rebooting in 1 Second ..." && sleep 1
    reboot now
fi

echo "--------------------------------------"
echo "-- Arch Install on Main Drive       --"
echo "--------------------------------------"
pacstrap /mnt base base-devel linux linux-firmware linux-headers git vim nano sudo archlinux-keyring wget libnewt --noconfirm --needed
genfstab -U /mnt >> /mnt/etc/fstab
echo "keyserver hkp://keyserver.ubuntu.com" >> /mnt/etc/pacman.d/gnupg/gpg.conf
cp -R ${SCRIPT_DIR} /mnt/root/ArchDeltom
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
echo "--------------------------------------"
echo "--GRUB BIOS Bootloader Install&Check--"
echo "--------------------------------------"
if [[ ! -d "/sys/firmware/efi" ]]; then
    grub-install --boot-directory=/mnt/boot/efi ${DISK}
fi
#echo "--------------------------------------"
#echo "-- Check for low memory systems <8G --"
#echo "--------------------------------------"
#TOTALMEM=$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')
#if [[  $TOTALMEM -lt 8000000 ]]; then
#    #Put swap into the actual system, not into RAM disk, otherwise there is no point in it, #it'll cache RAM into RAM. So, /mnt/ everything.
#    mkdir /mnt/opt/swap #make a dir that we can apply NOCOW to to make it btrfs-friendly.
#   chattr +C /mnt/opt/swap #apply NOCOW, btrfs needs that.
#   dd if=/dev/zero of=/mnt/opt/swap/swapfile bs=1M count=2048 status=progress
#   chmod 600 /mnt/opt/swap/swapfile #set permissions.
#   chown root /mnt/opt/swap/swapfile
#   mkswap /mnt/opt/swap/swapfile
#   swapon /mnt/opt/swap/swapfile
#   #The line below is written to /mnt/ but doesn't contain /mnt/, since it's just / for the #sysytem itself.
#    echo "/opt/swap/swapfile	none	swap	sw	0	0" >> /mnt/etc/fstab #Add #swap to fstab, so it KEEPS working after installation.
#fi
echo "--------------------------------------"
echo "--   SYSTEM READY FOR 1-setup       --"
echo "--------------------------------------"