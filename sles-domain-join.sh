#!/bin/bash

#The steps are based on the following document:
#https://docs.microsoft.com/en-us/azure/active-directory-domain-services/join-rhel-linux-vm

logdir='/var/log/azure/domain-join'
mkdir -p $logdir
logfile='/var/log/azure/domain-join/script.log'
touch $logfile
domain_name=$1
domain_admin_username=$2
domain_admin_password=$3
no_caps_domain_name=${domain_name,,}

function sles15_join_domain()
{
    hostname=`hostname`
    #Take a backup of hosts file
    cp /etc/hosts /etc/hosts-`date +"%d-%m-%y"`
    echo "127.0.0.1    $hostname    $hostname.lab.local" >> /etc/hosts
    echo "Updating the DNS server search" >> $logfile
    cp /etc/sysconfig/network/config /etc/sysconfig/network/config-`date +"%d-%m-%y"`
    sed -i 's/NETCONFIG_DNS_STATIC_SEARCHLIST=""/NETCONFIG_DNS_STATIC_SEARCHLIST="lab.local"/g' /etc/sysconfig/network/config
    systemctl restart wicked.service
    echo "Installing the required packages" >> $logfile
    zypper --non-interactive install realmd sssd sssd-tools adcli krb5-client samba-client openldap2-client sssd-ad  >> $logfile
    realm discover $domain_name >> $logfile
    verify=`realm discover $domain_name | grep 'realm-name:' | cut -d : -f2 |  tr -d [:space:]`
    nocaps_domain_name=`realm discover $domain_name | grep 'domain-name:' | cut -d : -f2 | tr -d [:space:]`
    if [ $verify == $domain_name ] && [ $? == 0 ]
    then
        echo "Domain $verify was discovered" >> $logfile
        echo "Updating the krb5.conf to fix the issue in : https://www.suse.com/support/kb/doc/?id=000018928" >> $logfile
        echo "[libdefaults]" >> /etc/krb5.conf.d/domain_join.conf
        echo "default_ccache_name = FILE:/tmp/krb5cc_%{uid}" >> /etc/krb5.conf.d/domain_join.conf
        echo "Trying to check for the certificate for the admin user using kinit" >> $logfile
        echo "$domain_admin_password" | kinit $domain_admin_username@$domain_name >> $logfile
        if [ $? == 0 ]
        then
            echo "The credentials cache has been updated successfully" >> $logfile
            echo "Waiting for 1 min before trying to join the machine to the domain" >> $logfile
            sleep 60
            echo "Trying to join domain now .." >> $logfile
            echo "$domain_admin_password" | realm join --verbose $domain_name -U "$domain_admin_username@$domain_name" >> $logfile
            if [ $? == 0 ]
            then 
                echo "Updating the sudo configuration to add the user to the sudo users" >> $logfile
                echo "$domain_admin_username@$nocaps_domain_name   ALL=(ALL)    NOPASSWD:ALL" >> /etc/sudoers.d/domain-join
                echo "Updating the config file for not to use the FQDN in user login" >> $logfile
                cp /etc/sssd/sssd.conf /etc/sssd/sssd.conf-`date +"%d-%m-%y"`
                sed -i '/^use_fully_qualified_names/ s/True/False/g ' sssd.conf
                systemctl restart sssd
                systemctl enable sssd
                echo "Copying the krb5.conf and sssd.conf to the /root directory as a reference" >> $logfile
                cp /etc/krb5.conf /root/
                cp /etc/sssd/sssd.conf /root/
                echo "We are successfully joined to the domain ^_^" >> $logfile
                echo "Enjoy your day :) " >> $logfile
                #echoing the messages for the stdout of custom script
                echo "We are successfully joined to the domain ^_^"
            else
                echo "Failed to join the domain , please check the logs"
                exit 3
            fi
        else
        echo "Failed to refresh the credentials cache, please check the logs"
        exit 2
        fi
    else
    echo "Failed to discover the domain, check the network setup and try to run the script again"
    exit 1
    fi
}



echo "#######################" >> $logfile
date >> $logfile
echo "Trying to determine the SLES version the machine using" >> $logfile
echo "Checking if the os-release file is available, else check on redhat-release file" >> $logfile
if [ -f /etc/os-release ]
then
    source /etc/os-release
    major_version=`echo $VERSION_ID | cut -d . -f1`
    case $major_version in
        15)
            echo "The machine running SLES 15 , executing function for that version .." >> $logfile
            sles15_join_domain
            ;;
        12)
            echo "The machine running RHEL 7 , executing function for that version .." >> $logfile
            sles15_join_domain
            ;;  
        *)
            echo "Not a RHEL machine .." >> $logfile
            exit 4
            ;;
    esac
fi