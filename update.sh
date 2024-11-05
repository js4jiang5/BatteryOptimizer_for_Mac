#!/bin/bash

function valid_day() {
	if ! [[ "$1" =~ ^[0-9]+$ ]] || [[ "$1" -lt 1 ]] || [[ "$1" -gt 28 ]]; then
		return 1
	else
		return 0
	fi
}

function get_changelog { # get the latest changelog
	if [[ -z $1 ]]; then
		changelog=$(curl -sSL "$github_link/CHANGELOG" | sed s:\":'\\"':g 2>&1)
	else
		changelog=$(curl -sSL "$github_link/$1" | sed s:\":'\\"':g 2>&1)
	fi

    n_lines=0
	while read -r "line"; do
		line="v${line#*v}" # remove any words before v
		num=$(echo $line | tr '.' ' '| tr 'v' ' ') # extract number parts
		is_version=true
		n_num=0
		for var in $num; do
			if ! [[ "$var" =~ ^[0-9]+$ ]]; then
				is_version=false
				break
			else
				n_num=$((n_num+1))
			fi
		done
		if [[ $line =~ "." ]] && [[ $line =~ "v" ]] && $is_version && [[ $n_num == 3 ]] && [[ $n_lines > 0 ]]; then
			is_version=true
		else
			is_version=false
		fi

        if $is_version; then # found the start of 2nd version
			break
		fi
        n_lines=$((n_lines+1))
    done <<< "$changelog"
    echo -e "$changelog" | awk 'NR>=2 && NR<='$n_lines
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

# Force-set path to include sbin
PATH="$PATH:/usr/sbin"

# Set environment variables
tempfolder=~/.battery-tmp
binfolder=/usr/local/bin
configfolder=$HOME/.battery
batteryfolder="$tempfolder/battery"
language_file=$configfolder/language.code
github_link="https://raw.githubusercontent.com/js4jiang5/BatteryOptimizer_for_MAC/refs/heads/intel"
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
is_TW=false

echo -e "🔋 Starting battery update\n"

version_local=$(echo $(battery version)) #update informed version first
# Write battery function as executable
echo "[ 1 ] Downloading latest battery version"
update_branch="intel"
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

#if ! test -f $binfolder/shutdown.sh; then # check if shutdown.sh already exist, to be removed at the beginning of 2025
#	if [[ $(smc -k BCLM -r) == *"no data"* ]]; then # power limit during shutdown only required for Apple CPU Macbook
#		echo "[ 3 ] Setup for power limit when Macs shutdown"
#		sudo cp $batteryfolder/dist/.reboot $HOME/.reboot
#		sudo cp $batteryfolder/dist/.shutdown $HOME/.shutdown
#		sudo cp $batteryfolder/dist/shutdown.sh $binfolder/shutdown.sh
#		sudo cp $batteryfolder/dist/battery_shutdown.plist $HOME/Library/LaunchAgents/battery_shutdown.plist
#		launchctl enable "gui/$(id -u $USER)/com.battery_shutdown.app"
#		launchctl unload "$HOME/Library/LaunchAgents/battery_shutdown.plist" 2> /dev/null
#		launchctl load "$HOME/Library/LaunchAgents/battery_shutdown.plist" 2> /dev/null
#		sudo chown $USER $HOME/.reboot
#		sudo chmod 755 $HOME/.reboot
#		sudo chmod u+x $HOME/.reboot
#		sudo chown $USER $HOME/.shutdown
#		sudo chmod 755 $HOME/.shutdown
#		sudo chmod u+x $HOME/.shutdown
#		sudo chown $USER $binfolder/shutdown.sh
#		sudo chmod 755 $binfolder/shutdown.sh
#		sudo chmod u+x $binfolder/shutdown.sh
#	fi
#fi

## correct the schedule plist if it is incorrect due to the bug, to be removed at the beginning of 2025
#schedule_tracker_file="$configfolder/calibrate_schedule"
#enable_exist="$(launchctl print gui/$(id -u $USER) | grep "=> enabled")"
#if [[ $enable_exist ]]; then # new version that replace => false with => enabled
#    schedule_enabled="$(launchctl print gui/$(id -u $USER) | grep enabled | grep "com.battery_schedule.app")"
#else # old version that use => false
#    schedule_enabled="$(launchctl print gui/$(id -u $USER) | grep "=> false" | grep "com.battery_schedule.app")"
#    schedule_enabled=${schedule_enabled/false/enabled}
#fi

#if test -f $schedule_tracker_file && [[ $schedule_enabled =~ "enabled" ]]; then
#	schedule=$(cat $schedule_tracker_file 2>/dev/null)

#	time=$(echo ${schedule#*" at "} | awk '{print $1}')
#	hour=${time%:*}
#	minute=${time#*:}

#	if [[ $schedule == *"every"* ]] && [[ $schedule == *"Week"* ]] && [[ $schedule == *"Year"* ]]; then
#        weekday=$(echo $schedule | awk '{print $4}')
#        week_period=$(echo $schedule | awk '{print $6}')
#        week=$(echo $schedule | awk '{print $13}')
#        year=$(echo $schedule | awk '{print $16}')
#        if  [[ $schedule =~ "MON" ]]; then weekday=1; elif
#            [[ $schedule =~ "TUE" ]]; then weekday=2; elif
#            [[ $schedule =~ "WED" ]]; then weekday=3; elif
#            [[ $schedule =~ "THU" ]]; then weekday=4; elif
#            [[ $schedule =~ "FRI" ]]; then weekday=5; elif
#            [[ $schedule =~ "SAT" ]]; then weekday=6; elif
#            [[ $schedule =~ "SUN" ]]; then weekday=0;
#        fi
#        schedule="weekday $weekday week_period $week_period hour $hour minute $minute"
#    else
#		n_days=0
#		days[0]=
#		days[1]=
#		days[2]=
#		days[3]=
#        schedule=${schedule/weekday}
#		day_loc=$(echo "$schedule" | tr " " "\n" | grep -n "day" | cut -d: -f1)
#		if [[ $day_loc ]]; then
#			for i_day in {1..4}; do
#				value=$(echo $schedule | awk '{print $"'"$((day_loc+i_day))"'"}')
#				if valid_day $value; then
#					days[$n_days]=$value
#					n_days=$(($n_days+1))
#				else
#					break
#				fi
#			done 
#		fi

#		month_period_loc=$(echo "$schedule" | tr " " "\n" | grep -n "every" | cut -d: -f1)

#		if [[ $month_period_loc ]]; then
#			month_period=$(echo $schedule | awk '{print $"'"$((month_period_loc+1))"'"}');
#            schedule="day ${days[*]} month_period $month_period hour $hour minute $minute"
#		else # calibrate every month case
#			schedule="day ${days[*]} $month_period hour $hour minute $minute"
#		fi
#    fi
#    battery schedule $schedule
#fi

#echo "[ 3 ] Setting up visudo declarations"
#if [[ $(version_number $version_local) < $(version_number "v2.0.9") ]]; then
#	sudo $batteryfolder/battery.sh visudo $USER
#fi

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
pkill -f "$binfolder/battery.*"


#if [[ $(version_number $version_local) > $(version_number "v2.0.8") ]]; then
	battery maintain recover
#else # to be removed at the beginning of 2025
#	battery maintain_synchronous recover >> $HOME/.battery/battery.log &
#	battery create_daemon >> /dev/null
#	battery schedule enable >> /dev/null
#	battery status 
#fi

button_empty="                                                                                                                                                    "
if $is_TW; then
	changelog=$(get_changelog CHANGELOG_TW)
	answer="$(osascript -e 'display dialog "'"已更新至 $version, 更新內容如下\n\n$changelog"'" buttons {"'"$button_empty"'", "完成"} default button 2 with icon note with title "BatteryOptimizer for MAC"' -e 'button returned of result')"
else
	changelog=$(get_changelog CHANGELOG)
	answer="$(osascript -e 'display dialog "'"Update to $version completed, changes include\n\n$changelog"'" buttons {"'"$button_empty"'", "Finish"} default button 2 with icon note with title "BatteryOptimizer for MAC"' -e 'button returned of result')"
fi
