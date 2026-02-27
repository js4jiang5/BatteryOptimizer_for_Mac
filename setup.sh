#!/bin/bash

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
	if test -f $config_file; then
		config=$(cat $config_file 2>/dev/null)
		name_loc=$(echo "$config" | grep -n "$name" | cut -d: -f1)
		if [[ $name_loc ]]; then
			sed -i '' ''"$name_loc"'s/.*/'"$name"' = '"$val"'/' $config_file
			#sed -i '' "${name_loc}s@.*@${name} = ${val}@" "$config_file"
		else # not exist yet
			echo "$name = $val" >> $config_file
		fi
	fi
}

# User welcome message
echo -e "\n####################################################################"
echo '# 👋 Welcome, this is the setup script for the battery CLI tool.'
echo -e "# Note: this script will ask for your password once or multiple times."
echo -e "####################################################################\n\n"

PATH=/usr/bin:/bin:/usr/sbin:/sbin

# Set environment variables
tempfolder=~/.battery-tmp
binfolder=/usr/local/co.battery-optimizer
mkdir -p $tempfolder
function cleanup() { rm -rf "$tempfolder"; }
trap cleanup EXIT

# Set script value
calling_user=${1:-${SUDO_USER:-$USER}} # give SUDO_USER higher priority
if [[ "$calling_user" == "root" ]]; then
	echo "❌ Failed to determine unprivileged username"
	exit 1
fi
echo $calling_user
configfolder=/Users/$calling_user/.battery
config_file=$configfolder/config_battery
pidfile=$configfolder/battery.pid
logfile=$configfolder/battery.log
launch_agent_plist=/Users/$calling_user/Library/LaunchAgents/battery.plist
path_configfile=/etc/paths.d/battery-optimizer
sleepwatcher_log=$configfolder/sleepwatcher.log

# check CPU type
if [[ $(sysctl -n machdep.cpu.brand_string) == *"Intel"* ]]; then
    cpu_type="intel"
else
    cpu_type="apple"
fi

# Cleanup original battery and smc binary
sudo rm -f /usr/local/bin/battery
sudo rm -f /usr/local/bin/smc

# Ask for sudo once, in most systems this will cache the permissions for a bit
sudo echo "🔋 Starting battery installation"
echo "[ 1 ] Superuser permissions acquired."

# Note: github names zips by <reponame>-<branchname>.replace( '/', '-' )
echo "[ 2 ] Downloading latest version of battery CLI"
update_branch="main"
in_zip_folder_name="BatteryOptimizer_for_MAC-$update_branch"
batteryfolder="$tempfolder/battery"
rm -rf $batteryfolder
mkdir -p $batteryfolder
curl -sSL -o $batteryfolder/repo.zip "https://github.com/js4jiang5/BatteryOptimizer_for_Mac/archive/refs/heads/$update_branch.zip"
unzip -qq $batteryfolder/repo.zip -d $batteryfolder
cp -r $batteryfolder/$in_zip_folder_name/* $batteryfolder
curl -sSL -o $batteryfolder/dist/notification_permission.scpt "https://github.com/js4jiang5/BatteryOptimizer_for_Mac/raw/refs/heads/main/dist/notification_permission.scpt"
rm $batteryfolder/repo.zip

# Move built file to bin folder
echo "[ 3 ] Move smc to executable folder"
sudo rm -rf "$binfolder" # start with an empty $binfolder and ensure there is no symlink or file at the path
sudo install -d -m 755 -o root -g wheel "$binfolder"
if [[ $cpu_type == "apple" ]]; then
	sudo install -m 755 -o root -g wheel "$batteryfolder/dist/smc" "$binfolder/smc"
else
	sudo install -m 755 -o root -g wheel "$batteryfolder/dist/smc_intel" "$binfolder/smc"
fi

# Check if smc works
if [[ "$(smc 2>&1)" =~ [Bb]ad ]]; then 
    sudo install -m 755 -o root -g wheel "$batteryfolder/dist/smc_intel" "$binfolder/smc"
    if [[ "$(smc 2>&1)" =~ [Bb]ad ]]; then
        echo "❌ Error: BatteryOptimizer seems not compatible with your MAC yet"
        exit 1
    fi
fi

echo "[ 4 ] Writing script to $binfolder/battery and set PATH environment"
sudo install -m 755 -o root -g wheel "$batteryfolder/battery.sh" "$binfolder/battery"
if ! grep -qF "$binfolder" $path_configfile 2>/dev/null; then
	printf '%s\n' "$binfolder" | sudo tee "$path_configfile" >/dev/null
fi
sudo chown -h root:wheel $path_configfile
sudo chmod -h 644 $path_configfile
# Create a symlink for rare shells that do not initialize PATH from /etc/paths.d 
sudo mkdir -p /usr/local/bin
sudo ln -sf "$binfolder/battery" /usr/local/bin/battery
sudo chown -h root:wheel /usr/local/bin/battery
sudo ln -sf "$binfolder/smc" /usr/local/bin/smc
sudo chown -h root:wheel /usr/local/bin/smc

echo "[ 5 ] Setting correct file permissions for $calling_user"
# Set permissions for logfiles
mkdir -p $configfolder
sudo chown -hRP $calling_user $configfolder
sudo chmod -h 755 $configfolder

touch $logfile
sudo chown $calling_user $logfile
sudo chmod 644 $logfile

touch $pidfile
sudo chown $calling_user $pidfile
sudo chmod 644 $pidfile

touch $config_file
sudo chown $calling_user $config_file
sudo chmod 644 $config_file

# Fix permissions for 'create_daemon' action
echo "[ 6 ] Setup permissions for launch agent"
sudo chown -h $calling_user "$(dirname "$launch_agent_plist")"
sudo chmod -h 755 "$(dirname "$launch_agent_plist")"
sudo chown -hf $calling_user "$launch_agent_plist" 2>/dev/null

echo "[ 7 ] Setting up visudo declarations"
sudo $binfolder/battery visudo 1>/dev/null

# Run battery maintain with default percentage 80
#echo "[ 8 ] Set default battery maintain percentage to 80%, can be changed afterwards"

# Setup configuration file
version=$(echo $($binfolder/battery version))
touch $config_file
if [[ -z $(read_config calibrate_schedule) ]]; then write_config calibrate_method 1; fi
if [[ -z $(read_config calibrate_schedule) ]]; then write_config calibrate_schedule; fi
if [[ -z $(read_config calibrate_next) ]]; then write_config calibrate_next; fi
if [[ -z $(read_config informed_version) ]]; then write_config informed_version $version; fi
if [[ -z $(read_config language) ]]; then write_config language; fi
if [[ -z $(read_config maintain_percentage) ]]; then write_config maintain_percentage; fi
if [[ -z $(read_config daily_last) ]]; then write_config daily_last; fi
if [[ -z $(read_config webhookid) ]]; then write_config webhookid; fi

user_home="/Users/$calling_user"
if [[ $($binfolder/smc -k BCLM -r) == *"no data"* ]] && [[ $($binfolder/smc -k CHWA -r) != *"no data"* ]]; then # sleepwatcher only required for Apple CPU Macbook when CHWA is available
	echo "[ 8 ] Setup for power limit when Macs shutdown"
	sudo install -m 755 -o "$calling_user" "$batteryfolder/dist/.reboot" "$user_home/.reboot"
	sudo install -m 755 -o "$calling_user" "$batteryfolder/dist/.shutdown" "$user_home/.shutdown"
	sudo install -m 755 -o "$calling_user" "$batteryfolder/dist/shutdown.sh" "$binfolder/shutdown.sh"
	plist_path="$user_home/Library/LaunchAgents/battery_shutdown.plist"
	sudo install -m 644 -o "$calling_user" "$batteryfolder/dist/battery_shutdown.plist" "$plist_path"
	launchctl unload "$plist_path" 2>/dev/null
	launchctl load "$plist_path"

	# Install homebrew
	if [[ -z $(which brew 2>&1) ]]; then
		echo "[ 9 ] Install homebrew"
		curl -s https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | bash
		[[ -f /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
		if [[ -z $(which brew 2>&1) ]]; then
			echo "Error: brew installation fail"
			brew_installed=false
		else
			echo "brew installation completed"
			brew_installed=true
		fi
	else
		echo "[ 9 ] Homebrew installed"
		brew_installed=true
	fi

	# Install sleepwatcher
	if ! $brew_installed; then
		sleepwatcher_installed=false
	else
		if [[ -z $(which sleepwatcher 2>&1) ]]; then
			echo "[ 10 ] Install sleepwatcher"
			HOMEBREW_NO_INSTALL_FROM_API=1 brew reinstall sleepwatcher
			if [[ -z $(which sleepwatcher 2>&1) ]]; then
				echo "Error: sleepwatcher installation fail"
				sleepwatcher_installed=false
			else
				echo "sleepwatcher installation completed"
				sleepwatcher_installed=true
				brew services restart sleepwatcher
			fi
		else
			echo "[ 10 ] Sleepwatcher installed"
			sleepwatcher_installed=true
		fi
	fi

	if $sleepwatcher_installed; then
		echo "[ 11 ] Generate ~/.sleep and ~/.wakeup"
		sudo install -m 755 -o "$calling_user" "$batteryfolder/dist/.sleep" "$user_home/.sleep"
		sudo install -m 755 -o "$calling_user" "$batteryfolder/dist/.wakeup" "$user_home/.wakeup"
	fi
fi

lang=$(defaults read -g AppleLocale)
if [[ $lang =~ "zh_TW" ]]; then
	is_TW=true
else
	is_TW=false
fi

# Enable notification permission for Script Editor
open -a "Script Editor" $batteryfolder/dist/notification_permission.scpt

empty="                                                                    "
button_empty="${empty} Buy me a coffee ☕ ${empty}😀"
button_empty_tw="${empty} 請我喝杯咖啡 ☕ ${empty}😀"
notice="Installation completed.

Script Editor is opened. Please manually click ▶️ in Script Editor for permission of notification,
then setup your MAC system settings as follows
1.	System Settings > Battery > Battery Health > click the ⓘ icon > toggle off \\\"Optimize Battery Charging\\\"
2.	System Settings > Notifications > enable \\\"Allow notifications when mirroring or sharing\\\"
3.	System Settings > Notifications > Applications > Script Editor > Choose \\\"Alerts\\\"
If Script Editor is missing in the Notifications list, please reboot your Mac and check again.
"
notice_tw="安裝完成.

工序指令編寫程序已打開, 請手動點擊工序指令編寫程序中的 ▶️  以允許通知.
接著請調整 MAC 系統設定如下
1.	系統設定 > 電池 > 電池健康度 > 點擊 ⓘ 圖標 > 關閉 \\\"最佳化電池充電\\\"
2.	系統設定 > 通知 > 開啟 \\\"在鏡像輸出或共享顯示器時允許通知\\\"
3.	系統設定 > 通知 > 應用程式通知 > 工序指令編寫程式 > 選擇 \\\"提示\\\"
如果通知中沒有工序指令編寫程式，請重啟你的 Mac 再確認一次.
"

if $is_TW; then
	answer="$(osascript -e 'display dialog "'"$notice_tw \n如果您覺得這個小工具對您有幫助,點擊下方按鈕請我喝杯咖啡吧"'" buttons {"'"$button_empty_tw"'", "完成"} default button 2 with icon note with title "BatteryOptimizer for MAC"' -e 'button returned of result')"
else
	answer="$(osascript -e 'display dialog "'"$notice \nIf you feel this tool is helpful, you may click the button below and buy me a coffee."'" buttons {"'"$button_empty"'", "Finish"} default button 2 with icon note with title "BatteryOptimizer for MAC"' -e 'button returned of result')"
fi
if [[ $answer =~ "coffee" ]] || [[ $answer =~ "咖啡" ]]; then
    open https://buymeacoffee.com/js4jiang5
fi
