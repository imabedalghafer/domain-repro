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

function sles12_join_domain()
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
    zypper --non-interactive install krb5-client samba-client openldap2-client sssd sssd-tools sssd-ad adcli 
    echo "Taking a backup of krb5.conf file" >> $logfile
    cp /etc/krb5.conf /etc/krb5.conf-`date +"%d-%m-%y"`
    cat > /etc/krb5.conf << EOF
[libdefaults]
    default_realm = $domain_name
    dns_canonicalize_hostname = false
    rdns = false
    clockskew = 500
    dns_lookup_realm = true
    dns_lookup_kdc = true
    forwardable = true
    default_ccache_name = FILE:/tmp/krb5cc_%{uid}
[realms]
    $domain_name = {
        admin_server = $no_caps_domain_name
    }
[logging]
    kdc = FILE:/var/log/krb5/krb5kdc.log
    admin_server = FILE:/var/log/krb5/kadmind.log
    default = SYSLOG:NOTICE:DAEMON
[domain_realm]
    .$no_caps_domain_name = $domain_name
    $no_caps_domain_name = $domain_name
EOF
    echo "Taking a backup for smb.conf file " >> $logfile
    smb_backup_file=/etc/samba/smb.conf-`date +"%d-%m-%y"`
    cp  /etc/samba/smb.conf   $smb_backup_file
    echo "Updating the smb.conf file " >> $logfile
    cat >  /etc/samba/smb.conf << EOF
[global]
        workgroup = LAB
        kerberos method = secrets and keytab
        realm = $domain_name
        security = ADS
        template homedir = /home/%D/%U
        template shell = /bin/bash
        idmap uid = 10000-20000
        idmap gid = 10000-20000
EOF
    sed -n '/homes/,$p' $smb_backup_file >> /etc/samba/smb.conf
    echo "Updating nsswitch file " >> $logfile
    cp /etc/nsswitch.conf /etc/nsswitch.conf-`date +"%d-%m-%y"`
    sed -i '/^passwd:/ s/$/ sss/ ' /etc/nsswitch.conf
    sed -i '/^group:/ s/$/ sss/ ' /etc/nsswitch.conf

    echo "Taking a backup of sssd.conf file " >> $logfile
    cp /etc/sssd/sssd.conf /etc/sssd/sssd.conf-`date +"%d-%m-%y"`
    echo "Updating the SSSD configuration " >> $logfile
    cat > /etc/sssd/sssd.conf << EOF
[sssd]
config_file_version = 2
services = nss,pam
domains = $no_caps_domain_name

[nss]
#filter_users = root
#filter_groups = root

[pam]

[domain/$no_caps_domain_name]
default_shell = /bin/bash
krb5_store_password_if_offline = True
cache_credentials = True
krb5_realm = $domain_name
realmd_tags = manages-system joined-with-adcli
id_provider = ad
ad_domain = $no_caps_domain_name
use_fully_qualified_names = True
ldap_id_mapping = True
access_provider = ad
auth_provider = ad
enumerate = false
override_homedir = /home/%d/%u
ldap_referrals = false
ldap_schema = ad
EOF
    echo "Trying to check for the certificate for the admin user using kinit" >> $logfile
    echo "$domain_admin_password" | kinit $domain_admin_username@$domain_name >> $logfile
    if [ $? == 0 ]
    then
        echo "Trying to join the domain .." >> $logfile
        echo $domain_admin_password | net ads join $domain_name -U $domain_admin_username
        if [ $? == 0 ]
        then
            echo "Updating the sudo configuration to add the user to the sudo users" >> $logfile
            echo "$domain_admin_username@$nocaps_domain_name   ALL=(ALL)    NOPASSWD:ALL" >> /etc/sudoers.d/domain-join
            sssd config-check >> $logfile
            echo "Update the PAM configuration " >> $logfile
            pam-config -a --sss
            pam-config -a --mkhomedir
            echo "Starting the SSSD service " >> $logfile
            systemctl enable sssd
            systemctl start sssd
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
            echo "The machine running SLES 12 , executing function for that version .." >> $logfile
            sles12_join_domain
            ;;  
        *)
            echo "Not a SLES machine .." >> $logfile
            exit 4
            ;;
    esac
fi