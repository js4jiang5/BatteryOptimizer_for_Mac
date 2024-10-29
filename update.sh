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
rm -rf $batteryfolder
mkdir -p $batteryfolder
curl -sS -o $batteryfolder/battery.sh https://raw.githubusercontent.com/js4jiang5/BatteryOptimizer_for_MAC/main/battery.sh

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
	sodo cp $batteryfolder/dist/battery_shutdown.plist $HOME/Library/LaunchAgents/battery_shutdown.plist
	launchctl enable "gui/$(id -u $USER)/com.battery_shutdown.app"
	launchctl unload "$HOME/Library/LaunchAgents/battery_shutdown.plist" 2> /dev/null
	launchctl load "$HOME/Library/LaunchAgents/battery_shutdown.plist" 2> /dev/null
fi

# Remove tempfiles
cd
rm -rf $tempfolder
echo "[ Final ] Removed temporary folder"

echo -e "\n🎉 Battery tool updated.\n"
