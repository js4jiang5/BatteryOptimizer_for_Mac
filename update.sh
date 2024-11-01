#!/bin/bash

# Force-set path to include sbin
PATH="$PATH:/usr/sbin"

# Set environment variables
tempfolder=~/.battery-tmp
binfolder=/usr/local/bin
batteryfolder="$tempfolder/battery"
mkdir -p $batteryfolder

echo -e "🔋 Starting battery update\n"

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

echo "[ 2 ] Writing script to $binfolder/battery"
cp $batteryfolder/battery.sh $binfolder/battery
chown $USER $binfolder/battery
chmod 755 $binfolder/battery
chmod u+x $binfolder/battery

if [[ $(smc -k BCLM -r) == *"no data"* ]]; then # power limit during shutdown only required for Apple CPU Macbook
	echo "[ 3 ] Setup for power limit when Macs shutdown"
	sudo cp $batteryfolder/dist/.reboot $HOME/.reboot
	sudo cp $batteryfolder/dist/.shutdown $HOME/.shutdown
	sudo cp $batteryfolder/dist/shutdown.sh $binfolder/shutdown.sh
	sudo cp $batteryfolder/dist/battery_shutdown.plist $HOME/Library/LaunchAgents/battery_shutdown.plist
	launchctl enable "gui/$(id -u $USER)/com.battery_shutdown.app"
	launchctl unload "$HOME/Library/LaunchAgents/battery_shutdown.plist" 2> /dev/null
	launchctl load "$HOME/Library/LaunchAgents/battery_shutdown.plist" 2> /dev/null
	sudo chown $USER $HOME/.reboot
	sudo chmod 755 $HOME/.reboot
	sudo chmod u+x $HOME/.reboot
	sudo chown $USER $HOME/.shutdown
	sudo chmod 755 $HOME/.shutdown
	sudo chmod u+x $HOME/.shutdown
	sudo chown $USER $binfolder/shutdown.sh
	sudo chmod 755 $binfolder/shutdown.sh
	sudo chmod u+x $binfolder/shutdown.sh
fi

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

# Remove tempfiles
cd
rm -rf $tempfolder
echo "[ Final ] Removed temporary folder"

echo -e "\n🎉 Battery tool updated.\n"

# Restart battery maintain process
echo -e "Restarting battery maintain.\n"
battery maintain stop >> /dev/null
sleep 1
battery maintain_synchronous recover >> $HOME/.battery/battery.log &
battery create_daemon >> /dev/null
battery schedule enable >> /dev/null
battery status 

echo -e "You're running the latest version now.\n"