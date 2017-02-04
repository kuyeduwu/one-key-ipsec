# 一键搭建适用于Ubuntu的IPSec/IKEv2 VPN

使用bash脚本一键搭建IPSec/IKEv2的vpn服务端.

# 注意

该脚本目前只适用于在Vultr处购买的基于KVM的Ubuntu 16.10(x64) VPS服务器，未针对32位系统以及其它任何VPS提供商的任何平台做任何测试。

# 感谢

在strongswan的配置过程中，参考过以下内容，特此感谢：

1. [Strongswan WiKi](https://wiki.strongswan.org)
2. [ATI的硬體&攝影網誌](https://atifans.net/articles/ipsec-ikev2-server-on-fedora-rhel-centos/)

该脚本的完成过程中，参考了[quericy](https://quericy.me)的作品，特此感谢。

# 说明

1.请以`root`用户或者通过`sudo`命令执行该脚本。

2.请确保当前系统所使用的防火墙为`iptables`。

3.在运行过程中，需要提供网卡名称，请通过`ifconfig`命令查询。默认使用`ens3`作为网卡名称。

4.在运行结束之前，该脚本会询问`Export Password`，此为客户端证书的密码，在某些客户端上导入证书时会用到该密码，请用户自行提供。

4.自动配置完毕后，默认的vpn用户名为`myUserName`，默认密码为`myUserPass`，默认`PSK`为`myPSKkey`，请务必编辑`/usr/local/etc/ipsec.secrets`文件以修改默认用户名和密码。

5.iOS端不需要额外的APP，请直接在设置中添加`IPSec VPN`，并提供用户名，密码，PSK即可连接。

6.身边没有安卓，Windows Phone以及Windows Mobile设备，所以暂时不清楚他们的连接方式。

7.Windows PC端在使用前需要将配置过程中生成的`p12`文件导入到本地计算机受信任的根证书颁发机构，导入的过程中会需要用户提供此前设置的`Export Password`。

8.Windows端请确保VPN连接按照如下方式设置：

  - VPN类型为IKEv2
  
  - 数据加密为：需要加密（如果服务器拒绝将断开连接）
  
  - 身份验证为：使用可扩展的身份验证协议，并且选择：Microsoft：安全密码（EAP-MSCHAP v2）（启用加密）
