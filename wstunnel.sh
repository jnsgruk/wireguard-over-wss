#!/bin/bash

#
# Original script downloaded from: https://github.com/Kirill888/notes/blob/wg-tunnel-update/wireguard/scripts/wstunnel.sh
# Modified by jnsgruk to use `ip route` for modern Linux distros
#

DEFAULT_HOSTS_FILE='/etc/hosts'

read_host_entry () {
    local host=$1
    local hfile=${2:-${DEFAULT_HOSTS_FILE}}
    awk -v host="$host" '{
     if( !($0~"^[ ]*#") && $2==host )
       print $1, ($0~"## wstunnel end-point")?"auto":"manual"
     }' "${hfile}"
}

add_host_entry () {
    local host=$1
    local ip=$2
    local hfile=${3:-${DEFAULT_HOSTS_FILE}}
    echo -e "${ip}\t${host}\t## wstunnel end-point" >> "${hfile}"
}

update_host_entry () {
    local host=$1
    local ip=$2
    local hfile=${3:-${DEFAULT_HOSTS_FILE}}
    local edited
    edited=$(awk -v host="$host" -v ip="$ip" '{
      if( !($0~"^[ ]*#") && $2==host && ($0~"## wstunnel end-point") )
        print ip "\t" host "\t" "## wstunnel end-point"
      else
        print $0
      }' "${hfile}")

    echo "${edited}" > "${hfile}"
}

delete_host_entry () {
    local host=$1
    local hfile=${2:-${DEFAULT_HOSTS_FILE}}
    local edited
    edited=$(awk -v host="$host" '{
      if( !($0~"^[ ]*#") && $2==host && ($0~"## wstunnel end-point") )
        ;
      else
        print $0
      }' "${hfile}")

    echo "${edited}" > "${hfile}"
}

maybe_update_host () {
    local host="$1"
    local current_ip="$2"
    local hfile=${3:-${DEFAULT_HOSTS_FILE}}
    local recorded_ip h_mode

    read -r recorded_ip h_mode < <(read_host_entry "${host}" "${hfile}") || true

    if [[ -z "${recorded_ip}" ]]; then
        echo "[#] Add new entry ${host} => <${current_ip}>"
        add_host_entry "${host}" "${current_ip}" "${hfile}"
    else
        if [[ "${recorded_ip}" == "${current_ip}" ]]; then
            echo "[#] Recorded address is already correct"
        else
            if [[ "${h_mode}" == "auto" ]]; then
                echo "[#] Updating ${recorded_ip} -> ${current_ip}"
                update_host_entry "${host}" "${current_ip}" "${hfile}"
            else
                echo "[#] Manual entry doesn't match current ip: ${recorded_ip} -> ${current_ip}"
                exit 2
            fi
        fi
    fi
}

launch_wstunnel () {
    local host=${REMOTE_HOST}
    local rport=${REMOTE_PORT:-51820}
    local wssport=${WSS_PORT:-443}
    local lport=${LOCAL_PORT:-${rport}}
    local prefix=${WS_PREFIX:-"wstunnel"}
    local user=${1:-"nobody"}
    local timeout=${TIMEOUT:-"-1"}
    local cmd

    cmd=$(command -v wstunnel)
    cmd="sudo -n -u ${user} -- $cmd"

    $cmd >/dev/null 2>&1 </dev/null \
      --quiet \
      --udpTimeoutSec "${timeout}" \
      --upgradePathPrefix "${prefix}" \
      --udp  -L "127.0.0.1:${lport}:127.0.0.1:${rport}" \
      "wss://${host}:${wssport}" & disown
    echo "$!"
}

pre_up () {
    local wg=$1
    local cfg="/etc/wireguard/${wg}.wstunnel"
    local remote remote_ip gw wstunnel_pid hosts_file _dnsmasq

    if [[ -f "${cfg}" ]]; then
        # shellcheck disable=SC1090
        source "${cfg}"
        remote=${REMOTE_HOST}
        hosts_file=${UPDATE_HOSTS}
        _dnsmasq=${USING_DNSMASQ:-0}
    else
        echo "[#] Missing config file: ${cfg}"
        exit 1
    fi

    remote_ip=$(dig +short "${remote}")

    if [[ -z "${remote_ip}" ]]; then
        echo "[#] Can't resolve ${remote}"
        exit 1
    fi

    if [[ -f "${hosts_file}" ]]; then
        # Cache DNS in
        maybe_update_host "${remote}" "${remote_ip}" "${hosts_file}"

        [[ $_dnsmasq -eq 0 ]] || killall -HUP dnsmasq || true
    fi

    # Find out current route to ${remote_ip} and make it explicit
    gw=$(ip route get "${remote_ip}" | cut -d" " -f3)
    ip route add "${remote_ip}" via "${gw}" > /dev/null 2>&1 || true
    # Start wstunnel in the background
    wstunnel_pid=$(launch_wstunnel nobody)

    # save state
    mkdir -p /var/run/wireguard
    echo "${wstunnel_pid} ${remote} ${remote_ip} \"${hosts_file}\" ${_dnsmasq}" > "/var/run/wireguard/${wg}.wstunnel"
}

post_up () {
    local tun=$1
    ip route add 0.0.0.0/1 dev "${tun}" > /dev/null 2>&1
    ip route add ::0/1 dev "${tun}" > /dev/null 2>&1
    ip route add 128.0.0.0/1 dev "${tun}" > /dev/null 2>&1
    ip route add 8000::/1 dev "${tun}" > /dev/null 2>&1
}

post_down () {
    local tun=$1
    local state_file="/var/run/wireguard/${tun}.wstunnel"
    local wstunnel_pid remote remote_ip hosts_file _dnsmasq

    if [[ -f "${state_file}" ]]; then
        read -r wstunnel_pid remote remote_ip hosts_file _dnsmasq < "${state_file}"
        # unquote
        hosts_file=${hosts_file%\"}
        hosts_file=${hosts_file#\"}

        rm "${state_file}"
    else
        echo "[#] Missing state file: ${state_file}"
        exit 1
    fi

    kill -TERM "${wstunnel_pid}" > /dev/null 2>&1 || true

    if [[ -n "${remote_ip}" ]]; then
	    ip route delete "${remote_ip}" > /dev/null 2>&1 || true
    fi

    if [[ -f "${hosts_file}" ]]; then
        delete_host_entry "${remote}" "${hosts_file}"
        [[ $_dnsmasq -eq 0 ]] || killall -HUP dnsmasq || true
    fi
}
