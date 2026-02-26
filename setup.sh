#!/bin/bash

#
# SECURITY NOTES FOR MAINTAINERS:
#
# This app uses a visudo configuration that allows a background script running as
# an unprivileged user to execute battery management commands without requiring a
# user password. This requires careful installation and design to avoid potential
# privilege-escalation vulnerabilities.
#
# Rule of thumb:
# - Unprivileged users must not be able to modify, replace, or inject any code
#   that can be executed with root privileges.
#
# For this reason:
# - All battery-related binaries and scripts that can be executed via sudo,
#   including those that prompt for a user password, must be owned by root.
# - They must not be writable by group or others.
# - Their parent directories must also be owned by root and not be writable by
#   unprivileged users, to prevent the replacement of executables.
#
# See: https://github.com/actuallymentor/battery/issues/443
#

function write_config() { # write $val to $name in config_file
	name=$1
	val=$2
	if test -f "$config_file"; then
		config=$(cat "$config_file" 2>/dev/null)
		name_loc=$(echo "$config" | grep -n "$name" | cut -d: -f1)
		if [[ $name_loc ]]; then
			sed -i '' ''"$name_loc"'s/.*/'"$name"' = '"$val"'/' "$config_file"
		else # not exist yet
			echo "$name = $val" >> "$config_file"
		fi
	fi
}

# User welcome message
echo -e "\n####################################################################"
echo '# 👋 Welcome, this is the setup script for apple-juice.'
echo -e "# Note: this script will ask for your password once or multiple times."
echo -e "####################################################################\n\n"

# Set environment variables
tempfolder=$(mktemp -d "${TMPDIR:-/tmp}/apple-juice-install.XXXXXX")
trap 'rm -rf "$tempfolder"' EXIT
readonly EXPECTED_BINFOLDER="/usr/local/co.apple-juice"
binfolder="$EXPECTED_BINFOLDER"

# Set script value
calling_user=${1:-"$USER"}
configfolder=/Users/$calling_user/.apple-juice
config_file=$configfolder/config
pidfile=$configfolder/apple-juice.pid
logfile=$configfolder/apple-juice.log
sleepwatcher_log=$configfolder/sleepwatcher.log

# Ask for sudo once, in most systems this will cache the permissions for a bit
sudo echo "🔋 Starting apple-juice installation"
echo -e "[ 1 ] Superuser permissions acquired."

# Cleanup after older versions that installed to /usr/local/bin
sudo rm -f /usr/local/bin/apple-juice
sudo rm -f /usr/local/bin/smc
sudo rm -f /usr/local/bin/shutdown.sh

# check CPU type
if [[ $(sysctl -n machdep.cpu.brand_string) == *"Intel"* ]]; then
    cpu_type="intel"
else
    cpu_type="apple"
fi

# Note: github names zips by <reponame>-<branchname>.replace( '/', '-' )
update_branch="2.0.27"
in_zip_folder_name="apple-juice-$update_branch"
downloadfolder="$tempfolder/download"
echo "[ 2 ] Downloading latest version of apple-juice"
rm -rf "$downloadfolder"
mkdir -p "$downloadfolder"
curl -sSL -o "$downloadfolder/repo.zip" "https://github.com/MoonBoi9001/apple-juice/archive/refs/tags/v$update_branch.zip"
unzip -qq "$downloadfolder/repo.zip" -d "$downloadfolder"
cp -r "$downloadfolder/$in_zip_folder_name/"* "$downloadfolder"
curl -sSL -o "$downloadfolder/dist/notification_permission.scpt" "https://github.com/MoonBoi9001/apple-juice/raw/refs/heads/main/dist/notification_permission.scpt"
rm "$downloadfolder/repo.zip"

# Create dedicated bin folder with root ownership (security requirement)
# Safety check: verify binfolder hasn't been modified (defense against code injection)
echo "[ 3 ] Create root-owned executable folder"
if [[ "$binfolder" != "$EXPECTED_BINFOLDER" ]]; then
	echo "Error: invalid binfolder path"
	exit 1
fi
if [[ -d "$binfolder" ]]; then
	sudo rm -rf "$binfolder"
fi
sudo install -d -m 755 -o root -g wheel "$binfolder"
if [[ $cpu_type == "apple" ]]; then
	sudo cp "$downloadfolder/dist/smc" "$binfolder/smc"
else
	sudo cp "$downloadfolder/dist/smc_intel" "$binfolder/smc"
fi
sudo chown -h root:wheel "$binfolder/smc"
sudo chmod 755 "$binfolder/smc"
# Check if smc works (use explicit path since symlinks not created yet)
check_smc=$("$binfolder/smc" 2>&1)
if [[ $check_smc =~ " Bad " ]] || [[ $check_smc =~ " bad " ]] ; then # current is not a right version
	sudo cp "$downloadfolder/dist/smc_intel" "$binfolder/smc"
	sudo chown -h root:wheel "$binfolder/smc"
	sudo chmod 755 "$binfolder/smc"
	# check again
	check_smc=$($binfolder/smc 2>&1)
	if [[ $check_smc =~ " Bad " ]] || [[ $check_smc =~ " bad " ]] ; then # current is not a right version
		echo "Error: apple-juice seems not compatible with your MAC yet"
		exit 1
	fi
fi

echo "[ 4 ] Writing script to $binfolder/apple-juice for user $calling_user"
sudo cp "$downloadfolder/apple-juice.sh" "$binfolder/apple-juice"

echo "[ 5 ] Setting correct file permissions"
# Set permissions for apple-juice executables (must be root-owned for security)
sudo chown -h root:wheel "$binfolder/apple-juice"
sudo chmod 755 "$binfolder/apple-juice"

# Create symlinks in /usr/local/bin for PATH accessibility
sudo mkdir -p /usr/local/bin
sudo ln -sf "$binfolder/apple-juice" /usr/local/bin/apple-juice
sudo chown -h root:wheel /usr/local/bin/apple-juice
sudo ln -sf "$binfolder/smc" /usr/local/bin/smc
sudo chown -h root:wheel /usr/local/bin/smc

# Set permissions for logfiles
mkdir -p "$configfolder" || { echo "Failed to create config directory"; exit 1; }
sudo chown -hR "$calling_user" "$configfolder"

touch "$logfile"
sudo chown -h "$calling_user" "$logfile"
sudo chmod 755 "$logfile"

touch "$pidfile"
sudo chown -h "$calling_user" "$pidfile"
sudo chmod 755 "$pidfile"

echo "[ 6 ] Setting up visudo declarations"
sudo "$downloadfolder/apple-juice.sh" visudo "$USER"
sudo chown -hR "$calling_user" "$configfolder"

# Run apple-juice maintain with default percentage 80
echo "[ 7 ] Set default maintain percentage to 80%, can be changed afterwards"
# Setup configuration file
version=$(echo $(apple-juice version))
touch "$config_file"
write_config calibrate_method 1
write_config calibrate_schedule
write_config calibrate_next
write_config informed_version $version
write_config language
write_config maintain_percentage
write_config daily_last
write_config clamshell_discharge
write_config webhookid

$binfolder/apple-juice maintain 80 >/dev/null &

if [[ $(smc -k BCLM -r) == *"no data"* ]] && [[ $(smc -k CHWA -r) != *"no data"* ]]; then # sleepwatcher only required for Apple CPU Macbook when CHWA is available
	echo "[ 8 ] Setup for power limit when Macs shutdown"
	sudo cp $downloadfolder/dist/.reboot $HOME/.reboot
	sudo cp $downloadfolder/dist/.shutdown $HOME/.shutdown
	sudo cp $downloadfolder/dist/shutdown.sh $binfolder/shutdown.sh
	sudo cp $downloadfolder/dist/apple-juice_shutdown.plist $HOME/Library/LaunchAgents/apple-juice_shutdown.plist
	launchctl enable "gui/$(id -u $USER)/com.apple-juice.shutdown"
	launchctl unload "$HOME/Library/LaunchAgents/apple-juice_shutdown.plist" 2> /dev/null
	launchctl load "$HOME/Library/LaunchAgents/apple-juice_shutdown.plist" 2> /dev/null
	sudo chown -hR $calling_user $HOME/.reboot
	sudo chmod 755 $HOME/.reboot
	sudo chmod +x $HOME/.reboot
	sudo chown -hR $calling_user $HOME/.shutdown
	sudo chmod 755 $HOME/.shutdown
	sudo chmod +x $HOME/.shutdown
	sudo chown -h root:wheel $binfolder/shutdown.sh
	sudo chmod 755 $binfolder/shutdown.sh
	# Create symlink for shutdown.sh (only when the file is installed)
	sudo ln -sf "$binfolder/shutdown.sh" /usr/local/bin/shutdown.sh
	sudo chown -h root:wheel /usr/local/bin/shutdown.sh

	# Install homebrew
	if [[ -z $(which brew 2>&1) ]]; then
		echo "[ 9 ] Install homebrew"
		curl -s https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | bash
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
		sudo cp $downloadfolder/dist/.sleep $HOME/.sleep
		sudo cp $downloadfolder/dist/.wakeup $HOME/.wakeup
		sudo chown -hR $calling_user $HOME/.sleep
		sudo chmod 755 $HOME/.sleep
		sudo chmod +x $HOME/.sleep
		sudo chown -hR $calling_user $HOME/.wakeup
		sudo chmod 755 $HOME/.wakeup
		sudo chmod +x $HOME/.wakeup
	fi
fi

lang=$(defaults read -g AppleLocale)
if [[ $lang =~ "zh_TW" ]]; then
	is_TW=true
else
	is_TW=false
fi

# Enable notification permission for Script Editor
open -a "Script Editor" $downloadfolder/dist/notification_permission.scpt

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
	osascript -e 'display dialog "'"$notice_tw"'" buttons {"完成"} default button 1 with icon note with title "apple-juice"'
else
	osascript -e 'display dialog "'"$notice"'" buttons {"Done"} default button 1 with icon note with title "apple-juice"'
fi

# Remove tempfiles
#cd ../..
#echo "[ Final ] Removing temp folder $tempfolder"
# Note: tempfolder is cleaned up by trap on EXIT

#echo -e "\n🎉 apple-juice installed. Type \"apple-juice help\" for instructions.\n"