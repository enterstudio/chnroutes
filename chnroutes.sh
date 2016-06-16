#!/bin/sh

[ `uname` = Darwin ] && mac=true || mac=false
dir=~/.chnroutes
up=ip-pre-up
down=chnroutes-down.sh
url=ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest
apnic=${url##*/}
ip='\([[:digit:]]\+\.\)\{3\}[[:digit:]]\+'
date=`date +'%Y-%m-%d %H:%M'`

cidr(){
	case $1 in 256) echo 24;;
				512) echo 23;;
				1024) echo 22;;
				2048) echo 21;;
				4096) echo 20;;
				8192) echo 19;;
				16384) echo 18;;
				32768) echo 17;;
				65536) echo 16;;
				131072) echo 15;;
				262144) echo 14;;
				524288) echo 13;;
				1048576) echo 12;;
				2097152) echo 11;;
				4194304) echo 10;;
				8388608) echo 9;;
				16777216) echo 8
	esac
}

msg(){
	$mac && echo $1 || echo -e $1
}

chkmd5(){
	msg '\x1b[32mCheck MD5:\x1b[0m'
	if $mac; then
		[[ `md5 $apnic` = `< $apnic.md5` ]] && valid=true || valid=false
		$valid && echo $apnic: OK || echo $apnic: FAILED
		$valid
	else
		md5sum -c $apnic.md5
	fi
}

download(){
	msg "\x1b[32mDownload $apnic:\x1b[0m"
	curl -O $url -O $url.md5
}

if [[ $1 = -r ]]; then
	mkdir -p $dir && cd $_
	if [[ ! -f $apnic || ! -f $apnic.md5 || `find $apnic -mtime +0` ]]; then
		download && chkmd5 || exit
	else
		chkmd5 || { download && chkmd5; } || exit
	fi

	msg '\x1b[32mGenrate route files:\x1b[0m'
	cat <<EOF > $up
#!/bin/sh
#
# Generated on $date by chnroutes
# https://github.com/soa/chnroutes
#

g=\`ip r s 0/0 | grep -om1 '$ip' | head -1\`
[ -z \$g ] && exit 0

ip r d default

ip -b - <<EOF
EOF
	cat <<EOF > $down
#!/bin/sh
#
# Generated on $date by chnroutes
# https://github.com/soa/chnroutes
#

ip -b - <<EOF
EOF
	grep '^apnic|CN|ipv4|' $apnic | grep -o "$ip|[[:digit:]]\+" | while read line
	do
		ip=${line%|*}
		cidr=`cidr ${line#*|}`
		echo r a $ip/$cidr via \$g >> $up || exit
		echo r d $ip/$cidr >> $down || exit
		i=$[i+1]
		[ $[i%100] -eq 0 ] && printf '#'
	done
	echo EOF >> $up
	echo EOF >> $down
	msg "\nDone, use 'chnroutes -i' to install."
elif [[ $1 = -i ]]; then
	install -m 755 $dir/$up /etc/ppp/
	install -m 755 $dir/$down /etc/ppp/ip-down.d/
else
	cat << EOF
Shell script to genrate route table for mainlanders.
https://github.com/soa/chnroutes

options:
  -r = genrate route files
  -i = install to /etc/ppp
EOF
fi