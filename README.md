# Domain-repro
This is script is used to create a working environment of windows domain and 1 linux client that would join that domain.

## Tasks automated by the script:
-	Create a Windows server (you can select with to be 2016 or 2019 )
-	Install and configure the domain controller with a domain name called “LAB.LOCAL”
-	Use the provided username and password as domain admin user
-	Create a Linux machine of a specific distro (it can be rhel, ubuntu …etc ) or you can provide the URN for the image you want to use
-	Download and run the domain join script of that specific distro
-	Copy the needed domain join configuration files to /root as a reference for working setup.

## Usage:
-	Download and run ***domain_build.sh***  script
-	You are presented with self-help options to guide you with the needed arguments
-	Once you provide the arguments , grab a cup of coffee/latte (we are not a fans of tea 😝 ) 
-	Come back in 10 min and you will have the environment ready.
-	***Bonus*** : look in /var/log/azure/domain-join/script.log , if you would like to see the details of the process or if you faced any issues.

## Tools needed to run the script:
-	WSL (windows subsystem for Linux) or any Linux system
-	Azure CLI installed on the machine and already logged in (during testing we spotted an issue azure cli 2.9.1 and the script might not work as intended with this version.)
-	OR you could use the cloud-shell to run the script from.

## Limitations:
-	The script use only SSSD for domain joining, we are planning to add winbind option to be used for domain joining in the next release

## Example of usage:

```
$ ./domain_build.sh
Welcome to the repro script ^_^
You can select both the image name for windows and the image name for Linux

for Windows when asked you can enter any of the below options:
------------
    - 2k16 --> for windows server 2016
    - 2k19 --> for windows server 2019

for Linux machines when asked you can enter any of the below names:
------------
    - rhel6 --> for RHEL 6 RAW linux machine
    - rhel7 --> for RHEL 7 RAW linux machine
    - rhel8 --> for RHEL 8 RAW linux machine
    - sles12 --> for SLES 12 SP5 machine
    - sles15 --> for SLES 15 SP3 machine
    - ubuntu18 --> for Ubuntu 18 LTS
    - ubuntu20 --> for Ubuntu 20 LTS
    - oracle7 --> for Oracle 7.9 machine
    - oracle8 --> for Oracle 8.4 LVM machine
    - centos7 --> for Centos 7.9 machine
    - centos8 --> for Centos 8.4 machine
    - you can also provide the URN for the Linux image to use if non of the above images matching your scenario

Please enter the windows version to create as your domain server:2k19
Windows server 2019 was selected
Please enter the username used for Windows VM: winadmin
Please enter the password used for Windows VM:
Please enter the distro name that you want to use like: ubuntu18
Downloading the domain join script for this distro
--2021-09-30 17:14:13--  https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/ubuntu-domain-join.sh
Resolving raw.githubusercontent.com (raw.githubusercontent.com)... 185.199.109.133, 185.199.111.133, 185.199.110.133, ...
Connecting to raw.githubusercontent.com (raw.githubusercontent.com)|185.199.109.133|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 8864 (8.7K) [text/plain]
Saving to: ‘ubuntu-domain-join.sh’

ubuntu-domain-join.sh                                100%[===================================================================================================================>]   8.66K  --.-KB/s    in 0.001s

2021-09-30 17:14:14 (15.5 MB/s) - ‘ubuntu-domain-join.sh’ saved [8864/8864]

Please enter the username used for Linux VM: linuxadmin
Please enter the password used for Linux VM:
```
