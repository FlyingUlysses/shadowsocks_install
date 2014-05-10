#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#===============================================================================================
#   System Required:  CentOS5.x (32bit/64bit) or CentOS6.x (32bit/64bit)
#   Description:  Install Shadowsocks(Nodejs) for CentOS
#   Author: Teddysun <i@teddysun.com>
#   Intro:  http://teddysun.com/355.html
#===============================================================================================

clear
echo "#############################################################"
echo "# Install Shadowsocks(Nodejs) for CentOS5.x (32bit/64bit) or CentOS6.x (32bit/64bit)"
echo "# Intro: http://teddysun.com/355.html"
echo "#"
echo "# Author: Teddysun <i@teddysun.com>"
echo "#"
echo "#############################################################"
echo ""

# Get IP address(Default No.1)
IP=`ifconfig | grep 'inet addr:'| grep -v '127.0.0.*' | cut -d: -f2 | awk '{ print $1}' | head -1`;
# Get Nodejs latest version
NODEJS_VER=`curl -s http://nodejs.org/download/ | awk -F'<b>' '/Current version/{print $2}' | cut -d '<' -f 1`

# Install Shadowsocks-nodejs
function install_shadowsocks_nodejs(){
    rootness
    disable_selinux
    pre_install
    download_files
    config_shadowsocks
    iptables_set
    install
}

# Make sure only root can run our script
function rootness(){
if [[ $EUID -ne 0 ]]; then
   echo "Error:This script must be run as root!" 1>&2
   exit 1
fi
}

# Disable selinux
function disable_selinux(){
if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0
fi
}

# Pre-installation settings
function pre_install(){
    #Set shadowsocks-nodejs config password
    echo "Please input password for shadowsocks-nodejs:"
    read -p "(Default password: teddysun.com):" shadowsockspwd
    if [ "$shadowsockspwd" = "" ]; then
        shadowsockspwd="teddysun.com"
    fi
    echo "password:$shadowsockspwd"
    echo "####################################"
    get_char(){
        SAVEDSTTY=`stty -g`
        stty -echo
        stty cbreak
        dd if=/dev/tty bs=1 count=1 2> /dev/null
        stty -raw
        stty echo
        stty $SAVEDSTTY
    }
    echo ""
    echo "Press any key to start...or Press Ctrl+C to cancel"
    char=`get_char`
    #Install necessary dependencies
    yum install -y wget unzip openssl-devel gcc swig python python-devel python-setuptools autoconf libtool libevent
    yum install -y automake make curl curl-devel zlib-devel openssl-devel perl perl-devel cpio expat-devel gettext-devel
    #Current folder
    cur_dir=`pwd`
    cd $cur_dir
}

# Download latest NodeJS
function download_files(){
    if [ -f node-${NODEJS_VER}.tar.gz ];then
        echo "node-${NODEJS_VER}.tar.gz [found]"
    else
        if ! wget http://nodejs.org/dist/${NODEJS_VER}/node-${NODEJS_VER}.tar.gz;then
            echo "Failed to download node-${NODEJS_VER}.tar.gz"
            exit 1
        fi
    fi
    # Untar Nodejs file
    tar -zxf node-${NODEJS_VER}.tar.gz
    if [ $? -eq 0 ];then
        cd $cur_dir/node-${NODEJS_VER}/
    else
        echo ""
        echo "Untar Nodejs failed! Please visit http://teddysun.com/355.html and contact."
        exit 1
    fi
}

# Config shadowsocks
function config_shadowsocks(){
    touch /etc/config.json
    cat >>/etc/config.json<<-EOF
{
    "server":"${IP}",
    "server_port":8989,
    "local_address":"127.0.0.1",
    "local_port":1080,
    "password":"${shadowsockspwd}",
    "timeout":600,
    "method":"aes-256-cfb"
}
EOF
}

# iptables set
function iptables_set(){
    /sbin/service iptables status 1>/dev/null 2>&1
    if [ $? -eq 0 ]; then
        /etc/init.d/iptables status | grep '8989' | grep 'ACCEPT' >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            /sbin/iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 8989 -j ACCEPT
            /etc/init.d/iptables save
            /etc/init.d/iptables restart
        fi
    fi
}


# Install 
function install(){
    # Build and Install Nodejs
    if [ ! -s /usr/local/bin/npm ];then
        ./configure
        make && make install
    fi
    # Install shadowsocks-Nodejs
    which npm > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        cd $cur_dir
        npm install -g shadowsocks
    else
        echo ""
        echo "Nodejs install failed! Please visit http://teddysun.com/355.html and contact."
        exit 1
    fi
    # Run it in the background
    if [ -s /usr/local/bin/ssserver ]; then
        nohup ssserver -c /etc/config.json > /dev/null 2>&1 &
        if [ $? -eq 0 ]; then
            echo "Shadowsocks-nodejs start success!"
        else
            echo "Shadowsocks-nodejs start failure!"
        fi
        # Add run on system start up
        cat /etc/rc.d/rc.local | grep 'ssserver' > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "nohup ssserver -c /etc/config.json > /dev/null 2>&1 &" >> /etc/rc.d/rc.local
        fi
    else
        echo ""
        echo "Shadowsocks-nodejs install failed! Please visit http://teddysun.com/355.html and contact."
        exit 1
    fi
    # Delete Nodejs untar floder
    rm -rf $cur_dir/node-${NODEJS_VER}/
    # Delete Nodejs file
    rm -f node-${NODEJS_VER}.tar.gz
    clear
    echo ""
    echo "Congratulations, shadowsocks-nodejs install completed!"
    echo -e "Your Server IP: \033[41;37m ${IP} \033[0m"
    echo -e "Your Server Port: \033[41;37m 8989 \033[0m"
    echo -e "Your Password: \033[41;37m ${shadowsockspwd} \033[0m"
    echo -e "Your Proxy Port: \033[41;37m 1080 \033[0m"
    echo ""
    echo ""
    echo "Welcome to visit:http://teddysun.com/355.html"
    echo "Enjoy it! ^_^"
}

# Uninstall Shadowsocks-nodejs
function uninstall_shadowsocks_nodejs(){
    NODE_PID=`ps -ef | grep -v grep | grep -v ps | grep -i 'node /usr/local/bin/ssserver' | awk '{print $2}'`
    if [ ! -z $NODE_PID ]; then
        for pid in $NODE_PID
        do
            kill -9 $pid
            if [ $? -eq 0 ]; then
                echo "Shadowsocks-nodejs process[$pid] has been killed"
            fi
        done
    fi
    # delete config file
    rm -f /etc/config.json
    cd /usr/local/lib/node_modules/
    npm uninstall shadowsocks
    rm -f /usr/local/bin/sslocal
    rm -f /usr/local/bin/ssserver
    echo "Shadowsocks-nodejs uninstall success!"
}

# Initialization step
action=$1
[  -z $1 ] && action=install
case "$action" in
install)
    install_shadowsocks_nodejs
    ;;
uninstall)
    uninstall_shadowsocks_nodejs
    ;;
*)
    echo "Arguments error! [${action} ]"
    echo "Usage: `basename $0` {install|uninstall}"
    ;;
esac