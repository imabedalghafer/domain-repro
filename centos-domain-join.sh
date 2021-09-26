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

function centos7_join_domain()
{
    hostname=`hostname`
    #Take a backup of hosts file
    cp /etc/hosts /etc/hosts-`date +"%d-%m-%y"`
    echo "127.0.0.1    $hostname    $hostname.lab.local" >> /etc/hosts
    echo "Installing the required packages" >> $logfile
    yum install -y realmd sssd krb5-workstation krb5-libs oddjob oddjob-mkhomedir samba-common-tools >> $logfile
    realm discover $domain_name >> $logfile
    verify=`realm discover $domain_name | grep 'realm-name:' | cut -d : -f2 |  tr -d [:space:]`
    nocaps_domain_name=`realm discover $domain_name | grep 'domain-name:' | cut -d : -f2 | tr -d [:space:]`
    if [ $verify == $domain_name ] && [ $? == 0 ]
    then
        echo "Domain $verify was discovered" >> $logfile
        echo "Trying to check for the certificate for the admin user using kinit" >> $logfile
        echo "$domain_admin_password" | kinit $domain_admin_username@$domain_name >> $logfile
        if [ $? == 0 ]
        then
            echo "The credentials cache has been updated successfully" >> $logfile
            echo "Trying to join domain now .." >> $logfile
            echo "$domain_admin_password" | realm join --verbose $domain_name -U "$domain_admin_username@$domain_name" >> $logfile
            if [ $? == 0 ]
            then
                echo "Updating the sudo configuration to add the user to the sudo users" >> $logfile
                echo "$domain_admin_username@$nocaps_domain_name   ALL=(ALL)    NOPASSWD:ALL" >> /etc/sudoers.d/domain-join
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

function centos6_join_domain()
{
    hostname=`hostname`
    #Take a backup of hosts file
    cp /etc/hosts /etc/hosts-`date +"%d-%m-%y"`
    echo "127.0.0.1    $hostname    $hostname.lab.local" >> /etc/hosts
    echo "Setting the locale values" >> $logfile
    export LC_CTYPE=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
    echo "Installing the required packages" >> $logfile
    echo "Updating infra package to avoid SSL errors" >> $logfile
    yum update -y --disablerepo='*' --enablerepo='*microsoft*' >> $logfile
    yum clean all >> $logfile
    yum repolist >> $logfile
    yum install -y adcli sssd authconfig krb5-workstation >> $logfile
    nocaps_domain_name=`adcli info LAB.LOCAL | grep domain-name  | cut -d = -f2 | tr -d [:space:]`
    caps_domain_name=${nocaps_domain_name^^}
    if [ $caps_domain_name == $domain_name ]
    then
        echo "Domain $caps_domain_name was discovered" >> $logfile
        echo "Creating the krb5.conf file" >> $logfile
        echo "getting the user credentials cache using kinit" >> $logfile
        echo $domain_admin_password | kinit $domain_admin_username@$domain_name >> $logfile
        cp /etc/krb5.conf /etc/krb5.conf-`date +"%d-%m-%y"`
        #added without a space to match the EOF use in bash , reference bash(1)
        cat > /etc/krb5.conf <<EOF
[logging]
 default = FILE:/var/log/krb5libs.log
 kdc = FILE:/var/log/krb5kdc.log
 admin_server = FILE:/var/log/kadmind.log

[libdefaults]
 default_realm = $domain_name
 dns_lookup_realm = true
 dns_lookup_kdc = true
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true
 rdns = false

[realms]
 $domain_name = {
 kdc = $domain_name
 admin_server = $domain_name
 }

[domain_realm]
 .$domain_name = $domain_name
 $domain_name = $domain_name
EOF
        echo "Creating the sssd.conf file" >> $logfile
        cat > /etc/sssd/sssd.conf << EOF
[sssd]
 services = nss, pam, ssh, autofs
 config_file_version = 2
 domains = $domain_name

[domain/$domain_name]
 id_provider = ad

EOF
        chmod 600 /etc/sssd/sssd.conf
        chown root:root /etc/sssd/sssd.conf
        echo "Updaing the PAM to use the SSSD " >> $logfile
        authconfig --enablesssd --enablesssdauth --update
        echo "Joining the domain to create the krb5.keytab file" >> $logfile
        echo -n $domain_admin_password | adcli join $domain_name -U $domain_admin_username --stdin-password >> $logfile
        if [ $? == 0 ]
        then
            echo "Restarting the service to make sure everything is ready" >> $logfile
            service sssd start >> $logfile
            if [ $? == 0 ]
            then
                chkconfig sssd on >> $logfile
                echo "Updating the sudo configuration to add the user to the sudo users" >> $logfile
                echo "$domain_admin_username@$nocaps_domain_name   ALL=(ALL)    NOPASSWD:ALL" >> /etc/sudoers.d/domain-join
                echo "Trust me , that was a hard job !! " >> $logfile
                echo "We are done and now you can use the joined domain machine " >> $logfile
                echo "Enjoy your day and happy repro ^_^" >> $logfile
            else
                echo "Failed to start the service, please check the logs" >> $logfile
                exit 5
            fi
        else
            echo "Failed to join the domain, please check the logs" >> $logfile
            exit 2
        fi
    else
        echo "There is an issue , please check the logs" >> $logfile
    fi
}

echo "#######################" >> $logfile
date >> $logfile
echo "Trying to determine the Centos version the machine using" >> $logfile
echo "Checking if the os-release file is available, else check on centos-release file" >> $logfile
if [ -f /etc/os-release ]
then
    source /etc/os-release
    major_version=$VERSION_ID
    case $major_version in
        8)
            echo "The machine running Centos 8 , executing function for that version .." >> $logfile
            centos7_join_domain
            ;;
        7)
            echo "The machine running Centos 7 , executing function for that version .." >> $logfile
            centos7_join_domain
            ;;
        6)
            echo "The machine running Centos 6 , executing function for that version .." >> $logfile
            centos6_join_domain
            ;;
        *)
            echo "Not a Centos machine .." >> $logfile
            exit 4
            ;;
    esac
else
    os_version=`cat /etc/centos-release | grep -o 6`
    if [ $os_version == 6 ]
    then
        centos6_join_domain
    else
        echo "Not a Centos machine .." >> $logfile
        exit 4
    fi
fi
