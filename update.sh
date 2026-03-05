#!/bin/bash -uo pipefail

function safe_rm() {
    local opts=""
    if [[ "${1:-}" == -* ]]; then
        opts="$1"
        shift # shift left to let $1 become path
    fi

	if [[ $# -eq 0 ]]; then
        echo "❌ Error: path or file name not specified" >&2
        return 1
    fi

	for target in "$@"; do
		if [[ -z "${target// /}" ]]; then
			echo "❌ Error: path is empty, delete stopped" >&2
			continue
		fi

		case "$target" in
			"/"|"/usr"|"/usr/bin"|"/etc"|"/var"|"/Library"|"/System")
				echo "🚨 Warning: detected danger system path ($target), delete stopped!" >&2
				continue
				;;
		esac

		# check existence before delete
		if [[ -e "$target" || -L "$target" ]]; then
			#echo "🗑️ safe deleting $target"
            # auto detect if sudo is required and add it
            # if current is not root and not writable, add sudo
            if [[ $EUID -ne 0 && ! -w "$target" && ! -w "$(dirname "$target")" ]]; then
                sudo rm ${opts:-} "$target"
            else
                rm ${opts:-} "$target"
            fi
		#else
		#	echo "❌ path not exist, skip delete ($target)"
		fi
	done
}

function format00() {
	value=$1
	if [ $value -lt 10 ]; then
		value=0$(echo $value | tr -d '0')
		if [ "$value" == "0" ]; then
			value="00"
		fi
	fi
	echo $value
}

function version_number { # get number part of version for comparison
	version=$1
	version="v${version#*v}" # remove any words before v
	num=$(echo $version | tr '.' ' '| tr 'v' ' ')
	v1=$(echo $num | awk '{print $1}'); v2=$(echo $num | awk '{print $2}'); v3=$(echo $num | awk '{print $3}');
	echo $(format00 $v1)$(format00 $v2)$(format00 $v3)
}

function get_parameter() { # get parameter value from configuration file. the format is var=value or var= value or var = value
 	echo "$1" | grep "^$2=" | cut -d'=' -f2 | tr -d '"' | tr -d "'"
}

function read_config() { # read $val of $name in config_file
	local name="${1:-}" 
	local val=""
	if [[ -f "${config_file:-}" ]]; then
		while read -r "line" || [[ -n "$line" ]]; do
			if [[ "$line" == "$name ="* ]]; then
				val="${line#*'='}"
				break
			fi
		done < $config_file
	fi
	echo "${val:-}"
}

function write_config() {
    local name="${1:-}" 
    local val="${2:-}" 
    local file="${config_file:-}"
    if [[ ! -f "$file" ]]; then
        echo "$name = $val" >> "$file"
        return
    fi
    local name_loc
    name_loc=$(grep -n "^$name =" "$file" | cut -d: -f1 | head -n 1)
    if [[ -n "$name_loc" ]]; then
        sed -i '' "${name_loc}s@.*@${name} = ${val}@" "$file"
    else # not exist yest
        echo "$name = $val" >> "$file"
    fi
}

# Force-set path to include sbin
PATH=/usr/bin:/bin:/usr/sbin:/sbin

# Ensure Ctrl+C stops the entire script, not just the current command
trap 'exit 130' INT

# Set environment variables
binfolder=/usr/local/co.battery-optimizer
configfolder=$HOME/.battery
config_file=$configfolder/config_battery

echo -e "🔋 Starting battery update\n"

battery_local=$(cat $binfolder/battery 2>/dev/null)
battery_version_local=$(get_parameter "$battery_local" "BATTERY_CLI_VERSION")
visudo_version_local=$(get_parameter "$battery_local" "BATTERY_VISUDO_VERSION")

# Trigger reinstall for Terminal users to update from version v2.0.29 or earlier.
if [[ 10#$(version_number $battery_version_local) -lt 10#$(version_number "v2.0.30") ]]; then
	echo -e "💡 This battery update requires a full reinstall for security hardening...\n"
	curl -sS "https://raw.githubusercontent.com/js4jiang5/BatteryOptimizer_for_Mac/main/setup.sh" | bash
	$binfolder/battery maintain recover
	exit 0
fi

# Write battery function as executable
echo "[ 1 ] Downloading latest battery version"
tmp_battery=$(mktemp)
if ! curl -fsSL "https://raw.githubusercontent.com/js4jiang5/BatteryOptimizer_for_Mac/main/battery.sh" -o "$tmp_battery"; then
    echo "❌ Error: download fail"
    safe_rm -f "$tmp_battery"
    exit 1
fi
#safe_rm -f $tmp_battery; tmp_battery=$HOME/.battery-tmp/battery/battery.sh # this is for testing before upload

echo "[ 2 ] Writing script to $binfolder/battery"
sudo install -m 755 -o root -g wheel "$tmp_battery" "$binfolder/battery"

battery_new=$(cat $binfolder/battery 2>/dev/null)
battery_version_new=$(get_parameter "$battery_new" "BATTERY_CLI_VERSION")
visudo_version_new=$(get_parameter "$battery_new" "BATTERY_VISUDO_VERSION")

echo "[ 3 ] Setting up visudo declarations"
if [[ $visudo_version_new != $visudo_version_local ]]; then
	sudo $binfolder/battery visudo 1>/dev/null
fi

echo -e "\n🎉 Battery tool updated.\n"

# Restart battery maintain process
echo -e "Restarting battery maintain.\n"
write_config "informed_version" "$battery_version_new"

pkill -9 -f "$binfolder/battery.*"
$binfolder/battery maintain recover

empty="                                                                    "
button_empty="${empty} Buy me a coffee ☕ ${empty}😀"
button_empty_tw="${empty} 請我喝杯咖啡 ☕ ${empty}😀"
lang=$(defaults read -g AppleLocale)
language=$(read_config language)
if [[ $language ]]; then
	if [[ "$language" == "tw" ]]; then
		is_TW=true
	else
		is_TW=false
	fi
else
	if [[ $lang =~ "zh_TW" ]]; then
		is_TW=true
	else
		is_TW=false
	fi
fi
if $is_TW; then
	answer="$(osascript -e 'display dialog "'"已更新至 $battery_version_new \n\n如果您覺得這個小工具對您有幫助,點擊下方按鈕請我喝杯咖啡吧"'" buttons {"'"$button_empty_tw"'", "完成"} default button 2 with icon note with title "BatteryOptimizer for MAC"' -e 'button returned of result')"
else
	answer="$(osascript -e 'display dialog "'"Update to $battery_version_new completed. \n\nIf you feel this tool is helpful, click the button below and buy me a coffee."'" buttons {"'"$button_empty"'", "Finish"} default button 2 with icon note with title "BatteryOptimizer for MAC"' -e 'button returned of result')"
fi
if [[ $answer =~ "coffee" ]] || [[ $answer =~ "咖啡" ]]; then
    open https://buymeacoffee.com/js4jiang5
fi
