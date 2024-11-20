#!/bin/bash

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
update_branch="pre-release"
in_zip_folder_name="BatteryOptimizer_for_MAC-$update_branch"
batteryfolder="$tempfolder/battery"
echo "[ 2 ] Downloading latest version of battery CLI"
rm -rf $batteryfolder
mkdir -p $batteryfolder
curl -sSL -o $batteryfolder/repo.zip "https://github.com/js4jiang5/BatteryOptimizer_for_MAC/archive/refs/heads/$update_branch.zip"
unzip -qq $batteryfolder/repo.zip -d $batteryfolder
cp -r $batteryfolder/$in_zip_folder_name/* $batteryfolder
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
$binfolder/battery maintain 80 >/dev/null &

if [[ $(smc -k BCLM -r) == *"no data"* ]]; then # sleepwatcher only required for Apple CPU Macbook
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

#		sleep_file=$HOME/.sleep
#		wakeup_file=$HOME/.wakeup
#		# .sleep
#		sleep_code="#!/bin/bash
#if [[ \$(smc -k CHWA -r) == *\"no data\"* ]]; then
#	chwa_has_data=false
#else
#	chwa_has_data=true
#fi

#if \$chwa_has_data; then
#	sudo smc -k CHWA -w 01 # limit at 80% before sleep
#	echo \"\`date +%Y/%m/%d-%T\` sleep\"  >> $sleepwatcher_log
#fi"
#		echo "$sleep_code" > "$sleep_file"
#		chmod +x "$sleep_file"

#		# .wakeup
#		wakeup_code="#!/bin/bash
#if [[ \$(smc -k CHWA -r) == *\"no data\"* ]]; then
#	chwa_has_data=false
#else
#	chwa_has_data=true
#fi

#if \$chwa_has_data; then
#	sudo smc -k CHWA -w 00 # allow full charge to 100%
#	echo \"\`date +%Y/%m/%d-%T\` wakeup\"  >> $sleepwatcher_log
#fi"
#		echo "$wakeup_code" > "$wakeup_file"
#		chmod +x "$wakeup_file"
	fi
fi

# Remove tempfiles
cd ../..
echo "[ Final ] Removing temp folder $tempfolder"
rm -rf $tempfolder

echo -e "\n🎉 Battery tool installed. Type \"battery help\" for instructions.\n"