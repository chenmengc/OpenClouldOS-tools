#!/bin/sh

# ===================================================
# Copyright (c) [2021] [Tencent]
# [OpenCloudOS Tools] is licensed under Mulan PSL v2.
# You can use this software according to the terms and conditions of the Mulan PSL v2. 
# You may obtain a copy of Mulan PSL v2 at:
#            http://license.coscl.org.cn/MulanPSL2 
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.  
# See the Mulan PSL v2 for more details.  
# ===================================================

#
# Tos common variables and functions
# author: g_CAPD_SRDC_OS@tencent.com
#

. /usr/lib/opencloudos-tools/tos-fix-dns.sh
. /usr/lib/opencloudos-tools/tos-backup.sh
. /usr/lib/opencloudos-tools/tos-analyze-performance.sh
TOS_RELEASE="/etc/tlinux-release"
KERNEL_VER=$(uname -r)
TOS_VER_V=""
TOS_VER=""
TOS_DATE=""

# check tlinux2
is_tlinux2()
{
    [ ! -f $TOS_RELEASE ] && return 1
    grep -q "Tencent tlinux release 2." $TOS_RELEASE || \
        grep -q "Tencent Linux release 2." $TOS_RELEASE
}

#check tlinux
is_tlinux()
{
    t_v=$1
    [ ! -f $TOS_RELEASE ] && return 1
    grep -q "Tencent tlinux release $t_v" $TOS_RELEASE || \
        grep -q "Tencent Linux release $t_v" $TOS_RELEASE
}

#get tlinux version and date
getVersionDate()
{
    if [ -f /etc/motd ]; then
        TOS_VER=$(awk '/Version/{print $2}' /etc/motd)
        TOS_DATE=$(awk '/Version/{print $NF}' /etc/motd)
    fi
    if [ -f $TOS_RELEASE ]; then
        TOS_VER_V=$(head $TOS_RELEASE)
    fi
        
}

#check machine type, dependent on virt-what
vmwhat()
{
    if [ ! -x /usr/sbin/virt-what ]; then
        echo "Try to install virt-what rpm by yum!"
        yum -y install virt-what > /dev/null 2>&1
    fi
    if [ -x /usr/sbin/virt-what ]; then
	echo -e -n "Machine type:\t\t"
        v_what=$(/usr/sbin/virt-what)
        [ -z "$v_what" ] && echo "Physical machine" && return 0
        echo $v_what | grep -q -i "virtualbox"  && echo "Virtualbox guest" && return 0
        echo $v_what | grep -q -i "vmware" && echo "VMware guest" && return 0
        echo "$v_what"
        return 0
    fi
}

#show tencentos system information
tos_show()
{
    echo "=============== System Information ==============="
    # get SN
    if [ -x /usr/sbin/dmidecode ]; then
        seri_num=$(dmidecode -s system-serial-number | tail -n1)
	[ -n "$seri_num" ] && echo -e "Serial Number:\t\t$seri_num"
    fi

    # get IP
    eth1_ip=$(ip a | grep "inet" | grep "eth1" | awk '{print $2}' | awk -F/ '{print $1}')
    if [ -n "$eth1_ip" ]; then
        echo -e "eth1 IP:\t\t$eth1_ip"
    else
        other_ip=$(ip a|grep "inet"|grep -v "inet6"|grep -v "127.0"|head -n1|awk '{print $2}'|awk -F/ '{print $1}')
	[ -n "$other_ip" ] && echo -e "IP:\t\t$other_ip"
    fi

    # get machine type
    if which rpm &> /dev/null ;then
        vmwhat
    fi

    # get system version
    [ -n "$KERNEL_VER" ] && echo -e "Kernel version:\t\t$KERNEL_VER"

    getVersionDate
    if [ -n "$TOS_VER_V" ]; then
        echo -e "OpenCloudOS release:\t$TOS_VER_V"
    elif [ -f /etc/os-release ]; then
	echo -e -n "OS release:\t\t"
	awk -F'"' '/PRETTY_NAME/ {print $2}' /etc/os-release
    fi

    if [ -n "$TOS_VER" ]; then 
        echo -e "Release version:\t$TOS_VER"
    fi
    if [ -n "$TOS_DATE" ]; then
	echo -e "Release date:\t\t$TOS_DATE"
    fi

    # get rpm version
    if which rpm &> /dev/null ;then
        GCC_VERSION=$(rpm -q gcc | grep -v "not" | head -n1)
        [ -n "$GCC_VERSION" ] && echo -e "Gcc version:\t\t$GCC_VERSION"
        GLIBC_VERSION=$(rpm -q glibc | grep -v "not" | head -n1)
        [ -n "$GLIBC_VERSION" ] && echo -e "Glibc version:\t\t$GLIBC_VERSION"
        SYSTEMD_VERSION=$(rpm -q systemd | grep -v "not" | head -n1)
        [ -n "$SYSTEMD_VERSION" ] && echo -e "Systemd version:\t$SYSTEMD_VERSION"
        PYTHON_VERSION=$(rpm -q python | grep -v "not" | head -n1)
        [ -n "$PYTHON_VERSION" ] && echo -e "Python version:\t\t$PYTHON_VERSION"
    fi
}


#tencentos check rpms
tos_check()
{
    if [ -n "$1" ]; then
        rpm -qa | grep $1 > /tmp/rpms_list.txt
    else
        echo "It may take few minitues!"
        rpm -qa > /tmp/rpms_list.txt
	
        
    fi
    for i in $(cat /tmp/rpms_list.txt)
    do
        result=$(rpm -q -V $i)
        if [ -n "$result" ]; then
            echo "$i:"
            echo $result
        fi
    done
}


#tencentos update rpms
tos_update()
{
    if [ -n "$1" ]; then
        yum update $@
    else
        yum update
    fi
}

#tencentos install rpms
tos_install()
{
    if [ -n "$1" ]; then
        yum install $@
    else
        echo "You Nedd to pass a list of pkgs to install"
    fi
}

#tencentos fix yum problems, update tlinux-release rpm
tos_fix_yum()
{
    tos_fix_dns
    if [ $? -eq 0 ]; then
        # dig mirrors.tencent.com
        dig_result=$(/usr/bin/dig mirrors.tencent.com)
        answer_section=$(echo $dig_result | grep "ANSWER SECTION:")
        # if we have answer section
        if [ "$answer_section" == "" ]; then
            echo "The DNS can't resolve the domain of mirrors.tencent.com"
            echo "Please configure DNS according to this page: http://mirrors.tencent.com/#/document/question "
            return 1;
        fi
    fi
    if is_tlinux 1.2 ; then
        #tlinux1.2-kvm_guest
        uname -r | grep -q "kvm_guest"
        if [ $? -eq 0 ]; then
            rpm -Uvh https://mirrors.tencent.com/tlinux/rpm/tlinux-release-kvm-guest-1.0-2.tl1.noarch.rpm
            [ $? -ne 0 ] && rpm -ivh --force https://mirrors.tencent.com/tlinux/rpm/tlinux-release-kvm-guest-1.0-2.tl1.noarch.rpm
        fi

        result=$(rpm -q -V python)
        if [ -n "$result" ]; then
            echo "$result"
            echo "python rpm is changed."
            read -r -p "Would you like to reinstall the python rpm?[y/n]" input
            case $input in
                [yY][eE][sS]|[yY])
                    echo "Reinstall python rpm"
                    rpm -ivh --force https://mirrors.tencent.com/tlinux/1.2/os/x86_64/Packages/python-2.6.6-29.el6.x86_64.rpm
                    ;;
                [nN][oO]|[nN])
                    echo "You choose no, exit"
                    exit 0
                    ;;
                *)
                    echo "Invalid input..."
                    exit 1
                    ;;
            esac
        fi

        rpm -Uvh  https://mirrors.tencent.com/tlinux/rpm/epel-release-6-12.tl1.noarch.rpm
        [ $? -ne 0 ] && rpm -ivh --force https://mirrors.tencent.com/tlinux/rpm/epel-release-6-12.tl1.noarch.rpm
        rpm -Uvh  https://mirrors.tencent.com/tlinux/rpm/tlinux-release-1-11.tl1.x86_64.rpm
        [ $? -ne 0 ] && rpm -ivh --force https://mirrors.tencent.com/tlinux/rpm/tlinux-release-1-11.tl1.x86_64.rpm
        return $?
    fi
    if is_tlinux 2.0 ; then
        result=$(rpm -q -V python)
        if [ -n "$result" ]; then
            echo "$result"
            echo "python rpm is changed."
            read -r -p "Would you like to reinstall the python rpm?[y/n]" input
            case $input in
                [yY][eE][sS]|[yY])
                    echo "Reinstall python rpm"
                    python_rpm=$(rpm -q python | grep x86_64)
                    rpm -ivh --force https://mirrors.tencent.com/tlinux/2.0/os/x86_64/Packages/${python_rpm}.rpm
                    rpm -ivh --force https://mirrors.tencent.com/tlinux/2.0/tlinux/x86_64/RPMS/${python_rpm}.rpm
                    ;;
                [nN][oO]|[nN])
                    echo "You choose no, exit"
                    exit 0
                    ;;
                *)
                    echo "Invalid input..."
                    exit 1
                    ;;
            esac
        fi

        rpm -Uvh https://mirrors.tencent.com/tlinux/rpm/tlinux-release-2-4.tl2.x86_64.rpm
        [ $? -ne 0 ] && rpm -ivh --force https://mirrors.tencent.com/tlinux/rpm/tlinux-release-2-4.tl2.x86_64.rpm
        return $?
    fi
    if is_tlinux 2.2 ; then
        #tlinux2.2-kvm_guest
        uname -r | grep -q "kvm_guest"
        if [ $? -eq 0 ]; then
            rpm -Uvh https://mirrors.tencent.com/tlinux/rpm/tlinux-release-kvm-guest-1.0-2.tl2.noarch.rpm
            [ $? -ne 0 ] && rpm -ivh --force https://mirrors.tencent.com/tlinux/rpm/tlinux-release-kvm-guest-1.0-2.tl2.noarch.rpm
        fi
         
        #tlinux2.2-tkernel3
        uname -r | grep -q "tlinux3"
        if [ $? -eq 0 ]; then
            rpm -Uvh https://mirrors.tencent.com/tlinux/rpm/tlinux-tkernel3-release-1.1-1.tl2.noarch.rpm
            [ $? -ne 0 ] && rpm -ivh --force https://mirrors.tencent.com/tlinux/rpm/tlinux-tkernel3-release-1.1-1.tl2.noarch.rpm
        fi
 
        result=$(rpm -q -V python)
        if [ -n "$result" ]; then
            echo "$result"
            echo "python rpm is changed."
            read -r -p "Would you like to reinstall the python rpm?[y/n]" input
            case $input in
                [yY][eE][sS]|[yY])
                    echo "Reinstall python rpm"
                    python_rpm=$(rpm -q python | grep x86_64)
                    rpm -ivh --force https://mirrors.tencent.com/tlinux/2.2/os/x86_64/Packages/${python_rpm}.rpm
                    rpm -ivh --force https://mirrors.tencent.com/tlinux/2.2/tlinux/x86_64/RPMS/${python_rpm}.rpm
                    ;;
                [nN][oO]|[nN])
                    echo "You choose no, exit"
                    exit 0
                    ;;
                *) 
                    echo "Invalid input..."
                    exit 1
                    ;;
            esac
        fi


        rpm -Uvh https://mirrors.tencent.com/tlinux/rpm/tlinux-release-2-11.tl2.x86_64.rpm
        [ $? -ne 0 ] && rpm -ivh --force https://mirrors.tencent.com/tlinux/rpm/tlinux-release-2-11.tl2.x86_64.rpm
        return $?
    fi

    if is_tlinux 2.6 ; then
        result=$(rpm -q -V python)
        if [ -n "$result" ]; then
            echo "$result"
            echo "python rpm is changed."
            read -r -p "Would you like to reinstall the python rpm?[y/n]" input
            case $input in
                [yY][eE][sS]|[yY])
                    echo "Reinstall python rpm"
                    python_rpm=$(rpm -q python | grep x86_64)
                    rpm -ivh --force https://mirrors.tencent.com/tlinux/2.6/os/x86_64/Packages/${python_rpm}.rpm
                    rpm -ivh --force https://mirrors.tencent.com/tlinux/2.6/tlinux/x86_64/RPMS/${python_rpm}.rpm
                    ;;
                [nN][oO]|[nN])
                    echo "You choose no, exit"
                    exit 0
                    ;;
                *) 
                    echo "Invalid input..."
                    exit 1
                    ;;
            esac
        fi

        rpm -Uvh https://mirrors.tencent.com/tlinux/2.6/tlinux/x86_64/RPMS/epel-release-7-13.tl2.noarch.rpm
        [ $? -ne 0 ] && rpm -ivh --force https://mirrors.tencent.com/tlinux/2.6/tlinux/x86_64/RPMS/epel-release-7-13.tl2.noarch.rpm
        rpm -Uvh https://mirrors.tencent.com/tlinux/2.6/tlinux/x86_64/RPMS/tlinux-release-2-11.tl2.1.x86_64.rpm
        [ $? -ne 0 ] && rpm -ivh --force https://mirrors.tencent.com/tlinux/2.6/tlinux/x86_64/RPMS/tlinux-release-2-11.tl2.1.x86_64.rpm
        return $?
    fi
}

# tos fix yum, dns, etc.
tos_fix()
{
    fix_op=$1
    if [ "$fix_op"x == "yum"x ];then
        tos_fix_yum
    elif [ "$fix_op"x == "dns"x ];then
        tos_fix_dns
    else
        echo "tos fix $fix_op: invalid option"
    fi
}

# tos set dns, etc.
tos_set()
{
    set_op=$1
    if [ "$set_op"x == "dns"x ];then
        tos_set_dns
    elif [ "$set_op"x == "irq"x ];then
        if [ ! -x /etc/init.d/irqaffinity ]; then
            yum -y install tlinux-irqaffinity
        fi
        /etc/init.d/irqaffinity restart
    else
        echo "tos set $set_op: invalid option"
    fi
}

# Yum Check Available Package Updates
tos_check_update()
{
    #To see which installed packages on your system have updates available, use the following command
    yum check-update
}

# Recover or Reinstall the system
tos_recover()
{
    /usr/lib/opencloudos-tools/tlinux_super_tool.py -r $@
}

