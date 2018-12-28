#!/bin/bash

YUM_DIR=/etc/yum.repos.d/
LOG_FILE=abiquo-kvm-install.log
AIM_CONF=/etc/abiquo-aim.ini
LIBVIRT_GUEST_CONF=/etc/sysconfig/libvirt-guests
SELINUX_CONF=/etc/sysconfig/selinux

# Change this URL if you want to use a local repository:
MIRROR_URL=http://mirror.abiquo.com/abiquo/el6/

function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}


if [ `whoami` != 'root' ]; then
    echo "This script needs to be run as root."
    exit 1
fi

echo -n "Checking distribution... "
if [ -f "/etc/redhat-release" ]; then
	head -n1 "/etc/redhat-release"
    else
	echo "Unsupported distribution found." 
        exit 1
fi

read -p "Installing Abiquo KVM, continue (y/n)? " ans

if [[ "${ans}" == 'y'  ||  "${ans}" == 'yes' ]]; then

	echo -n "Installing Abiquo release... "
	rpm -Uvh ${MIRROR_URL}abiquo-latest-release.noarch.rpm  >> $LOG_FILE 2>&1 
	if [ $? == 0 ]; then
		echo "Done."
	else
		echo "Failed!"
		exit 1
	fi

	echo -n "Checking signature... "
	rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-Abiquo >> $LOG_FILE 2>&1
	rpm -K ${MIRROR_URL}abiquo-latest-release.noarch.rpm >> $LOG_FILE 2>&1
	if [ $? == 0 ]; then
		echo "Done."
	else
		echo "Failed!"
		exit 1
	fi

	echo -n "Installing abiquo cloud node and KVM packages... "
	yum clean all -y >> $LOG_FILE 2>&1
	yum install abiquo-cloud-node qemu-kvm -y >> $LOG_FILE 2>&1
	if [ $? == 0 ]; then
		echo "Done."
	else
		echo "Failed!"
		exit 1
	fi

	echo -n "Installing extra packages... "
	yum install sos tcpdump abiquo-sosreport-plugins \
                    wget -y >> $LOG_FILE 2>&1
	if [ $? == 0 ]; then
		echo "Done."
	else
		echo "Warning: Extra packages not installed."
	fi

        # Post install steps
        read -p "Please, enter Remote Services IP: " ans
	if valid_ip $ans; then
	    sed -i "s,xen+unix:///,qemu+unix:///system," $AIM_CONF >>     $LOG_FILE 2>&1
            sed -i "s,127.0.0.1,$ans," $AIM_CONF >> 	$LOG_FILE 2>&1
	else
	    echo "This is not a valid IP. Please edit /etc/abiquo-aim.ini manually."
	fi
	
        # Post install steps
        read -p "Please, enter NFS repository IP: " ans
	if valid_ip $ans; then
	    read -p "Please enter NFS remote location [/opt/vm_repository]: " ans2
		if [[ "$ans2" == "" ]]; then
		    ans2="/opt/vm_repository"
		fi
	    echo "$ans:$ans2 /opt/vm_repository nfs    defaults        0 0" >> /etc/fstab
	else
	    echo "This is not a valid IP. Please edit /etc/fstab manually."
	fi

	# Guest suspend disabled by default
	sed -i "s,#ON_SHUTDOWN=suspend,ON_SHUTDOWN=shutdown," $LIBVIRT_GUEST_CONF >>     $LOG_FILE 2>&1
	
	# Selinux disabled by default
	sed -i "s,SELINUX=enforcing,SELINUX=disabled," $SELINUX_CONF >>     $LOG_FILE 2>&1

	echo -n "Configuring services ... "

	chkconfig iptables off >> $LOG_FILE 2>&1
	chkconfig selinux off >> $LOG_FILE 2>&1
	chkconfig abiquo-aim on >> $LOG_FILE 2>&1
	chkconfig rpcbind on >> $LOG_FILE 2>&1
	service iptables stop >> $LOG_FILE 2>&1
	service abiquo-aim start >> $LOG_FILE 2>&1

	if [ `getenforce` == 'Enabled' ]; then
	    echo "SElinux is enabled, please reboot."
	fi

	echo "Done."
fi

exit 0
