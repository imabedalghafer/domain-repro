#!/bin/bash

#This script is used to create a domain server with one linux client that is joined to that domain 
#We are following the below document as a reference for domain joining:
#https://docs.microsoft.com/en-us/azure/active-directory-domain-services/join-rhel-linux-vm

rgname='domain-repro-rg'
location='eastus'
winsize='Standard_d2s_v3'
linsize='Standard_b1ms'

echo 'Welcome to the repro script ^_^'
cat << EOF
You can select both the image name for windows and the image name for Linux

For Windows when asked you can enter any of the below options:
------------
    - 2k16 --> for windows server 2016
    - 2k19 --> for windows server 2019

For Linux machines when asked you can enter any of the below names:
------------
    - rhel6 --> for RHEL 6 RAW linux machine
    - rhel7 --> for RHEL 7 RAW linux machine
    - rhel8 --> for RHEL 8 RAW linux machine
    - sles12 --> for SLES 12 SP5 machine
    - sles15 --> for SLES 15 SP3 machine
    - ubuntu18 --> for Ubuntu 18 LTS
    - ubuntu20 --> for Ubuntu 20 LTS 
    - oracle6 --> For Oracle 6.10 machine
    - oracle7 --> for Oracle 7.9 machine
    - oracle8 --> for Oracle 8.4 LVM machine
    - centos6 --> For centos 6.10 machine
    - centos7 --> for Centos 7.9 machine
    - centos8 --> for Centos 8.4 machine
    - you can also provide the URN for the Linux image to use if non of the above images matching your scenario

EOF
read -p 'Please enter the windows version to create as your domain server: ' winversion
winvmname=domainvm$winversion
case $winversion in
    '2k19')
        winimage='MicrosoftWindowsServer:WindowsServer:2019-Datacenter:latest'
        echo 'Windows server 2019 was selected'
        ;;
    '2k16')
        winimage='MicrosoftWindowsServer:WindowsServer:2016-Datacenter:latest'
        echo 'Windows server 2016 was selected'
        ;;
    *)
        echo 'Please enter the proper image name for windows server, exiting...'
        exit 1
        ;;
esac

read -p 'Please enter the username used for Windows VM: ' winusername
read -s -p 'Please enter the password used for Windows VM: ' winpassword
echo ''

read -p 'Please enter the distro name that you want to use like: ' distro

case $distro in
    rhel6)
        linuximage='RedHat:RHEL:6.10:latest'
        echo "Downloading the domain join script for this distro"
	function sssd {
        wget -O rhel-domain-join.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/rhel-domain-join.sh
        filename='rhel-domain-join.sh'
	}
	function winbind {
	echo "winbind function available, downloading winbind script"
	wget -O redhat.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/redhat.sh
        filename='redhat.sh'
	}
        ;;
    rhel7)
        linuximage='RedHat:rhel-raw:7-raw:latest'
        echo "Downloading the domain join script for this distro"
	function sssd {
        wget -O rhel-domain-join.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/rhel-domain-join.sh
        filename='rhel-domain-join.sh'
        }
        function winbind {
        echo "winbind function available, downloading winbind script"
        wget -O redhat.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/redhat.sh
        filename='redhat.sh'
        }
        ;;
    rhel8)
        linuximage='RedHat:rhel-raw:8-raw:latest'
        echo "Downloading the domain join script for this distro"
	function sssd {
        wget -O rhel-domain-join.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/rhel-domain-join.sh
        filename='rhel-domain-join.sh'
        }
        function winbind {
        echo "winbind function available, downloading winbind script"
        wget -O redhat.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/redhat.sh
	    filename='redhat.sh'
	}
        ;;
    ubuntu18)
        linuximage='Canonical:UbuntuServer:18.04-LTS:latest'
        echo "Downloading the domain join script for this distro"
	function sssd {
        wget -O ubuntu-domain-join.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/ubuntu-domain-join.sh
        filename='ubuntu-domain-join.sh'
	}
	function winbind {
        echo "winbind function available, downloading winbind script"
	    wget -O ubuntu.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/ubuntu.sh
	    filename='ubuntu.sh'
	}
        ;;
    ubuntu20)
        linuximage='Canonical:0001-com-ubuntu-server-focal:20_04-lts:latest'
        echo "Downloading the domain join script for this distro"
        function sssd {
        wget -O ubuntu-domain-join.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/ubuntu-domain-join.sh
        filename='ubuntu-domain-join.sh'
        }
        function winbind {
        echo "winbind function available, downloading winbind script"
        wget -O ubuntu.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/ubuntu.sh
        filename='ubuntu.sh'
        }
	;;
    sles12)
        linuximage='SUSE:sles-12-sp5:gen1:latest'
        function sssd {
	wget -O sles-domain-join.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/sles-domain-join.sh
        filename='sles-domain-join.sh'
        }
        function winbind {
        echo "winbind function available, downloading winbind script"
        wget -O sles.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/sles.sh
        filename='sles.sh'
        }
        ;;    
    sles15)
        linuximage='SUSE:sles-15-sp4:gen1:latest'
	function sssd {
        wget -O sles-domain-join.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/sles-domain-join.sh
	    filename='sles-domain-join.sh'
        }
        function winbind {
        echo "winbind function available, downloading winbind script"
        wget -O sles.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/sles.sh
        filename='sles.sh'
	}
        ;;
    oracle6)
        linuximage='Oracle:Oracle-Linux:6.10:latest'
        echo "Downloading the domain join script for this distro"
        wget -O oracle-domain-join.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/oracle-domain-join.sh
        filename='oracle-domain-join.sh'
        ;;
    oracle7)
        linuximage='Oracle:Oracle-Linux:ol79:latest'
        echo "Downloading the domain join script for this distro"
	function sssd {
        wget -O oracle-domain-join.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/oracle-domain-join.sh
        filename='oracle-domain-join.sh'
	}
	function winbind {
        echo "winbind function available, downloading winbind script"
        wget -O oracle.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/oracle.sh
        filename='oracle.sh'
	}
        ;;
    oracle8)
        linuximage='Oracle:Oracle-Linux:ol84-lvm:latest'
        echo "Downloading the domain join script for this distro"
    function sssd {
        wget -O oracle-domain-join.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/oracle-domain-join.sh
        filename='oracle-domain-join.sh'
        }
    function winbind {
        echo "winbind function available, downloading winbind script"
        wget -O oracle.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/oracle.sh
        filename='oracle.sh'
        }
	;;
    centos6)
        linuximage='OpenLogic:CentOS:6.10:latest'
    function sssd {
	    echo "Downloading the domain join script for this distro"
        wget -O centos-domain-join.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/centos-domain-join.sh
        filename='centos-domain-join.sh'
	}
	function winbind {
	    wget -O centos.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/centos.sh
	    filename='centos.sh'
	}
        ;;
    centos7)
        linuximage='OpenLogic:CentOS:7_9:latest'
	function sssd {
        echo "Downloading the domain join script for this distro"
        wget -O centos-domain-join.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/centos-domain-join.sh
        filename='centos-domain-join.sh'
    }
    function winbind {
        wget -O centos.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/centos.sh
        filename='centos.sh'
        }
        ;;
    centos8)
        linuximage='OpenLogic:CentOS:8_4:latest'
	function sssd {
        echo "Downloading the domain join script for this distro"
        wget -O centos-domain-join.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/centos-domain-join.sh
        filename='centos-domain-join.sh'
        }
        function winbind {
        wget -O centos.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/centos.sh
        filename='centos.sh'
        }
        ;;
    *)
        #the image urn has 3 : , we will check if the urn entered has this number
        count=`echo $distro | grep -o ':' | wc -l`
        version=`echo $distro | cut -d : -f4`
        #echo $version
        if [ $count == 3 ] && [ ! -z $version ]
        then
            linuximage=$distro
            publisher=`echo $distro | cut -d : -f1`
            offer=`echo $distro | cut -d : -f2`
            distro=$publisher
	    function sssd {
            echo "You selected an image from publisher $publisher with offer $offer"
            echo "The VM name that will be created will have the name of $distro-client"
            echo "Downloading the OS detector script "
            wget -O os-detector.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/os-detector.sh
            filename='os-detector.sh'
    	    }
    	    function winbind {
            wget -O win_os_detector.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/win_os_detector.sh
	    filename='win_os_detector.sh'
    	    }
        else
            echo 'Please check the image urn and try again , exsiting..'
            exit 2
        fi
        ;;
esac
linuxvmname=$distro-client
#echo $linuxvmanem ; echo $winvmname ; echo $winversion ; echo $linuximage
read -p 'Please enter the username used for Linux VM: ' linusername
read -s -p 'Please enter the password used for Linux VM: ' linpassword
echo ''

echo "Choose the AD integration method:"
echo "1. SSSD"
echo "2. Winbind"
read -p "Enter the number of your choice: " choice

# Execute the corresponding function based on the user's choice
case $choice in
    1) sssd ;;
    2) winbind ;;
    *) echo "Invalid choice. Please choose a valid option (1-2)." ;;
esac

function check_resource_group_exists {
    az group show --name "$1" &> /dev/null
}

if check_resource_group_exists "$rgname"; then
    echo "Resource group '$rgname' already exists. Skipping AD integration..."
else
    echo "Creating the resource group of name $rgname .."
    az group create --name $rgname --location $location >> /dev/null

    if [ $winversion == '2k16' ]
    then
        if [ $distro == 'rhel8' ] || [ $distro == 'centos8' ]
        then
            echo "You have selected windows server 2016 as a domain server with $distro"
            echo "When trying to run kinit, the command would fail with error: kinit: KDC has no support for encryption type while getting initial credentials"
            echo "This issue is mentioned in https://access.redhat.com/solutions/5728591"
            echo "Thus we would enable the 'AD-SUPPORT' crypto policy on top of the 'DEFAULT' "
            echo "The join domain script will use this command to perform this action : update-crypto-policies --set DEFAULT:AD-SUPPORT"
            echo "This is to update you about this out of doc command and this could be also with customer side."
            echo "For more details check on the RHEL solution above ..."
         fi
     fi

     echo "Creating the Windows machine $winvmname"
     az vm create -g $rgname -n $winvmname --admin-username $winusername --admin-password $winpassword --image $winimage --nsg-rule RDP --size $winsize >> /dev/null

     echo "Preparing the domain join script, it will be created on same directory as this script"
     echo "NOTE: the password for Directory Services Restore Mode will be similar to the password used for the windows machine"

     if [ -f domain_install.ps1 ]
     then
         rm ./domain_install.ps1
         echo "Install-WindowsFeature AD-Domain-Services -IncludeManagementTools" >> domain_install.ps1
         echo "\$pass = ConvertTo-SecureString -String $winpassword -AsPlainText -Force " >> domain_install.ps1
         echo "Install-ADDSForest -DomainName \"lab.local\" -DomainNetBiosName \"LAB\" -InstallDns:\$true -NoRebootOnCompletion:\$true -SafeModeAdministratorPassword \$pass -Force " >> domain_install.ps1
         echo 'shutdown -r' >> domain_install.ps1
    else
         echo "Install-WindowsFeature AD-Domain-Services -IncludeManagementTools" >> domain_install.ps1
         echo "\$pass = ConvertTo-SecureString -String $winpassword -AsPlainText -Force " >> domain_install.ps1
         echo "Install-ADDSForest -DomainName \"lab.local\" -DomainNetBiosName \"LAB\" -InstallDns:\$true -NoRebootOnCompletion:\$true -SafeModeAdministratorPassword \$pass -Force " >> domain_install.ps1
         echo 'shutdown -r' >> domain_install.ps1
    fi

    echo 'Promoting the domain server, this operation might take some time ..'
    az vm run-command invoke  --command-id RunPowerShellScript --name $winvmname -g $rgname --scripts @domain_install.ps1 >> /dev/null

    echo 'Updating the VNET to have the domain server IP as its DNS server'
    win_private_ip=`az vm list-ip-addresses -g $rgname -n $winvmname --query [].virtualMachine.network.privateIpAddresses -o tsv`
    vnet_name=`az network vnet list -g $rgname --query [].name -o tsv`
    az network vnet update -g $rgname -n $vnet_name --dns-servers $win_private_ip 168.63.129.16 >> /dev/null

    echo 'Waiting for the windows machine for 3 min'
    sleep 180
fi
echo "Creating the Linux machine $linuxvmname"
az vm create -g $rgname -n $linuxvmname --admin-username $linusername --admin-password $linpassword --image $linuximage --nsg-rule SSH --size $linsize >> /dev/null

echo "rewrite the windows password to add single quotas before sending it in the run command.."
tempwinpassword=\'$winpassword\'

echo 'Executing the default join domain script..'
az vm run-command invoke -g $rgname -n $linuxvmname --command-id RunShellScript --scripts @$filename --parameters LAB.LOCAL $winusername $tempwinpassword >> script_result.log

if [ -f $filename ]
then
    echo "Deleting the file $filename"
fi

echo "We are done ^_^ , happy troubleshooting .."

