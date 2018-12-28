#!/bin/bash

LOG_FILE=abiquo-kvm-install.log
LIBVIRT_GUEST_CONF=/etc/sysconfig/libvirt-guests
# Change this URL if you want to use a local repository:
MIRROR_URL=http://mirror.abiquo.com/abiquo/el6/

echo -n "Checking distribution... "
if [ -f "/etc/redhat-release" ]; then
        head -n1 "/etc/redhat-release"
    else
        echo "Unsupported distribution found." 
        exit 1
fi

echo -n "Stopping AIM..."
# Stop aim service
service abiquo-aim stop >> $LOG_FILE 2>&1
if [ $? == 0 ]; then
   echo "Done."
else
   echo "Failed!"
fi

echo -n "Upgrading packages..."
# Remove package locks from yum.conf
sed -i /exclude=libvirt/d /etc/yum.conf >> $LOG_FILE 2>&1
sed -i /abiquo/d /etc/yum.conf >> $LOG_FILE 2>&1

#Install abiquo release
rpm -Uvh $MIRROR_URL/2.6/os/x86_64/abiquo-release-ee-2.6.0-1.el6.noarch.rpm >> $LOG_FILE 2>&1

# Upgrade packages
yum clean all >> $LOG_FILE 2>&1
yum -y upgrade abiquo-cloud-node abiquo-aim libvirt qemu-kvm >> $LOG_FILE 2>&1
if [ $? == 0 ]; then
    echo "Done."
else
    echo "Failed! Check $LOG_FILE"
    exit 1
fi

echo -n "Upgrading libvirt guests... "
# Change machine model
find /etc/libvirt/qemu/ABQ*.xml -exec sed -i s,pc-0.13,pc,g {} \; >> $LOG_FILE 2>&1
# Delete BIOS loader
find /etc/libvirt/qemu/ABQ*.xml -exec sed -i /loader/d {} \; >> $LOG_FILE 2>&1
# Redefine all guests 
find /etc/libvirt/qemu/ABQ*.xml -exec virsh define {} \; >> $LOG_FILE 2>&1
# Disable suspend
sed -i "s,#ON_SHUTDOWN=suspend,ON_SHUTDOWN=shutdown," $LIBVIRT_GUEST_CONF >>     $LOG_FILE 2>&1
echo "Done."

echo -n "Starting aim... "
# Start aim service
service abiquo-aim start >> $LOG_FILE 2>&1
echo "Done."

