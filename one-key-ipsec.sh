#!/bin/bash

#===============================================================================================
#   System Required:  Ubuntu 16.10(x64) on KVM
#   VPS Service Provider: Vultr
#   Description:  Deploy Strongswan on Ubuntu
#   Author: Rick
#   Thanks to: quericy
#   Inspired by: https://github.com/quericy/one-key-ikev2-vpn.git
#===============================================================================================

clear
VER=0.0.1
echo "#############################################################"
echo "# Deploy Strongswan on Ubuntu 16.10(x64)"
echo "#"
echo "# Author:Rick"
echo "#"
echo "# Thanks to:quericy"
echo "#"
echo "# Version:$VER"
echo "#############################################################"
echo ""

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "Error:This script must be run as root!" 1>&2
   exit 1
fi

# Get the IP address
ip_addr=`ifconfig | grep 'inet ' | grep -v '127.0.0.1' | awk -Ft '{print $2}' | awk '{print $1}'`

# Get the description name of the Ethernet
read -p "Network card interface(default_value:ens3):" desc_name
if [ "$desc_name" = "" ]; then
    desc_name="ens3"
fi

# Install dependencies
apt-get -y update
apt-get -y install libpam0g-dev libssl-dev make gcc wget

# Download strongswan
wget http://download.strongswan.org/strongswan.tar.gz

# Config strongswan
tar xzf strongswan.tar.gz
cd strongswan-*
./configure  --enable-eap-identity --enable-eap-md5 \
--enable-eap-mschapv2 --enable-eap-tls --enable-eap-ttls --enable-eap-peap  \
--enable-eap-tnc --enable-eap-dynamic --enable-eap-radius --enable-xauth-eap  \
--enable-xauth-pam  --enable-dhcp  --enable-openssl  --enable-addrblock --enable-unity  \
--enable-certexpire --enable-radattr --enable-swanctl --enable-openssl --disable-gmp
make; make install
cd ..

# Generate cert
ipsec pki --gen --outform pem > ca.pem
ipsec pki --self --in ca.pem --dn "C=CN, O=Vurtl, CN=Ubuntu VPN CA" --ca --outform pem >ca.cert.pem
ipsec pki --gen --outform pem > server.pem
ipsec pki --pub --in server.pem | ipsec pki --issue --cacert ca.cert.pem \
--cakey ca.pem --dn "C=CN, O=Vurtl, CN=${ip_addr}" \
--san="${ip_addr}" --flag serverAuth --flag ikeIntermediate \
--outform pem > server.cert.pem
ipsec pki --gen --outform pem > client.pem
ipsec pki --pub --in client.pem | ipsec pki --issue --cacert ca.cert.pem --cakey ca.pem --dn "C=CN, O=Vurtl, CN=Ubuntu VPN Client" --outform pem > client.cert.pem
openssl pkcs12 -export -inkey client.pem -in client.cert.pem -name "client" -certfile ca.cert.pem -caname "Ubuntu VPN CA"  -out client.cert.p12

# Install cert
cp -r ca.cert.pem /usr/local/etc/ipsec.d/cacerts/
cp -r server.cert.pem /usr/local/etc/ipsec.d/certs/
cp -r server.pem /usr/local/etc/ipsec.d/private/
cp -r client.cert.pem /usr/local/etc/ipsec.d/certs/
cp -r client.pem  /usr/local/etc/ipsec.d/private/

# Config firewall (iptables)
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -s 10.31.0.0/24  -j ACCEPT
iptables -A FORWARD -s 10.31.1.0/24  -j ACCEPT
iptables -A FORWARD -s 10.31.2.0/24  -j ACCEPT
iptables -A INPUT -i $desc_name -p esp -j ACCEPT
iptables -A INPUT -i $desc_name -p udp --dport 500 -j ACCEPT
iptables -A INPUT -i $desc_name -p tcp --dport 500 -j ACCEPT
iptables -A INPUT -i $desc_name -p udp --dport 4500 -j ACCEPT
iptables -A INPUT -i $desc_name -p udp --dport 1701 -j ACCEPT
iptables -A INPUT -i $desc_name -p tcp --dport 1723 -j ACCEPT
iptables -A FORWARD -j REJECT
iptables -t nat -A POSTROUTING -s 10.31.0.0/24 -o $desc_name -j MASQUERADE
iptables -t nat -A POSTROUTING -s 10.31.1.0/24 -o $desc_name -j MASQUERADE
iptables -t nat -A POSTROUTING -s 10.31.2.0/24 -o $desc_name -j MASQUERADE

# Save firewall settings
iptables-save > /etc/iptables.rules
cat > /etc/network/if-up.d/iptables<<-EOF
#!/bin/sh
iptables-restore < /etc/iptables.rules
EOF
chmod +x /etc/network/if-up.d/iptables

# Config files
# ipsec.conf
cat > /usr/local/etc/ipsec.conf<<-EOF
config setup
    uniqueids=no
conn iOS_cert
    keyexchange=ikev1
    fragmentation=yes
    left=%defaultroute
    leftauth=pubkey
    leftsubnet=0.0.0.0/0
    leftcert=server.cert.pem
    right=%any
    rightauth=pubkey
    rightauth2=xauth
    rightsourceip=10.31.2.0/24
    rightcert=client.cert.pem
    auto=add

conn android_xauth_psk
    keyexchange=ikev1
    left=%defaultroute
    leftauth=psk
    leftsubnet=0.0.0.0/0
    right=%any
    rightauth=psk
    rightauth2=xauth
    rightsourceip=10.31.2.0/24
    auto=add

conn networkmanager-strongswan
    keyexchange=ikev2
    left=%defaultroute
    leftauth=pubkey
    leftsubnet=0.0.0.0/0
    leftcert=server.cert.pem
    right=%any
    rightauth=pubkey
    rightsourceip=10.31.2.0/24
    rightcert=client.cert.pem
    auto=add

conn windows7
    keyexchange=ikev2
    ike=aes256-sha1-modp1024!
    rekey=no
    left=%defaultroute
    leftauth=pubkey
    leftsubnet=0.0.0.0/0
    leftcert=server.cert.pem
    right=%any
    rightauth=eap-mschapv2
    rightsourceip=10.31.2.0/24
    rightsendcert=never
    eap_identity=%any
    auto=add
EOF

# strongswan.conf
cat > /usr/local/etc/strongswan.conf<<-EOF
charon {
       load_modular = yes
       duplicheck.enable = no
       compress = yes
       plugins {
               include strongswan.d/charon/*.conf
       }
       dns1 = 8.8.8.8
       dns2 = 8.8.4.4
       nbns1 = 8.8.8.8
       nbns2 = 8.8.4.4
}
include strongswan.d/*.conf
EOF

# ipsec.secrets
cat > /usr/local/etc/ipsec.secrets<<-EOF
: RSA server.pem
: PSK "myPSKkey"
: XAUTH "myXAUTHPass"
myUserName %any : EAP "myUserPass"
EOF

# Enable forward
echo "net.ipv4.ip_forward=1" >>/etc/sysctl.conf
sysctl -p

# Start service
ipsec start

__INTERACTIVE=""
if [ -t 1 ] ; then
    __INTERACTIVE="1"
fi

__green(){
    if [ "$__INTERACTIVE" ] ; then
        printf '\033[1;31;32m'
    fi
    printf -- "$1"
    if [ "$__INTERACTIVE" ] ; then
        printf '\033[0m'
    fi
}

__red(){
    if [ "$__INTERACTIVE" ] ; then
        printf '\033[1;31;40m'
    fi
    printf -- "$1"
    if [ "$__INTERACTIVE" ] ; then
        printf '\033[0m'
    fi
}

__yellow(){
    if [ "$__INTERACTIVE" ] ; then
        printf '\033[1;31;33m'
    fi
    printf -- "$1"
    if [ "$__INTERACTIVE" ] ; then
        printf '\033[0m'
    fi
}

# Complete
echo "#############################################################"
echo -e "#"
echo -e "# [$(__green "Install Complete")]"
echo -e "# Version:$VER"
echo -e "# Here is the default login info of your IPSec/IkeV2 VPN Service"
echo -e "# UserName:$(__green " myUserName")"
echo -e "# PassWord:$(__green " myUserPass")"
echo -e "# PSK:$(__green " myPSKkey")"
echo -e "# you should $(__red "change default username and password") in$(__yellow " /usr/local/etc/ipsec.secrets")"
echo -e "#"
echo -e "#############################################################"
echo -e ""
