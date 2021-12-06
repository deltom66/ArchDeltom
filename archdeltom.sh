#!/bin/bash

    bash 0-preinstall.sh
    arch-chroot /mnt /root/ArchDeltom/1-setup.sh
    source /mnt/root/ArchDeltom/install.conf
    arch-chroot /mnt /usr/bin/runuser -u $username -- /home/$username/ArchDeltom/2-user.sh
    arch-chroot /mnt /root/ArchDeltom/3-post-setup.sh