#!/bin/bash
# Find network peers for bonding setup
# Keith Fralick
# ( very minor updates: Troy Engel )

if [ `id -u` -ne 0 ]; then
        echo "root privileges needed to properly run this tool"
        exit 1
fi

cat >finder.c<<!EOF!
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <linux/if_ether.h>
#include <netinet/in.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <netpacket/packet.h>
#include <time.h>
#include <signal.h>
#include <unistd.h>
void die() { exit(0); }
int main(int argc, char **argv) {
        FILE *fp;
        int fd1, fd2, s, on = 1, i = 0, count = 0;
        unsigned char buf[1024];
        unsigned char output[1024] = {0xff,0xff,0xff,0xff,0xff,0xff,0x00,0x00,0x00,0x00,0x00,0x00,0x98,0x98};
        struct  ifreq ifr, ifr2;
        struct  sockaddr_ll     sock, sock2;

        argc--;++argv;
        if (argc < 2)
                return -1;
        fp = fopen("/dev/urandom", "r");
        fread(&output[i+14], 1, 256, fp);
        fclose(fp);
        memset(&ifr, 0, sizeof ifr);
        memset(&ifr2, 0, sizeof ifr2);
        strncpy(ifr.ifr_name, argv[0], sizeof ifr.ifr_name);
        strncpy(ifr2.ifr_name, argv[1], sizeof ifr.ifr_name);
        fd1 = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL));
        fd2 = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL));

        setsockopt(fd1, SOL_SOCKET, SO_BINDTODEVICE, &ifr, sizeof ifr);
        setsockopt(fd2, SOL_SOCKET, SO_BINDTODEVICE, &ifr2, sizeof ifr2);
        setsockopt(fd1, SOL_SOCKET, SO_BROADCAST, &on, sizeof on);
        ioctl(fd1, SIOCGIFINDEX, &ifr);
        ioctl(fd2, SIOCGIFINDEX, &ifr2);
        sock.sll_family = sock2.sll_family = AF_PACKET;
        sock.sll_ifindex = ifr.ifr_ifindex;
        sock.sll_protocol = sock2.sll_protocol = htons(ETH_P_ALL);
        sock2.sll_ifindex = ifr2.ifr_ifindex;
        bind(fd1, (struct sockaddr *)&sock, sizeof sock);
        bind(fd2, (struct sockaddr *)&sock2, sizeof sock2);
        signal(SIGALRM, die);
        alarm(2);

        while (1) {
                if (++count < 10)
                        sendto(fd1, output, 270, 0, 0, 0);
                if ((s = read(fd2, buf, sizeof buf)) == 270) {
                        if(!memcmp(buf, output, 270)) {
                                puts("MATCH");
                                break;
                        }
                }
        }
        return 0;
}
!EOF!
gcc finder.c -o finder

if [ ! -x "./finder" ]; then
        echo "finder.c could not compile, is gcc installed?"
        exit 1
fi

N=`ifconfig -a|grep -vE '^(\s|$)'|awk '{print $1}'|grep -v '^lo$'`
for i in $N
do
        ifconfig $i up
done
sleep 10
AC=0
for a in $N
do
        BC=0
        for b in $N
        do
                prev=$BC
                BC=`expr $BC + 1`
                if [ $prev -le $AC ]
                then
                        continue
                fi
                if [ "`./finder $a $b`" = "MATCH" ]
                then
                        echo "$a->$b"
                fi
        done
        AC=`expr $AC + 1`
done
