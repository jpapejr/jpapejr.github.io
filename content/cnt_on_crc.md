This how-to will cover how to get a working CRC development cluster running the Cloud Native ToolKit on IBM Cloud Bare Metal
and access it remotely.

**This is a work in progress until this message is removed**

CentOS machine 20x384 4TB storage

Remote access https://access.redhat.com/documentation/en-us/red_hat_codeready_containers/1.18/html/getting_started_guide/networking_gsg#connecting-to-remote-instance_gsg

export CRC_IP=**bare metal public ip**

Create `pull-secret.txt` using the pull secret data provided at https://cloud.redhat.com/openshift/install/crc/installer-provisioned

```
#as root
systemctl enable --now cockpit.socket (rest of work can be done from Cockpit IP:9090)


yum update
yum install haproxy
sudo systemctl start firewalld
firewall-cmd --add-port=80/tcp --permanent
firewall-cmd --add-port=6443/tcp --permanent
firewall-cmd --add-port=443/tcp --permanent
firewall-cmd --add-port=53/udp --permanent
systemctl restart firewalld
semanage port -a -t http_port_t -p tcp 6443
cp /etc/haproxy/haproxy.cfg{,.bak}

tee /etc/haproxy/haproxy.cfg &>/dev/null <<EOF
global
    debug

defaults
    log global
    mode http
    timeout connect 5000
    timeout client 5000
    timeout server 5000

frontend apps
    bind 0.0.0.0:80
    bind 0.0.0.0:443
    option tcplog
    mode tcp
    default_backend apps

backend apps
    mode tcp
    balance roundrobin
    option ssl-hello-chk
    server webserver1 $CRC_IP:443 check

frontend api
    bind 0.0.0.0:6443
    option tcplog
    mode tcp
    default_backend api

backend api
    mode tcp
    balance roundrobin
    option ssl-hello-chk
    server webserver1 $CRC_IP:6443 check
EOF

systemctl enable haproxy
systemctl start haproxy
useradd crc
usermod -aG wheel crc
su - crc
wget https://mirror.openshift.com/pub/openshift-v4/clients/crc/latest/crc-linux-amd64.tar.xz
tar xvf crc-linux-amd64.tar.xz
sudo mv crc-linux*/crc /usr/local/bin
crc setup
crc start --cpus 18 --disk-size 931 --memory 358400 --nameserver 8.8.8.8 --pull-secret-file pull-secret.txt
```

Add CloudNativeToolkit with

```
oc apply -f https://raw.githubusercontent.com/ibm-garage-cloud/ibm-garage-iteration-zero/master/install/install-ibm-toolkit.yaml
```

From your client machine, set up a resolver for the `testing` domain that resolves `*.testing` to the bare metal.

Probably need to extract the self-signed OCP cert and import into keystore and trust it to use everything right.

```
openssl s_client -connect api.crc.testing:443 </dev/null 2>/dev/null|openssl x509 -outform PEM >mycertfile.pem
```


References:

https://www.tecmint.com/setup-a-dns-dhcp-server-using-dnsmasq-on-centos-rhel/
https://fabianlee.org/2018/10/22/kvm-using-dnsmasq-for-libvirt-dns-resolution/
https://gist.github.com/sub-mod/ff999cb17940116a5ddea8d496c4b3f6
https://www.rootusers.com/how-to-open-a-port-in-centos-7-with-firewalld/
https://vrandombites.co.uk/macos/macos-multiple-resolver-configs/
https://fedoramagazine.org/using-the-networkmanagers-dnsmasq-plugin/
https://access.redhat.com/documentation/en-us/red_hat_codeready_containers/1.18/html/getting_started_guide/networking_gsg#connecting-to-remote-instance_gsg