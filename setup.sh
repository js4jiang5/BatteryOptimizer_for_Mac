#!/bin/bash

function write_config() { # write $val to $name in config_file
	name=$1
	val=$2
	if test -f $config_file; then
		config=$(cat $config_file 2>/dev/null)
		name_loc=$(echo "$config" | grep -n "$name" | cut -d: -f1)
		if [[ $name_loc ]]; then
			sed -i '' ''"$name_loc"'s/.*/'"$name"' = '"$val"'/' $config_file
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

# Set environment variables
tempfolder=~/.battery-tmp
binfolder=/usr/local/bin
mkdir -p $tempfolder

# Set script value
calling_user=${1:-"$USER"}
configfolder=/Users/$calling_user/.battery
config_file=$configfolder/config_battery
pidfile=$configfolder/battery.pid
logfile=$configfolder/battery.log
sleepwatcher_log=$configfolder/sleepwatcher.log

# Ask for sudo once, in most systems this will cache the permissions for a bit
sudo echo "🔋 Starting battery installation"
echo -e "[ 1 ] Superuser permissions acquired."

# check CPU type
if [[ $(sysctl -n machdep.cpu.brand_string) == *"Intel"* ]]; then
    cpu_type="intel"
else
    cpu_type="apple"
fi

# Note: github names zips by <reponame>-<branchname>.replace( '/', '-' )
update_branch="2.0.27"
in_zip_folder_name="BatteryOptimizer_for_MAC-$update_branch"
batteryfolder="$tempfolder/battery"
echo "[ 2 ] Downloading latest version of battery CLI"
rm -rf $batteryfolder
mkdir -p $batteryfolder
curl -sSL -o $batteryfolder/repo.zip "https://github.com/js4jiang5/BatteryOptimizer_for_MAC/archive/refs/tags/v$update_branch.zip"
unzip -qq $batteryfolder/repo.zip -d $batteryfolder
cp -r $batteryfolder/$in_zip_folder_name/* $batteryfolder
curl -sSL -o $batteryfolder/dist/notification_permission.scpt "https://github.com/js4jiang5/BatteryOptimizer_for_Mac/raw/refs/heads/main/dist/notification_permission.scpt"
rm $batteryfolder/repo.zip

# Move built file to bin folder
echo "[ 3 ] Move smc to executable folder"
sudo mkdir -p $binfolder
if [[ $cpu_type == "apple" ]]; then
	sudo cp $batteryfolder/dist/smc $binfolder/smc
else
	sudo cp $batteryfolder/dist/smc_intel $binfolder/smc
fi
sudo chown $calling_user $binfolder/smc
sudo chmod 755 $binfolder/smc
sudo chmod +x $binfolder/smc
# Check if smc works
check_smc=$(smc 2>&1)
if [[ $check_smc =~ " Bad " ]] || [[ $check_smc =~ " bad " ]] ; then # current is not a right version
	sudo cp $batteryfolder/dist/smc_intel $binfolder/smc
	sudo chown $USER $binfolder/smc
	sudo chmod 755 $binfolder/smc
	sudo chmod +x $binfolder/smc
	# check again
	check_smc=$(smc 2>&1)
	if [[ $check_smc =~ " Bad " ]] || [[ $check_smc =~ " bad " ]] ; then # current is not a right version
		echo "Error: BatteryOptimizer seems not compatible with your MAC yet"
		exit
	fi
fi

echo "[ 4 ] Writing script to $binfolder/battery for user $calling_user"
sudo cp $batteryfolder/battery.sh $binfolder/battery

echo "[ 5 ] Setting correct file permissions for $calling_user"
# Set permissions for battery executables
sudo chown -R $calling_user $binfolder/battery
sudo chmod 755 $binfolder/battery
sudo chmod +x $binfolder/battery

# Set permissions for logfiles
mkdir -p $configfolder
sudo chown -R $calling_user $configfolder

touch $logfile
sudo chown $calling_user $logfile
sudo chmod 755 $logfile

touch $pidfile
sudo chown $calling_user $pidfile
sudo chmod 755 $pidfile

sudo chown $calling_user $binfolder/battery

echo "[ 6 ] Setting up visudo declarations"
sudo $batteryfolder/battery.sh visudo $USER
sudo chown -R $calling_user $configfolder

# Run battery maintain with default percentage 80
echo "[ 7 ] Set default battery maintain percentage to 80%, can be changed afterwards"
# Install CLI i18n catalog files for the installed /usr/local/bin/battery script
mkdir -p "$configfolder/i18n"
cp -Rf "$batteryfolder/i18n/." "$configfolder/i18n/"
sudo chown -R "$calling_user" "$configfolder/i18n"

# Setup configuration file
version=$(echo $(battery version))
touch $config_file
write_config calibrate_method 1
write_config calibrate_schedule
write_config calibrate_next
write_config informed_version $version
write_config language
write_config maintain_percentage
write_config daily_last
write_config clamshell_discharge
write_config webhookid

$binfolder/battery maintain 80 >/dev/null &

if [[ $(smc -k BCLM -r) == *"no data"* ]] && [[ $(smc -k CHWA -r) != *"no data"* ]]; then # sleepwatcher only required for Apple CPU Macbook when CHWA is available
	echo "[ 8 ] Setup for power limit when Macs shutdown"
	sudo cp $batteryfolder/dist/.reboot $HOME/.reboot
	sudo cp $batteryfolder/dist/.shutdown $HOME/.shutdown
	sudo cp $batteryfolder/dist/shutdown.sh $binfolder/shutdown.sh
	sudo cp $batteryfolder/dist/battery_shutdown.plist $HOME/Library/LaunchAgents/battery_shutdown.plist
	launchctl enable "gui/$(id -u $USER)/com.battery_shutdown.app"
	launchctl unload "$HOME/Library/LaunchAgents/battery_shutdown.plist" 2> /dev/null
	launchctl load "$HOME/Library/LaunchAgents/battery_shutdown.plist" 2> /dev/null
	sudo chown -R $calling_user $HOME/.reboot
	sudo chmod 755 $HOME/.reboot
	sudo chmod +x $HOME/.reboot
	sudo chown -R $calling_user $HOME/.shutdown
	sudo chmod 755 $HOME/.shutdown
	sudo chmod +x $HOME/.shutdown
	sudo chown -R $calling_user $binfolder/shutdown.sh
	sudo chmod 755 $binfolder/shutdown.sh
	sudo chmod +x $binfolder/shutdown.sh

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
		sudo cp $batteryfolder/dist/.sleep $HOME/.sleep
		sudo cp $batteryfolder/dist/.wakeup $HOME/.wakeup
		sudo chown -R $calling_user $HOME/.sleep
		sudo chmod 755 $HOME/.sleep
		sudo chmod +x $HOME/.sleep
		sudo chown -R $calling_user $HOME/.wakeup
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
	#osascript <<- EOF
	#	display notification "安裝完成" with title "BatteryOptimizer" sound name "Blow"
	#	delay .5
	#EOF
	answer="$(osascript -e 'display dialog "'"$notice_tw \n如果您覺得這個小工具對您有幫助,點擊下方按鈕請我喝杯咖啡吧"'" buttons {"'"$button_empty_tw"'", "完成"} default button 2 with icon note with title "BatteryOptimizer for MAC"' -e 'button returned of result')"
else
	#osascript <<- EOF
	#	display notification "Installation completed" with title "BatteryOptimizer" sound name "Blow"
	#	delay .5
	#EOF
	answer="$(osascript -e 'display dialog "'"$notice \nIf you feel this tool is helpful, you may click the button below and buy me a coffee."'" buttons {"'"$button_empty"'", "Finish"} default button 2 with icon note with title "BatteryOptimizer for MAC"' -e 'button returned of result')"
fi
if [[ $answer =~ "coffee" ]] || [[ $answer =~ "咖啡" ]]; then
    open https://buymeacoffee.com/js4jiang5
fi

# Remove tempfiles
#cd ../..
#echo "[ Final ] Removing temp folder $tempfolder"
rm -rf $tempfolder

#echo -e "\n🎉 Battery tool installed. Type \"battery help\" for instructions.\n"
