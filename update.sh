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
			if [[ "$line" =~  "$name = " ]]; then
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
PATH="$PATH:/usr/sbin"

# Set environment variables
tempfolder=~/.battery-tmp
binfolder=/usr/local/bin
configfolder=$HOME/.battery
config_file=$configfolder/config_battery
batteryfolder="$tempfolder/battery"
language_file=$configfolder/language.code
github_link="https://raw.githubusercontent.com/js4jiang5/BatteryOptimizer_for_MAC/main"
mkdir -p $batteryfolder

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

echo -e "🔋 Starting battery update\n"

battery_local=$(echo $(cat $binfolder/battery 2>/dev/null))
battery_version_local=$(echo $(get_parameter "$battery_local" "BATTERY_CLI_VERSION") | tr -d \")
visudo_version_local=$(echo $(get_parameter "$battery_local" "BATTERY_VISUDO_VERSION") | tr -d \")

# Write battery function as executable
echo "[ 1 ] Downloading latest battery version"
update_branch="main"
in_zip_folder_name="BatteryOptimizer_for_MAC-$update_branch"
batteryfolder="$tempfolder/battery"
rm -rf $batteryfolder
mkdir -p $batteryfolder
curl -sSL -o $batteryfolder/repo.zip "https://github.com/js4jiang5/BatteryOptimizer_for_MAC/archive/refs/heads/$update_branch.zip"
unzip -qq $batteryfolder/repo.zip -d $batteryfolder
cp -r $batteryfolder/$in_zip_folder_name/* $batteryfolder
rm $batteryfolder/repo.zip

# update smc for intel macbook if version is less than v2.0.14
if [[ 10#$(version_number $battery_version_local) -lt 10#$(version_number "v2.0.14") ]]; then
	if [[ $(sysctl -n machdep.cpu.brand_string) == *"Intel"* ]]; then # check CPU type
		sudo mkdir -p $binfolder
		sudo cp $batteryfolder/dist/smc_intel $binfolder/smc
		sudo chown $USER $binfolder/smc
		sudo chmod 755 $binfolder/smc
		sudo chmod +x $binfolder/smc
	fi
fi

echo "[ 2 ] Writing script to $binfolder/battery"
cp $batteryfolder/battery.sh $binfolder/battery
chown $USER $binfolder/battery
chmod 755 $binfolder/battery
chmod u+x $binfolder/battery

battery_new=$(echo $(cat $binfolder/battery 2>/dev/null))
battery_version_new=$(echo $(get_parameter "$battery_new" "BATTERY_CLI_VERSION") | tr -d \")
visudo_version_new=$(echo $(get_parameter "$battery_new" "BATTERY_VISUDO_VERSION") | tr -d \")

echo "[ 3 ] Setting up visudo declarations"
if [[ $visudo_version_new != $visudo_version_local ]]; then
	sudo $binfolder/battery visudo $USER
fi

echo "[ 4 ] Setting up battery configuration"
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
rm -rf $tempfolder
echo "[ Final ] Removed temporary folder"

echo -e "\n🎉 Battery tool updated.\n"

# Restart battery maintain process
echo -e "Restarting battery maintain.\n"
write_config informed_version "$battery_version_new"

# Try graceful shutdown first, then force kill (Issue #28)
pkill -f "$binfolder/battery " 2>/dev/null
sleep 1
pkill -9 -f "$binfolder/battery " 2>/dev/null
battery maintain recover

empty="                                                                    "
button_empty="${empty} Buy me a coffee ☕ ${empty}😀"
button_empty_tw="${empty} 請我喝杯咖啡 ☕ ${empty}😀"
if $is_TW; then
	answer="$(osascript -e 'display dialog "'"已更新至 $battery_version_new \n\n如果您覺得這個小工具對您有幫助,點擊下方按鈕請我喝杯咖啡吧"'" buttons {"'"$button_empty_tw"'", "完成"} default button 2 with icon note with title "BatteryOptimizer for MAC"' -e 'button returned of result')"
else
	answer="$(osascript -e 'display dialog "'"Update to $battery_version_new completed. \n\nIf you feel this tool is helpful, click the button below and buy me a coffee."'" buttons {"'"$button_empty"'", "Finish"} default button 2 with icon note with title "BatteryOptimizer for MAC"' -e 'button returned of result')"
fi
if [[ $answer =~ "coffee" ]] || [[ $answer =~ "咖啡" ]]; then
    open https://buymeacoffee.com/js4jiang5
fi
