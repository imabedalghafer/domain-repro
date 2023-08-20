#!/bin/bash

domain_name=$1
domain_admin_username=$2
domain_admin_password=$3

sudo echo 'append domain-search "lab.local"' >> /etc/dhcp/dhclient.conf
sudo sed -i '/^\[main\]/a dhcp = dhclient' /etc/NetworkManager/NetworkManager.conf

sudo systemctl restart NetworkManager

sudo update-crypto-policies --set DEFAULT:AD-SUPPORT

sudo yum install --disablerepo='*' --enablerepo='*microsoft*' 'rhui-azure-*' -y 

sudo yum install realmd oddjob-mkhomedir oddjob samba-winbind-clients samba-winbind samba-common-tools samba-winbind-krb5-locator -y

sudo  yum install samba -y

sudo mv /etc/samba/smb.conf /etc/samba/smb.conf.bak

sudo echo "$domain_admin_password" |realm join --membership-software=samba --client-software=winbind lab.local -U "$domain_admin_username"


# Define the lines to be added to the krb5.conf file
lines_to_add="[plugins]
    localauth = {
        module = winbind:/usr/lib64/samba/krb5/winbind_krb5_localauth.so
        enable_only = winbind
    }"

# File path to the krb5.conf file
krb5_conf="/etc/krb5.conf"

echo "$lines_to_add" | sudo tee -a "$krb5_conf"

systemctl enable --now smb

yum install krb5-workstation -y 

sudo echo "$domain_admin_password" | kinit $domain_admin_username

hostname=`hostname`

hostnamectl set-hostname $hostname.lab.local

ip=`hostname -I | awk '{print $1}'`

echo "$ip        $hostname.lab.local $hostname" >> /etc/hosts

echo "%lab.local\\\\$domain_admin_username ALL=(ALL)    NOPASSWD:ALL" >> /etc/sudoers

net ads join -k
