#!/bin/bash

function valid_day() {
	if ! [[ "$1" =~ ^[0-9]+$ ]] || [[ "$1" -lt 1 ]] || [[ "$1" -gt 28 ]]; then
		return 1
	else
		return 0
	fi
}

# Force-set path to include sbin
PATH="$PATH:/usr/sbin"

# Set environment variables
tempfolder=~/.battery-tmp
binfolder=/usr/local/bin
configfolder=$HOME/.battery
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

# correct the schedule plist if it is incorrect due to the bug
schedule_tracker_file="$configfolder/calibrate_schedule"
enable_exist="$(launchctl print gui/$(id -u $USER) | grep "=> enabled")"
if [[ $enable_exist ]]; then # new version that replace => false with => enabled
    schedule_enabled="$(launchctl print gui/$(id -u $USER) | grep enabled | grep "com.battery_schedule.app")"
else # old version that use => false
    schedule_enabled="$(launchctl print gui/$(id -u $USER) | grep "=> false" | grep "com.battery_schedule.app")"
    schedule_enabled=${schedule_enabled/false/enabled}
fi

if test -f $schedule_tracker_file && [[ $schedule_enabled =~ "enabled" ]]; then
	schedule=$(cat $schedule_tracker_file 2>/dev/null)

	time=$(echo ${schedule#*" at "} | awk '{print $1}')
	hour=${time%:*}
	minute=${time#*:}

	if [[ $schedule == *"every"* ]] && [[ $schedule == *"Week"* ]] && [[ $schedule == *"Year"* ]]; then
        weekday=$(echo $schedule | awk '{print $4}')
        week_period=$(echo $schedule | awk '{print $6}')
        week=$(echo $schedule | awk '{print $13}')
        year=$(echo $schedule | awk '{print $16}')
        if  [[ $schedule =~ "MON" ]]; then weekday=1; elif
            [[ $schedule =~ "TUE" ]]; then weekday=2; elif
            [[ $schedule =~ "WED" ]]; then weekday=3; elif
            [[ $schedule =~ "THU" ]]; then weekday=4; elif
            [[ $schedule =~ "FRI" ]]; then weekday=5; elif
            [[ $schedule =~ "SAT" ]]; then weekday=6; elif
            [[ $schedule =~ "SUN" ]]; then weekday=0;
        fi
        schedule="weekday $weekday week_period $week_period hour $hour minute $minute"
    else
		n_days=0
		days[0]=
		days[1]=
		days[2]=
		days[3]=
        schedule=${schedule/weekday}
		day_loc=$(echo "$schedule" | tr " " "\n" | grep -n "day" | cut -d: -f1)
		if [[ $day_loc ]]; then
			for i_day in {1..4}; do
				value=$(echo $schedule | awk '{print $"'"$((day_loc+i_day))"'"}')
				if valid_day $value; then
					days[$n_days]=$value
					n_days=$(($n_days+1))
				else
					break
				fi
			done 
		fi

		month_period_loc=$(echo "$schedule" | tr " " "\n" | grep -n "every" | cut -d: -f1)

		if [[ $month_period_loc ]]; then
			month_period=$(echo $schedule | awk '{print $"'"$((month_period_loc+1))"'"}');
            schedule="day ${days[*]} month_period $month_period hour $hour minute $minute"
		else # calibrate every month case
			schedule="day ${days[*]} $month_period hour $hour minute $minute"
		fi
    fi
    battery schedule $schedule
fi

echo "[ 3 ] Setting up visudo declarations"
sudo $batteryfolder/battery.sh visudo $USER

# Remove tempfiles
cd
rm -rf $tempfolder
echo "[ Final ] Removed temporary folder"

echo -e "\n🎉 Battery tool updated.\n"

# Restart battery maintain process
echo -e "Restarting battery maintain.\n"
version=$(echo $(battery version)) #update informed version first
informed_version_file=$configfolder/informed.version
echo "$version" > $informed_version_file

battery maintain stop >> /dev/null
sleep 1
battery maintain_synchronous recover >> $HOME/.battery/battery.log &
battery create_daemon >> /dev/null
battery schedule enable >> /dev/null
battery status 

echo -e "You're running the latest version $version now.\n"