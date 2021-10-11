#!/bin/bash
logdir='/var/log/azure/domain-join'
mkdir -p $logdir
logfile='/var/log/azure/domain-join/script.log'
touch $logfile
domain_name=$1
domain_admin_username=$2
domain_admin_password=$3
lc_domain_name=$(echo $domain_name | tr '[:upper:]' '[:lower:]')
resolver=$(systemd-resolve --status |sed -n 's/.*Servers: //p')
macaddress=$(cat /sys/class/net/eth0/address)


function ubuntu18_join_domain()
{
	hostname=`hostname`
	echo $hostname
	cp /etc/hosts /etc/hosts-`date +"%d-%m-%y"`
	echo "127.0.0.1    $hostname.lab.local"     $hostname >> /etc/hosts
	#Configure DNS
	cat > /etc/netplan/51-domain-join.yaml <<EOF 
network:
    ethernets:
        eth0:
            dhcp4: true
            dhcp4-overrides:
                route-metric: 100
            dhcp6: false
            match:
                driver: hv_netvsc
                macaddress: $macaddress
            set-name: eth0
            nameservers:
                addresses:
                  - $resolver
                  - 168.63.129.16
                search:
                  - lab.local
    version: 2
EOF
netplan apply
	#Install required packages
	echo "Installing the required packages" >> $logfile
	apt-get update >> $logfile
	DEBIAN_FRONTEND=noninteractive apt-get -y install krb5-user samba sssd sssd-tools libnss-sss libpam-sss ntp ntpdate realmd adcli packagekit >> $logfile
	#Configure NTP
	cp /etc/ntp.conf /etc/ntp.conf_bak-`date +"%d-%m-%y"`
	echo "server $lc_domain_name" >> /etc/ntp.conf
	systemctl stop ntp
	ntpdate $lc_domain_name >> $logfile
	systemctl start ntp
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
			#Disable rdns
			cp /etc/krb5.conf /etc/krb5.conf_bak-`date +"%d-%m-%y"`
			sed -i '2 i rdns=no' /etc/krb5.conf
            
			echo "Waiting for 1 min before trying to join the machine to the domain" >> $logfile
            sleep 60
			echo "Trying to join domain now .." >> $logfile
			echo "$domain_admin_password" | realm join --verbose $domain_name -U "$domain_admin_username@$domain_name" >> $logfile
			if [ $? == 0 ]
			then
				#Update sssd configuration
				echo "Updating sssd configuration"
				cp /etc/sssd/sssd.conf /etc/sssd/sssd.conf_bak-`date +"%d-%m-%y"`
				sed -i 's/^use_fully_qualified_names/#&/' /etc/sssd/sssd.conf
				systemctl restart sssd
				#Update sshd configuration
				cp /etc/ssh/sshd_config /etc/ssh/sshd_config_bak-`date +"%d-%m-%y"`
				sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
				sudo systemctl restart ssh									                
				#Enable home directory creation
				cp /etc/pam.d/common-session /etc/pam.d/common-session_bak-`date +"%d-%m-%y"`
				sed -i '/pam_sss.so*/a session required pam_mkhomedir.so skel=/etc/skel/ umask=0077' /etc/pam.d/common-session
				echo "Updating the sudo configuration to add the user to the sudo users" >> $logfile
				echo "$domain_admin_username@$nocaps_domain_name   ALL=(ALL)    NOPASSWD:ALL" >> /etc/sudoers.d/domain-join
				#added because when not using the FQDN the OS not able to detect that this is a domain user.
                echo "$domain_admin_username   ALL=(ALL)    NOPASSWD:ALL" >> /etc/sudoers.d/domain-join
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


function ubuntu20_join_domain()
{
	hostname=`hostname`
	echo $hostname
	cp /etc/hosts /etc/hosts-`date +"%d-%m-%y"`
	echo "127.0.0.1    $hostname.lab.local"     $hostname >> /etc/hosts	
		#Configure DNS
	cat > /etc/netplan/51-domain-join.yaml <<EOF 
network:
    ethernets:
        eth0:
            dhcp4: true
            dhcp4-overrides:
                route-metric: 100
            dhcp6: false
            match:
                driver: hv_netvsc
                macaddress: $macaddress
            set-name: eth0
            nameservers:
                addresses:
                  - $resolver
                  - 168.63.129.16
                search:
                  - lab.local
    version: 2
EOF
netplan apply
	#Install required packages
	echo "Installing the required packages" >> $logfile
	apt-get update >> $logfile
	DEBIAN_FRONTEND=noninteractive apt -y install krb5-user samba-common-bin sssd sssd-tools libnss-sss libpam-sss realmd adcli oddjob oddjob-mkhomedir packagekit >> $logfile
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
			#Disable rdns
			cp /etc/krb5.conf /etc/krb5.conf_bak-`date +"%d-%m-%y"`
			sed -i '2 i rdns=no' /etc/krb5.conf
            
			echo "Waiting for 1 min before trying to join the machine to the domain" >> $logfile
            sleep 60
			echo "Trying to join domain now .." >> $logfile
			echo "$domain_admin_password" | realm join --verbose $domain_name -U "$domain_admin_username@$domain_name" >> $logfile
			if [ $? == 0 ]
			then
				#Update sssd configuration
				echo "Updating sssd configuration"
				cp /etc/sssd/sssd.conf /etc/sssd/sssd.conf_bak-`date +"%d-%m-%y"`
				sed -i 's/^use_fully_qualified_names/#&/' /etc/sssd/sssd.conf
				systemctl restart sssd
				#Update sshd configuration
				cp /etc/ssh/sshd_config /etc/ssh/sshd_config_bak-`date +"%d-%m-%y"`
				sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
				sudo systemctl restart ssh
				#Configure home directory creation
				cp /etc/pam.d/common-session /etc/pam.d/common-session_bak-`date +"%d-%m-%y"`
				sed -i '/pam_sss.so*/a session required pam_mkhomedir.so skel=/etc/skel/ umask=0077' /etc/pam.d/common-session
				echo "Updating the sudo configuration to add the user to the sudo users" >> $logfile
				echo "$domain_admin_username@$nocaps_domain_name   ALL=(ALL)    NOPASSWD:ALL" >> /etc/sudoers.d/domain-join
				#added because when not using the FQDN the OS not able to detect that this is a domain user.
                echo "$domain_admin_username   ALL=(ALL)    NOPASSWD:ALL" >> /etc/sudoers.d/domain-join
				echo "Copying the krb5.conf and sssd.conf to the /root directory as a reference" >> $logfile
				cp /etc/krb5.conf /root/
				cp /etc/sssd/sssd.conf /root/
				echo "We are successfully joined to the domain ^_^" >> $logfile
				echo "Enjoy your day :) " >> $logfile
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

function ubuntu16_join_domain()
{
    echo "Ubuntu 16.x is not yet implemented... Coming Soon." >> $logfile
    exit 4
}

echo "#######################" >> $logfile
date >> $logfile
echo "Trying to determine your Ubuntu release" >> $logfile
echo "Checking if the os-release file is available, else check on lsb-release file" >> $logfile
if [ -f /etc/os-release ]
then
    source /etc/os-release
    major_version=`echo $VERSION_ID | cut -d . -f1`
    case $major_version in
        20)
            echo "The machine is running Ubuntu 20.x, executing function for that version .." >> $logfile
            ubuntu20_join_domain
            ;;
        18)
            echo "The machine is running Ubuntu 18.x, executing function for that version .." >> $logfile
            ubuntu18_join_domain
            ;;  
        16)
            echo "The machine is running Ubuntu 16.x, This is not yet implemented .." >> $logfile
            ubuntu16_join_domain
            ;;
        *)
            echo "VM is not running Ubuntu .." >> $logfile
            exit 4
            ;;
    esac
fi