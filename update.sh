#!/bin/bash

function valid_day() {
	if ! [[ "$1" =~ ^[0-9]+$ ]] || [[ "$1" -lt 1 ]] || [[ "$1" -gt 28 ]]; then
		return 1
	else
		return 0
	fi
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
    var_loc=$(echo $(echo "$1" | tr " " "\n" | grep -n "$2" | cut -d: -f1) | awk '{print $1}')
    if [ -z $var_loc ]; then
        echo
    else
        echo $1 | awk '{print $"'"$((var_loc))"'"}' | tr '=' ' ' | awk '{print $2}'
    fi
}

function read_config() { # read $val of $name in config_file
	name=$1
	val=
	if test -f $config_file; then
		while read -r "line" || [[ -n "$line" ]]; do
			if [[ "$line" == "$name = "* ]]; then
				val=${line#*'= '}
				break
			fi
		done < $config_file
	fi
	echo $val
}

function write_config() { # write $val to $name in config_file
	name=$1
	val=$2
	if test -f "$config_file"; then
		config=$(cat "$config_file" 2>/dev/null)
		name_loc=$(echo "$config" | grep -n "$name" | cut -d: -f1)
		if [[ $name_loc ]]; then
			# Escape sed special characters in both name and value
			name_escaped=$(printf '%s\n' "$name" | sed 's/[&/\]/\\&/g')
			val_escaped=$(printf '%s\n' "$val" | sed 's/[&/\]/\\&/g')
			sed -i '' "${name_loc}s/.*/${name_escaped} = ${val_escaped}/" "$config_file"
		else # not exist yet
			echo "$name = $val" >> "$config_file"
		fi
	fi
}

# Force-set path to include sbin
PATH="/usr/local/co.apple-juice:$PATH:/usr/sbin"

# Set environment variables
tempfolder=$(mktemp -d "${TMPDIR:-/tmp}/apple-juice-update.XXXXXX")
trap 'rm -rf "$tempfolder"' EXIT
binfolder=/usr/local/co.apple-juice
configfolder=$HOME/.apple-juice
config_file=$configfolder/config
downloadfolder="$tempfolder/download"
language_file=$configfolder/language.code
github_link="https://raw.githubusercontent.com/MoonBoi9001/apple-juice/main"
mkdir -p "$downloadfolder" || { echo "Failed to create temp directory"; exit 1; }

lang=$(defaults read -g AppleLocale)
if test -f $language_file; then
	language=$(cat "$language_file" 2>/dev/null)
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

echo -e "🔋 Starting apple-juice update\n"

# Cleanup old installations from /usr/local/bin (migration from vulnerable versions)
# Only remove if they are regular files (not symlinks to our new location)
if [[ -f /usr/local/bin/apple-juice && ! -L /usr/local/bin/apple-juice ]]; then
	sudo rm -f /usr/local/bin/apple-juice
fi
if [[ -f /usr/local/bin/smc && ! -L /usr/local/bin/smc ]]; then
	sudo rm -f /usr/local/bin/smc
fi
if [[ -f /usr/local/bin/shutdown.sh && ! -L /usr/local/bin/shutdown.sh ]]; then
	sudo rm -f /usr/local/bin/shutdown.sh
fi

# Ensure binfolder exists with correct ownership (for migration from old versions)
if [[ ! -d "$binfolder" ]]; then
	sudo install -d -m 755 -o root -g wheel "$binfolder"
fi

script_local=$(echo $(cat $binfolder/apple-juice 2>/dev/null))
version_local=$(echo $(get_parameter "$script_local" "BATTERY_CLI_VERSION") | tr -d \")
visudo_version_local=$(echo $(get_parameter "$script_local" "BATTERY_VISUDO_VERSION") | tr -d \")

# Download and install latest version
echo "[ 1 ] Downloading latest apple-juice version"
update_branch="main"
in_zip_folder_name="apple-juice-$update_branch"
downloadfolder="$tempfolder/download"
rm -rf $downloadfolder
mkdir -p $downloadfolder
curl -sSL -o $downloadfolder/repo.zip "https://github.com/MoonBoi9001/apple-juice/archive/refs/heads/$update_branch.zip"
unzip -qq $downloadfolder/repo.zip -d $downloadfolder
cp -r $downloadfolder/$in_zip_folder_name/* $downloadfolder
rm $downloadfolder/repo.zip

# update smc for intel macbook if version is less than v2.0.14
if [[ 10#$(version_number $version_local) -lt 10#$(version_number "v2.0.14") ]]; then
	if [[ $(sysctl -n machdep.cpu.brand_string) == *"Intel"* ]]; then # check CPU type
		if [[ ! -d "$binfolder" ]]; then
			sudo install -d -m 755 -o root -g wheel "$binfolder"
		fi
		sudo cp $downloadfolder/dist/smc_intel $binfolder/smc
		sudo chown -h root:wheel $binfolder/smc
		sudo chmod 755 $binfolder/smc
	fi
fi

echo "[ 2 ] Writing script to $binfolder/apple-juice"
sudo cp $downloadfolder/apple-juice.sh $binfolder/apple-juice
sudo chown -h root:wheel $binfolder/apple-juice
sudo chmod 755 $binfolder/apple-juice

# Create/update symlinks in /usr/local/bin for PATH accessibility
sudo mkdir -p /usr/local/bin
sudo ln -sf "$binfolder/apple-juice" /usr/local/bin/apple-juice
sudo chown -h root:wheel /usr/local/bin/apple-juice
sudo ln -sf "$binfolder/smc" /usr/local/bin/smc
sudo chown -h root:wheel /usr/local/bin/smc
if [[ -f "$binfolder/shutdown.sh" ]]; then
	sudo ln -sf "$binfolder/shutdown.sh" /usr/local/bin/shutdown.sh
	sudo chown -h root:wheel /usr/local/bin/shutdown.sh
fi

script_new=$(echo $(cat $binfolder/apple-juice 2>/dev/null))
version_new=$(echo $(get_parameter "$script_new" "BATTERY_CLI_VERSION") | tr -d \")
visudo_version_new=$(echo $(get_parameter "$script_new" "BATTERY_VISUDO_VERSION") | tr -d \")

echo "[ 3 ] Setting up visudo declarations"
if [[ $visudo_version_new != $visudo_version_local ]]; then
	sudo $binfolder/apple-juice visudo $USER
fi

echo "[ 4 ] Setting up configuration"
if ! test -f $config_file; then # config file not exist
	touch $config_file
fi
if [[ -z $(read_config calibrate_method) ]]; then write_config calibrate_method "$(cat "$configfolder/calibrate_method" 2>/dev/null)"; rm -rf "$configfolder/calibrate_method"; fi
if [[ -z $(read_config calibrate_schedule) ]]; then write_config calibrate_schedule "$(cat "$configfolder/calibrate_schedule" 2>/dev/null)"; rm -rf "$configfolder/calibrate_schedule"; fi
if [[ -z $(read_config informed_version) ]]; then write_config informed_version "$(cat "$configfolder/informed.version" 2>/dev/null)"; rm -rf "$configfolder/informed.version"; fi
if [[ -z $(read_config language) ]]; then write_config language "$(cat "$configfolder/language.code" 2>/dev/null)"; rm -rf "$configfolder/language.code"; fi
if [[ -z $(read_config maintain_percentage) ]]; then write_config maintain_percentage "$(cat "$configfolder/maintain.percentage" 2>/dev/null)"; rm -rf "$configfolder/maintain.percentage"; fi
if [[ -z $(read_config clamshell_discharge) ]]; then write_config clamshell_discharge "$(cat "$configfolder/clamshell_discharge" 2>/dev/null)"; rm -rf "$configfolder/clamshell_discharge"; fi
if [[ -z $(read_config webhookid) ]]; then write_config webhookid "$(cat "$configfolder/ha_webhook.id" 2>/dev/null)"; rm -rf "$configfolder/ha_webhook.id"; fi
if test -f "$configfolder/sig"; then rm -rf "$configfolder/sig"; fi
if test -f "$configfolder/state"; then rm -rf "$configfolder/state"; fi

# Remove tempfiles
cd
# Note: tempfolder is cleaned up by trap on EXIT
echo "[ Final ] Removed temporary folder"

echo -e "\n🎉 apple-juice updated.\n"

# Restart apple-juice maintain process
echo -e "Restarting apple-juice maintain.\n"
write_config informed_version "$version_new"

# Try graceful shutdown first, then force kill (Issue #28)
pkill -f "$binfolder/apple-juice " 2>/dev/null
sleep 1
pkill -9 -f "$binfolder/apple-juice " 2>/dev/null
apple-juice maintain recover

if $is_TW; then
	osascript -e 'display dialog "'"已更新至 $version_new"'" buttons {"完成"} default button 1 with icon note with title "apple-juice"'
else
	osascript -e 'display dialog "'"Updated to $version_new"'" buttons {"Done"} default button 1 with icon note with title "apple-juice"'
fi
