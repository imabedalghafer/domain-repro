#!/bin/bash

domain_name=$1
domain_admin_username=$2
domain_admin_password=$3

netplan apply

# Create the file and write the content
cat << EOF > /etc/netplan/99-dns.yaml
network:
  ethernets:
    eth0:
      nameservers:
        search: [ lab.local ]
EOF
netplan apply
systemd-resolve --status

echo "krb5-config krb5-config/default_realm string lab.local" > krb5-config.seed
sudo debconf-set-selections < krb5-config.seed
apt update && apt-get install -y samba krb5-config krb5-user winbind libpam-winbind libnss-winbind

cp -p /etc/krb5.conf /etc/krb5.conf_bkp

krb_content="[libdefaults]
      dns_lookup_realm = false
      ticket_lifetime = 24h
      renew_lifetime = 7d
      forwardable = true
      rdns = false
      default_realm = LAB.LOCAL
      default_ccache_name = KEYRING:persistent:%{uid}

[realms]
      LAB.LOCAL = {
            kdc = lab.local
            admin_server = lab.local
            default_domain = lab.local
            pkinit_anchors = FILE:/etc/pki/nssdb/certificate.pem
            pkinit_cert_match = <KU>digitalSignature
            pkinit_kdc_hostname = lab.local
      }

[domain_realm]
    .lab.local = LAB.LOCAL
    lab.local = LAB.LOCAL"

sudo echo "$krb_content" > /etc/krb5.conf

sudo cp /etc/samba/smb.conf /etc/samba/smb.conf_bkp

# samba configuration 
new_content="[global]
  kerberos method = secrets and keytab
  template homedir = /home/%U@%D
  workgroup = LAB
  template shell = /bin/bash
  security = ads
  realm = LAB.LOCAL
  idmap config LAB : range = 2000000-2999999
  idmap config LAB : backend = rid
  idmap config * : range = 10000-999999
  idmap config * : backend = tdb
  winbind use default domain = no
  winbind refresh tickets = yes
  winbind offline logon = yes
  winbind enum groups = no
  winbind enum users = no"

echo "$new_content" >  /etc/samba/smb.conf

sudo sed -i 's/^passwd:.*$/passwd:    compat systemd winbind/' /etc/nsswitch.conf
sudo sed -i 's/^group:.*$/group:     compat systemd winbind/' /etc/nsswitch.conf
sudo sed -i 's/^shadow:.*$/shadow:     compat/' /etc/nsswitch.conf


hostname=`hostname`

hostnamectl set-hostname $hostname.lab.local

ip=$(hostname -I | awk '{print $1}')

echo "$ip        $hostname.lab.local $hostname" >> /etc/hosts

echo "$domain_admin_password" | kinit $domain_admin_username
#echo "$2" | kinit $1

echo "$domain_admin_password" | net ads join -U  $domain_admin_username

systemctl enable smbd nmbd winbind
systemctl restart smbd nmbd winbind

echo "%LAB\\\\$domain_admin_username ALL=(ALL)    NOPASSWD:ALL" >> /etc/sudoers
sudo pam-auth-update --enable mkhomedir
