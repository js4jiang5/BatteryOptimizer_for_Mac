#!/bin/bash

## ###############
## Update management
## variables are used by this binary as well at the update script
## ###############
BATTERY_CLI_VERSION="v0.0.1"
BATTERY_VISUDO_VERSION="v1.0.1"

# Path fixes for unexpected environments
PATH=/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

## ###############
## Variables
## ###############
binfolder=/usr/local/bin
visudo_folder=/private/etc/sudoers.d
visudo_file=${visudo_folder}/battery
configfolder=$HOME/.battery
pidfile=$configfolder/battery.pid
logfile=$configfolder/battery.log
pid_sig=$configfolder/sig.pid
sigfile="$configfolder/sig"
state_file="$configfolder/state"
maintain_percentage_tracker_file=$configfolder/maintain.percentage
daemon_path=$HOME/Library/LaunchAgents/battery.plist
calibrate_pidfile=$configfolder/calibrate.pid
calibrate_method_file=$configfolder/calibrate_method
schedule_path=$HOME/Library/LaunchAgents/battery_schedule.plist
schedule_tracker_file="$configfolder/calibrate_schedule"
shutdown_path=$HOME/Library/LaunchAgents/battery_shutdown.plist
webhookid_file=$configfolder/ha_webhook.id
daily_log=$configfolder/daily.log
informed_version_file=$configfolder/informed.version
language_file=$configfolder/language.code
github_link="https://raw.githubusercontent.com/js4jiang5/BatteryOptimizer_for_MAC/refs/heads/intel"

## ###############
## Housekeeping
## ###############

# Create config folder if needed
mkdir -p $configfolder

# create logfile if needed
touch $logfile

# Trim logfile if needed
logsize=$(stat -f%z "$logfile")
max_logsize_bytes=5000000
if ((logsize > max_logsize_bytes)); then
	tail -n 100 $logfile >$logfile
fi

# CLI help message
helpmessage="
Battery CLI utility $BATTERY_CLI_VERSION

Usage:

  battery maintain PERCENTAGE[10-100,stop,suspend,recover] SAILING_TARGET[5-99]
    reboot-persistent battery level maintenance: turn off charging above, and on below a certain value
	it has the option of a --force-discharge flag that discharges even when plugged in (this does NOT work with clamshell mode)
	SAILING_TARGET default is PERCENTAGE-5 if not specified
	Examples:
    battery maintain 80 50    # maintain at 80% with sailing to 50%
	battery maintain 80    # equivalent to battery maintain 80 75
    battery maintain stop   # kill running battery maintain process, disable daemon, and enable charging. maintain will not run after reboot
	battery maintain suspend   # suspend running battery maintain process and enable charging. maintain is automatically resumed after AC adapter is reconnected. used for temporary charging to 100% before travel
	battery maintain recover   # recover battery maintain process

  battery calibrate 
    calibrate the battery by discharging it to 15%, then recharging it to 100%, and keeping it there for 1 hour, then discharge to maintained percentage level
	if macbook lid is not open or AC adapter is not connected, a remind notification will be received.
	calibration will be started automatically once macbook lid is open and AC adapter is connected
	notification will be received when each step is completed or error occurs till the end of calibration
	if you prefer the notifications to stay on until you dismiss it, setup notifications as follows
		system settings > notifications > applications > Script Editor > Choose "Alerts"
	when external monitor is used, you must setup notifications as follows in order to receive notification successfully
		system settings > notifications > check 'Allow notifications when mirroring or sharing the display'
	eg: battery calibrate   # start calibration
	eg: battery calibrate stop # stop calibration and resume maintain
	
  battery schedule
	schedule periodic calibration at most 4 separate days per month, or specified weekday every 1~12 weeks, or specified one day every 1~3 month. default is one day per month on Day 1 at 9am.
	Examples:
	battery schedule    # calibrate on Day 1 at 9am
	battery schedule day 1 8 15 22    # calibrate on Day 1, 8, 15, 22 at 9am.
	battery schedule day 3 18 hour 13    # calibrate on Day 3, 18 at 13:00
	battery schedule day 6 16 26 hour 18 minute 30    # calibrate on Day 6, 16, 26 at 18:30
    battery schedule weekday 0 week_period 2 hour 21 minute 30 # calibrate on Sunday every 2 weeks at 21:30
	battery schedule day 5 month_period 3 hour 21 minute 30 # calibrate every 3 month on Day 5 at 21:00
    battery schedule disable    # disable periodic calibration
	battery schedule enable    # enable periodic calibration
	Restrictions:
		1. at most 4 days per month are allowed
		2. valid day range [1-28]
		3. valid hour range [0-23]
		4. valid minute range [0-59]
    	5. valid weekday range [0-6] 0:Sunday, 1:Monday, ...
    	6. valid week_period range [1-12]
		7. valid month_period range [1-3]

  battery charge LEVEL[1-100]
    charge the battery to a certain percentage, and disable charging when that percentage is reached
    eg: battery charge 90

  battery discharge LEVEL[1-100]
    block power input from the adapter until battery falls to this level
    eg: battery discharge 90

  battery status
    output battery SMC status, capacity, temperature, health, and cycle count 

  battery dailylog
    output daily log and show daily log store location

  battery changelog
	show the changelog of the latest version on Github

  battery logs LINES[integer, optional]
    output logs of the battery CLI and GUI
	eg: battery logs 100

  battery language LANG[tw,us]
    eg: battery language tw  # show status and notification in traditional Chinese if available
	eg: battery language us  # show status and notification in English

  battery update
    update the battery utility to the latest version

  battery version
	show current version

  battery reinstall
    reinstall the battery utility to the latest version (reruns the installation script)

  battery uninstall
    enable charging, remove the smc tool, and the battery script

"

# Visudo instructions
visudoconfig="
# Visudo settings for the battery utility installed from https://github.com/js4jiang5/BatteryOptimizer_for_MAC
# intended to be placed in $visudo_file on a mac
Cmnd_Alias      BATTERYOFF = $binfolder/smc -k CH0B -w 02, $binfolder/smc -k CH0C -w 02, $binfolder/smc -k CH0B -r, $binfolder/smc -k CH0C -r
Cmnd_Alias      BATTERYON = $binfolder/smc -k CH0B -w 00, $binfolder/smc -k CH0C -w 00
Cmnd_Alias      DISCHARGEOFF = $binfolder/smc -k CH0I -w 00, $binfolder/smc -k CH0I -r, $binfolder/smc -k CH0J -w 00, $binfolder/smc -k CH0J -r, $binfolder/smc -k CH0K -w 00, $binfolder/smc -k CH0K -r
Cmnd_Alias      DISCHARGEON = $binfolder/smc -k CH0I -w 01, $binfolder/smc -k CH0J -w 01, $binfolder/smc -k CH0K -w 01
Cmnd_Alias      LEDCONTROL = $binfolder/smc -k ACLC -w 04, $binfolder/smc -k ACLC -w 03, $binfolder/smc -k ACLC -w 02, $binfolder/smc -k ACLC -w 01, $binfolder/smc -k ACLC -w 00, $binfolder/smc -k ACLC -r
Cmnd_Alias      BATTERYBCLM = $binfolder/smc -k BCLM -w 0a, $binfolder/smc -k BCLM -w 64, $binfolder/smc -k BCLM -r
Cmnd_Alias      BATTERYCHWA = $binfolder/smc -k CHWA -w 00, $binfolder/smc -k CHWA -w 01, $binfolder/smc -k CHWA -r
Cmnd_Alias      BATTERYACEN = $binfolder/smc -k ACEN -w 00, $binfolder/smc -k ACEN -w 01, $binfolder/smc -k ACEN -r
Cmnd_Alias      BATTERYBSAC = $binfolder/smc -k BSAC -w 03, $binfolder/smc -k BSAC -w 13, $binfolder/smc -k BSAC -w 23, $binfolder/smc -k BSAC -w 33, $binfolder/smc -k BSAC -w 43, $binfolder/smc -k BSAC -r
Cmnd_Alias      BATTERYCHBI = $binfolder/smc -k CHBI -r
Cmnd_Alias      BATTERYB0AC = $binfolder/smc -k B0AC -r 
ALL ALL = NOPASSWD: BATTERYOFF
ALL ALL = NOPASSWD: BATTERYON
ALL ALL = NOPASSWD: DISCHARGEOFF
ALL ALL = NOPASSWD: DISCHARGEON
ALL ALL = NOPASSWD: LEDCONTROL
ALL ALL = NOPASSWD: BATTERYBCLM
ALL ALL = NOPASSWD: BATTERYCHWA
ALL ALL = NOPASSWD: BATTERYACEN
ALL ALL = NOPASSWD: BATTERYCHBI
ALL ALL = NOPASSWD: BATTERYB0AC
"

# Get parameters
battery_binary=$0
action=$1
setting=$2
subsetting=$3
thirdsetting=$4
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
# check the availability of SMC keys
[[ $(smc -k BCLM -r) =~ "no data" ]] && has_BCLM=false || has_BCLM=true;
[[ $(smc -k CH0B -r) =~ "no data" ]] && has_CH0B=false || has_CH0B=true;
[[ $(smc -k CH0C -r) =~ "no data" ]] && has_CH0C=false || has_CH0C=true;
[[ $(smc -k CH0I -r) =~ "no data" ]] && has_CH0I=false || has_CH0I=true;
[[ $(smc -k CH0J -r) =~ "no data" ]] && has_CH0J=false || has_CH0J=true;
[[ $(smc -k CH0K -r) =~ "no data" ]] && has_CH0K=false || has_CH0K=true;
[[ $(smc -k ACEN -r) =~ "no data" ]] && has_ACEN=false || has_ACEN=true;
[[ $(smc -k BSAC -r) =~ "no data" ]] && has_BSAC=false || has_BSAC=true;
[[ $(smc -k ACLC -r) =~ "no data" ]] && has_ACLC=false || has_ACLC=true;
[[ $(smc -k CHWA -r) =~ "no data" ]] && has_CHWA=false || has_CHWA=true;

## ###############
## Helpers
## ###############


function valid_action() {
    local action=$1
    
    # List of valid actions
    VALID_ACTIONS=("" "visudo" "maintain" "calibrate" "schedule" "charge" "discharge" 
	"status" "dailylog" "logs" "language" "update" "version" "reinstall" "uninstall" 
	"maintain_synchronous" "status_csv" "create_daemon" "disable_daemon" "remove_daemon" "changelog")
    
    # Check if action is valid
    local action_valid=false
    for valid_action in "${VALID_ACTIONS[@]}"; do
        if [[ "$action" == "$valid_action" ]]; then
            action_valid=true
            break
        fi
    done
    
    if ! $action_valid; then
        echo "Error: Unknown command '$action'"
        # Find similar commands
        echo "Did you mean one of these?"
        for valid_action in "${VALID_ACTIONS[@]}"; do
            if [[ "$valid_action" == *"${action:0:3}"* ]]; then
                echo "  - $valid_action"
            fi
        done
        echo "Run 'battery' without parameters, for list of valid commands."
        return 1
    fi
    
    return 0
}

function ha_webhook() {
	DST=http://homeassistant.local:8123
	if test -f "$webhookid_file"; then
		WEBHOOKID=$(cat "$webhookid_file" 2>/dev/null)
		if [ $3 ]; then
			curl -sS -X POST \
			-H "Content-Type: application/json"\
			-d "{\"stage\": \"$1\" , \"battery\": \"$2\" , \"voltage\": \"$3\"}" \
			$DST/api/webhook/$WEBHOOKID 
		elif [ $2 ]; then
			curl -sS -X POST \
			-H "Content-Type: application/json"\
			-d "{\"stage\": \"$1\" , \"battery\": \"$2\"}" \
			$DST/api/webhook/$WEBHOOKID 
		else
			curl -sS -X POST \
			-H "Content-Type: application/json"\
			-d "{\"stage\": \"$1\" }" \
			$DST/api/webhook/$WEBHOOKID 
		fi
	fi
}

function log() {
	echo -e "$(date +%D-%T) - $1"
}

function logLF() {
	echo -e "\n$(date +%D-%T) - $1"
}

function logn() {
	echo -e -n "$(date +%D-%T) - $1"
}

function logd() {
	echo -e "$(date +%Y/%m/%d) $1"
}

function valid_percentage() {
	if ! [[ "$1" =~ ^[0-9]+$ ]] || [[ "$1" -lt 0 ]] || [[ "$1" -gt 100 ]]; then
		return 1
	else
		return 0
	fi
}

function valid_month_period() {
	if ! [[ "$1" =~ ^[0-9]+$ ]] || [[ "$1" -lt 1 ]] || [[ "$1" -gt 3 ]]; then
		return 1
	else
		return 0
	fi
}

function valid_day() {
	if ! [[ "$1" =~ ^[0-9]+$ ]] || [[ "$1" -lt 1 ]] || [[ "$1" -gt 28 ]]; then
		return 1
	else
		return 0
	fi
}

function valid_hour() {
	if ! [[ "$1" =~ ^[0-9]+$ ]] || [[ "$1" -lt 0 ]] || [[ "$1" -gt 23 ]]; then
		return 1
	else
		return 0
	fi
}

function valid_minute() {
	if ! [[ "$1" =~ ^[0-9]+$ ]] || [[ "$1" -lt 0 ]] || [[ "$1" -gt 59 ]]; then
		return 1
	else
		return 0
	fi
}

function valid_weekday() {
	if ! [[ "$1" =~ ^[0-9]+$ ]] || [[ "$1" -lt 0 ]] || [[ "$1" -gt 6 ]]; then
		return 1
	else
		return 0
	fi
}

function valid_week_period() {
	if ! [[ "$1" =~ ^[0-9]+$ ]] || [[ "$1" -lt 1 ]] || [[ "$1" -gt 12 ]]; then
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

function check_next_calibration_date() {
    LANG=en_us_8859_1
	schedule=$(cat "$schedule_tracker_file" 2>/dev/null)
	if [[ $schedule == *"every"* ]] && [[ $schedule == *"Week"* ]] && [[ $schedule == *"Year"* ]]; then
        weekday=$(echo $schedule | awk '{print $4}')
        week_period=$(echo $schedule | awk '{print $6}')
        time=$(echo $schedule | awk '{print $9}')
        week=$(echo $schedule | awk '{print $13}')
        year=$(echo $schedule | awk '{print $16}')
        hour=${time%:*}
        minute=${time#*:}
        if  [[ $schedule =~ "MON" ]]; then weekday=1; elif
            [[ $schedule =~ "TUE" ]]; then weekday=2; elif
            [[ $schedule =~ "WED" ]]; then weekday=3; elif
            [[ $schedule =~ "THU" ]]; then weekday=4; elif
            [[ $schedule =~ "FRI" ]]; then weekday=5; elif
            [[ $schedule =~ "SAT" ]]; then weekday=6; elif
            [[ $schedule =~ "SUN" ]]; then weekday=7;
        fi
        start_sec="$(echo `date -j -f "%Y-%V-%u %H:%M:%S" "$year-$week-$weekday $hour:$minute:00" +%s`)"
        schedule_sec="$(echo `date -j -f "%Y-%V-%u %H:%M:%S" "$(date +%Y)-$(date +%V)-$weekday $hour:$minute:00" +%s`)"
        now=`date +%s`
		for i in {0..12}; do # at most 12 weeks
			schedule_diff_sec=$((schedule_sec - start_sec))
			if [[ $((schedule_diff_sec % (week_period*7*24*60*60))) == 0 ]] && [[ $schedule_sec -gt $now ]]; then
				next_s=$schedule_sec
				break;
			else
				schedule_sec=$((schedule_sec+ (7*24*60*60)))
			fi
		done
        #for i in {0..31} ; do
        #    schedule_diff_sec=$((schedule_sec + i*86400 -start_sec))
        #    now_diff_sec=$((schedule_sec + i*86400 -now))
        #    if [[ $((schedule_diff_sec % (week_period*7*24*60*60))) == 0 ]] && [[ $schedule_diff_sec -ge 0 ]] && [[ $now_diff_sec -gt 0 ]]; then
        #        calibrate_date="$(echo `date -v+${i}d +%Y/%m/%d`)";
		#		next_s=$((schedule_sec + i*86400))
        #        break
        #    fi
        #done
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
					days[$n_days]=$(format00 $value)
					n_days=$(($n_days+1))
				else
					break
				fi
			done 
		fi

        time=${schedule#*" at "}
		time=${time%" starting"*}
        hour=${time%:*}
        minute=${time#*:}

		month_loc=$(echo "$schedule" | tr " " "\n" | grep -n "Month" | cut -d: -f1)
		if [[ $month_loc ]]; then
			month=$(echo $schedule | awk '{print $"'"$((month_loc+1))"'"}');
			month=$(format00 $month)
		fi

		year_loc=$(echo "$schedule" | tr " " "\n" | grep -n "Year" | cut -d: -f1)
		if [[ $year_loc ]]; then
			year=$(echo $schedule | awk '{print $"'"$((year_loc+1))"'"}');
		fi

		month_period_loc=$(echo "$schedule" | tr " " "\n" | grep -n "every" | cut -d: -f1)

		if [[ $month_period_loc ]]; then
			month_period=$(echo $schedule | awk '{print $"'"$((month_period_loc+1))"'"}');
			month_diff=$(((`date +%Y` - $year)*12 + `date +%m` - $month))
		else # calibrate every month case
			month_period=1 
			month_diff=0
		fi

        now=`date +%s`

        diff_min=$((86400*100)) # need to find the min in case users put larger day in front
        for i_month in {0..3}; do # at most 3 months
			if [[ $((($month_diff + $i_month) % $month_period)) -eq 0 ]]; then
				for i_day in $(seq 0 $((n_days-1))); do # check this month
					if [[ $((`date +%m` + i_month)) -gt 12 ]]; then # cross year
						year=$(date -v+1y +%Y)
					else
						year=$(date +%Y)
					fi
					#echo "$year $(date -v+${i_month}m +%m) ${days[$i_day]}"
					schedule_sec="$(echo `date -j -f "%Y-%m-%d %H:%M:%S" "$year-$(date -v+${i_month}m +%m)-${days[$i_day]} $hour:$minute:00" +%s`)"
					diff=$((schedule_sec - now))
					#echo "$diff $diff_min"
					if [[ $diff -gt 0 ]] && [[ $diff -lt $diff_min ]]; then
						next_s=$schedule_sec
						diff_min=$diff
						#echo "diff_min = $diff_min"
					fi
				done
			fi
        done
	fi
	echo $next_s
}

function show_schedule() {
	# check if schedule is enabled
	enable_exist="$(launchctl print gui/$(id -u $USER) | grep "=> enabled")"
	if [[ $enable_exist ]]; then # new version that replace => false with => enabled
		schedule_enabled="$(launchctl print gui/$(id -u $USER) | grep enabled | grep "com.battery_schedule.app")"
	else # old version that use => false
		schedule_enabled="$(launchctl print gui/$(id -u $USER) | grep "=> false" | grep "com.battery_schedule.app")"
		schedule_enabled=${schedule_enabled/false/enabled}
	fi
	schedule_txt="$(cat $schedule_tracker_file 2>/dev/null)"
	if [[ $schedule_enabled =~ "enabled" ]]; then
		if [[ $schedule_txt ]]; then
			if $is_TW; then
				if ! [[ $schedule_txt =~ "week" ]]; then
					if ! [[ $schedule_txt =~ "month" ]]; then
						schedule_txt=${schedule_txt/"Schedule calibration on day"/"電池自動校正時程安排在"}
						schedule_txt=${schedule_txt/"at"/"日"}
					else
						schedule_txt=${schedule_txt/"Schedule calibration on day"/"電池自動校正時程安排在"}
						schedule_txt=${schedule_txt/"every "/"日每"}
						schedule_txt=${schedule_txt/"month at"/"個月"}
						schedule_txt=${schedule_txt%" starting"*}
					fi
				else
					schedule_txt=${schedule_txt/"Schedule calibration on"/"電池自動校正時程安排在"}		
					schedule_txt=${schedule_txt/"SUN"/"星期日"} 
					schedule_txt=${schedule_txt/"MON"/"星期一"}
					schedule_txt=${schedule_txt/"TUE"/"星期二"}
					schedule_txt=${schedule_txt/"WED"/"星期三"}
					schedule_txt=${schedule_txt/"THU"/"星期四"}
					schedule_txt=${schedule_txt/"FRI"/"星期五"}
					schedule_txt=${schedule_txt/"SAT"/"星期六"}
					schedule_txt=${schedule_txt/"every "/"每"}
					schedule_txt=${schedule_txt/"week at"/"週"}
					schedule_txt=${schedule_txt%" starting"*}

				fi
				log "$schedule_txt 開始"
				#check_next_calibration_date
				log "下次校正日期是 `date -j -f "%s" "$(echo $(check_next_calibration_date) | awk '{print $NF}')" +%Y/%m/%d`"
			
			else
				schedule_txt=${schedule_txt%" starting"*}
				log "$schedule_txt"
				log "Next calibration date is `date -j -f "%s" "$(echo $(check_next_calibration_date) | awk '{print $NF}')" +%Y/%m/%d`"
			fi
		else
			if $is_TW; then
				log "您尚未設定電池自動校正時程"
			else
				log "You haven't scheduled calibration yet"
			fi
		fi
	else
		if [[ $schedule_txt ]]; then
			if $is_TW; then
				log "您的電池自動校正時程已暫停，要恢復請執行"
			else
				log "Your calibration schedule is disabled. Enable it by"
			fi
			log "battery schedule enable"
		else
			if $is_TW; then
				log "您尚未設定電池自動校正時程"
			else
				log "You haven't scheduled calibration yet"
			fi
		fi
	fi
}

## #################
## SMC Manipulation
## #################

# Change magsafe color
# see community sleuthing: https://github.com/actuallymentor/battery/issues/71
function change_magsafe_led_color() {
	if [[ $(get_cpu_type) == "apple" ]]; then
		log "MagSafe LED function invoked"
		color=$1

		# Check whether user can run color changes without password (required for backwards compatibility)
		if sudo -n smc -k ACLC -r &>/dev/null; then
			log "💡 Setting magsafe color to $color"
		else
			log "🚨 Your version of battery is using an old visudo file, please run 'battery visudo' to fix this, until you do battery cannot change magsafe led colors"
			return
		fi

		if [[ "$color" == "green" ]]; then
			log "setting LED to green"
			sudo smc -k ACLC -w 03
		elif [[ "$color" == "orange" ]]; then
			log "setting LED to orange"
			sudo smc -k ACLC -w 04
		elif [[ "$color" == "none" ]]; then
			log "setting LED to none"
			sudo smc -k ACLC -w 01
		else
			# Default action: reset. Value 00 is a guess and needs confirmation
			log "resetting LED"
			sudo smc -k ACLC -w 00
		fi
	fi
}

# Re:discharging, we're using keys uncovered by @howie65: https://github.com/actuallymentor/battery/issues/20#issuecomment-1364540704
# CH0I seems to be the "disable the adapter" key
function enable_discharging() {
	#if [[ $(get_cpu_type) == "apple" ]]; then
		disable_charging
		log "🔽🪫 Enabling battery discharging"
		if $has_CH0I; then sudo smc -k CH0I -w 01; fi
		if $has_ACLC; then sudo smc -k ACLC -w 01; fi
	#else
		if $has_BCLM; then sudo smc -k BCLM -w 0a; fi
		if $has_ACEN; then sudo smc -k ACEN -w 00; fi
		if $has_BSAC; then sudo smc -k BSAC -w 13; fi
		#if $has_CH0J; then sudo smc -k CH0J -w 01; fi
		#if $has_CH0K; then sudo smc -k CH0K -w 01; fi
	#fi
	sleep 1
}

function disable_discharging() {
	log "🔼🪫 Disabling battery discharging"
	#if [[ $(get_cpu_type) == "apple" ]]; then
		if $has_CH0I; then sudo smc -k CH0I -w 00; fi
	#else
		if $has_ACEN; then sudo smc -k ACEN -w 01; fi
		if $has_BSAC; then sudo smc -k BSAC -w 33; fi
		#if $has_CH0J; then sudo smc -k CH0J -w 00; fi
		#if $has_CH0K; then sudo smc -k CH0K -w 00; fi
	#fi
	sleep 1

	## Keep track of status
	#is_charging=$(get_smc_charging_status)

	#if ! valid_percentage "$setting"; then

	#	log "Disabling discharging: No valid maintain percentage set, enabling charging"
	#	# use direct commands since enable_charging also calls disable_discharging, and causes an eternal loop
	#	sudo smc -k CH0B -w 00
	#	sudo smc -k CH0C -w 00
	#	change_magsafe_led_color "orange"

	#elif [[ "$battery_percentage" -ge "$setting" && "$is_charging" == "enabled" ]]; then

	#	log "Disabling charging: Stop charge above $setting, disabling charging"
	#	disable_charging
	#	change_magsafe_led_color "green"

	#elif [[ "$battery_percentage" -lt "$setting" && "$is_charging" == "disabled" ]]; then

	#	log "Disabling discharging: Charge below $setting, enabling charging"
	#	# use direct commands since enable_charging also calls disable_discharging, and causes an eternal loop
	#	sudo smc -k CH0B -w 00
	#	sudo smc -k CH0C -w 00
	#	change_magsafe_led_color "orange"

	#fi
}

# Re:charging, Aldente uses CH0B https://github.com/davidwernhart/AlDente/blob/0abfeafbd2232d16116c0fe5a6fbd0acb6f9826b/AlDente/Helper.swift#L227
# but @joelucid uses CH0C https://github.com/davidwernhart/AlDente/issues/52#issuecomment-1019933570
# so I'm using both since with only CH0B I noticed sometimes during sleep it does trigger charging
function enable_charging() {
	#if [[ $(get_cpu_type) == "apple" ]]; then
		disable_discharging
		log "🔌🔋 Enabling battery charging"
		if $has_CH0B; then sudo smc -k CH0B -w 00; fi
		if $has_CH0C; then sudo smc -k CH0C -w 00; fi
	#else
		if $has_BCLM; then sudo smc -k BCLM -w 64; fi
		if $has_ACEN; then sudo smc -k ACEN -w 01; fi
		if $has_BSAC; then sudo smc -k BSAC -w 33; fi
	#fi
	sleep 1
}

function disable_charging() {
	log "🔌🪫 Disabling battery charging"
	#if [[ $(get_cpu_type) == "apple" ]]; then
		if $has_CH0B; then sudo smc -k CH0B -w 02; fi
		if $has_CH0C; then sudo smc -k CH0C -w 02; fi
	#fi
		if $has_BCLM; then sudo smc -k BCLM -w 0a; fi
		if $has_ACEN; then sudo smc -k ACEN -w 01; fi
		if $has_BSAC; then sudo smc -k BSAC -w 01; fi
	#fi
	sleep 1
}

function get_smc_charging_status() {
	if [[ $(get_cpu_type) == "apple" ]]; then
		hex_status=$(smc -k CH0B -r | awk '{print $4}' | sed s:\)::)
		if [[ "$hex_status" == "00" ]]; then
			echo "enabled"
		else
			echo "disabled"
		fi
	else
		bclm_hex_status=$(smc -k BCLM -r | awk '{print $6}' | sed s:\)::)
		acen_hex_status=$(smc -k ACEN -r | awk '{print $6}' | sed s:\)::)
		if [[ "$bclm_hex_status" == "64" ]] && [[ "$acen_hex_status" == "01" ]]; then
			echo "enabled"
		else
			echo "disabled"
		fi
	fi
}

function get_smc_discharging_status() {
	if [[ $(get_cpu_type) == "apple" ]]; then
		hex_status=$(smc -k CH0I -r | awk '{print $4}' | sed s:\)::)
		if [[ "$hex_status" == "0" ]]; then
			echo "not discharging"
		else
			echo "discharging"
		fi
	else
		acen_hex_status=$(smc -k ACEN -r | awk '{print $6}' | sed s:\)::)
		if [[ "$acen_hex_status" == "01" ]]; then
			echo "not discharging"
		else
			echo "discharging"
		fi
	fi
}

## ###############
## Statistics
## ###############

function get_battery_percentage() {
	#battery_percentage=$(pmset -g batt | tail -n1 | awk '{print $3}' | sed s:\%\;::)
	battery_percentage=$(smc -k BRSC -r | awk '{print $3}')
	if [ $battery_percentage -gt 100 ]; then
		battery_percentage=$((battery_percentage/256)) # BRSC is battery_level in some system, but bettery_level in others
	fi
	echo $battery_percentage
}

function get_accurate_battery_percentage() {
	MaxCapacity=$(ioreg -l -n AppleSmartBattery -r | grep "\"AppleRawMaxCapacity\" =" | awk '{ print $3 }' | tr ',' '.')
	CurrentCapacity=$(ioreg -l -n AppleSmartBattery -r | grep "\"AppleRawCurrentCapacity\" =" | awk '{ print $3 }' | tr ',' '.')
    accurate_battery_percentage=$(echo "scale=1; $CurrentCapacity*100/$MaxCapacity" | bc)
    echo $accurate_battery_percentage
}

function get_remaining_time() {
	time_remaining=$(pmset -g batt | tail -n1 | awk '{print $5}')
	echo "$time_remaining"
}

function get_charger_state() {
	ac_attached=$(pmset -g batt | tail -n1 | awk '{ x=match($0, /AC attached/) > 0; print x }')
	echo "$ac_attached"
}

function get_charging_status() {
	#if [[ $(get_cpu_type) == "apple" ]]; then
	#	is_charging=$(pmset -g batt | tail -n1 | awk '{ x=match($0, /; charging;/) > 0; print x }')
	#	is_discharging=$(pmset -g batt | tail -n1 | awk '{ x=match($0, /; discharging;/) > 0; print x }')
	#else
		charge_current=$(smc -k CHBI -r | awk '{print $3}' | sed s:\)::)
		discharge_current=$(smc -k B0AC -r | awk '{print $3}' | sed s:\)::)
		if [[ $charge_current == "0" ]]; then
			is_charging=0
		else
			is_charging=1
		fi
		if [[ $discharge_current == "0" ]]; then
			is_discharging=0
		else
			is_discharging=1
		fi
	#fi

	if [ "$is_charging" == "1" ]; then # charging
		echo "1"
	elif [ "$is_discharging" == "1" ]; then # discharging
		echo "2"
	else # not charging
		echo "0"
	fi
}

function get_maintain_percentage() {
	maintain_percentage=$(cat $maintain_percentage_tracker_file 2>/dev/null)
	echo "$maintain_percentage" | awk '{print $1}'
}

function get_voltage() {
	voltage=$(ioreg -l -n AppleSmartBattery -r | grep "\"Voltage\" =" | awk '{ print $3/1000 }' | tr ',' '.')
	echo "$voltage"
}

function get_battery_health() {
	MaxCapacity=$(ioreg -l -n AppleSmartBattery -r | grep "\"AppleRawMaxCapacity\" =" | awk '{ print $3 }' | tr ',' '.')
	DesignCapacity=$(ioreg -l -n AppleSmartBattery -r | grep "\"DesignCapacity\" =" | awk '{ print $3 }' | tr ',' '.')
    health=$(echo "scale=1; $MaxCapacity*100/$DesignCapacity" | bc)
    echo $health
}

function get_battery_temperature() {
	temperature=$(ioreg -l -n AppleSmartBattery -r | grep "\"VirtualTemperature\" =" | awk '{ print $3 }' | tr ',' '.')
	
	if [ $temperature ]; then
		temperature=$(echo "scale=1; ($temperature+5)/100" | bc)
	else
		#temperature=$(ioreg -l -n AppleSmartBattery -r | grep "\"Temperature\" =" | awk '{ print $3 }' | tr ',' '.')
		#temperature=$(echo "scale=1; ($temperature+5)/100" | bc)
		temperature=$(echo $(smc -k TB0T -r) | awk '{print $3}') # this value is closer to coconutBattery and AlDente
		temperature=$(echo "scale=1; ($temperature*1000+50)/1000" | bc)
	fi
    
    echo $temperature
}

function get_cycle() {
	cycle=$(ioreg -l -n AppleSmartBattery -r | grep "\"CycleCount\" =" | awk '{ print $3 }' | tr ',' '.')
	echo "$cycle"
}

function get_charger_connection() { # 20241013 by JS
	# AC is consider connected if battery is not discharging
	ac_attached=$(pmset -g batt | tail -n1 | awk '{ x=match($0, /AC attached/) > 0; print x }')
	is_charging=$(pmset -g batt | tail -n1 | awk '{ x=match($0, /; charging;/) > 0; print x }')
	discharge_current=$(smc -k B0AC -r | awk '{print $3}' | sed s:\)::)
	if [[ $discharge_current == "0" ]]; then
		not_discharging=1
	else
		not_discharging=0
	fi
	ac_connected=$(($ac_attached || $is_charging || $not_discharging))
	echo "$ac_connected"
}

function get_cpu_type() {
	if [[ $(smc -k BCLM -r) == *"no data"* ]]; then
		echo "apple"
	else
		echo "intel"
	fi
    #if [[ $(sysctl -n machdep.cpu.brand_string) == *"Intel"* ]]; then
    #    echo "intel"
    #else
    #    echo "apple"
    #fi
}

function get_parameter { # get parameter value from configuration file. the format is var=value or var= value or var = value
    var_loc=$(echo $(echo "$1" | tr " " "\n" | grep -n "$2" | cut -d: -f1) | awk '{print $1}')
    if [ -z $var_loc ]; then
        echo
    else
        echo $1 | awk '{print $"'"$((var_loc))"'"}' | tr '=' ' ' | awk '{print $2}'
    fi
}

function get_changelog { # get the latest changelog
	if [[ -z $1 ]]; then
		changelog=$(curl -sSL $github_link/CHANGELOG | sed s:\":'\\"':g 2>&1)
	else
		changelog=$(curl -sSL $github_link/$1 | sed s:\":'\\"':g 2>&1)
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

function get_version { # get the latest version number
	if [[ -z $1 ]]; then
		changelog=$(curl -sSL $github_link/CHANGELOG | sed s:\":'\\"':g 2>&1)
	else
		changelog=$(curl -sSL $github_link/$1 | sed s:\":'\\"':g 2>&1)
	fi

	while read -r "line"; do
		break
    done <<< "$changelog"
	echo $line
}

function lid_closed() { # 20241013 by JS
	lid_is_closed=$(ioreg -r -k AppleClamshellState -d 1 | grep AppleClamshellState | tail -n1 | awk '{print $3}')
	echo "$lid_is_closed"
}

function confirm_SIG() {
	ack_received=1
	break
	echo
}

function ack_SIG() {
	sigpid=$(cat "$pid_sig" 2>/dev/null)
	sig=$(cat "$sigfile" 2>/dev/null)
	if [ "$sig" == "suspend" ]; then # if suspend is called by user, enable charging to 100%
		maintain_status="suspended"
		enable_charging
		log 'ack battery maintain suspend' # send ack
	elif [ "$sig" == "suspend_no_charging" ]; then # if suspend is called by another battery process, let that process handle charging
		maintain_status="suspended"
		log 'ack battery maintain suspend' # send ack
	elif [ "$sig" == "recover" ]; then
		maintain_status="active"
		disable_discharging
		log 'ack battery maintain recover' # send ack
	fi
	kill -s USR1 $sigpid 2> /dev/null;
}

function calibrate_interrupted() {
	rm $calibrate_pidfile 2>/dev/null
	if [[ "$(maintain_is_running)" == "1" ]] && [[ "$(cat $state_file 2>/dev/null)" == "suspended" ]]; then
		$battery_binary maintain recover
	fi
	kill 0 # kill all child processes
	exit 1
}

function charge_interrupted() {
	disable_charging
	if [[ "$(maintain_is_running)" == "1" ]] && [[ "$(cat $state_file 2>/dev/null)" == "suspended" ]]; then
		$battery_binary maintain recover
	fi
	exit 1
}

function discharge_interrupted() {
	disable_discharging
	if [[ "$(maintain_is_running)" == "1" ]] && [[ "$(cat $state_file 2>/dev/null)" == "suspended" ]]; then
		$battery_binary maintain recover
	fi
	exit 1
}

function maintain_is_running() {
	# check if battery maintain is running
	if test -f "$pidfile"; then # if maintain is ongoing
		pid=$(cat "$pidfile" 2>/dev/null)
		#n_pid=$(pgrep -f $battery_binary | awk 'END{print NR}')
		#pid_found=0
		#for ((i = 1; i <= n_pid; i++)); do
		#	pid_running=$(pgrep -f $battery_binary | head -n$i | tail -n1 | awk '{print $1}')
		#	if [ "$pid" == "$pid_running" ]; then # battery maintain is running
		#		pid_found=1
		#		break
		#	fi
		#done
		if [[ $(pgrep -f $battery_binary) == *"$pid"* ]] && [[ $pid ]]; then
			echo 1
		else
			echo 0
		fi
	else
		echo 0
	fi
}

function calibrate_is_running() {
	# check if battery calibrate is running
	if test -f "$calibrate_pidfile"; then # if calibration is ongoing
		pid_calibrate=$(cat "$calibrate_pidfile" 2>/dev/null)
		if [[ $(pgrep -f $battery_binary) == *"$pid_calibrate"* ]] && [[ $pid_calibrate ]]; then
			echo 1
		else
			echo 0
		fi
	else
		echo 0
	fi
}

## ###############
## Actions
## ###############

# Help message
if [ -z "$action" ] || [[ "$action" == "help" ]]; then
	echo -e "$helpmessage"
	exit 0
fi

# Validate action
if ! valid_action "$action"; then
    exit 1
fi

# Visudo message
if [[ "$action" == "visudo" ]]; then

	# User to set folder ownership to is $setting if it is defined and $USER otherwise
	if [[ -z "$setting" ]]; then
		setting=$USER
	fi

	# Set visudo tempfile ownership to current user
	log "Setting visudo file permissions to $setting"
	sudo chown -R $setting $configfolder

	# Write the visudo file to a tempfile
	visudo_tmpfile="$configfolder/visudo.tmp"
	sudo rm $visudo_tmpfile 2>/dev/null
	echo -e "$visudoconfig" >$visudo_tmpfile

	# If the visudo file is the same (no error, exit code 0), set the permissions just
	if sudo cmp $visudo_file $visudo_tmpfile &>/dev/null; then

		echo "The existing battery visudo file is what it should be for version $BATTERY_CLI_VERSION"

		# Check if file permissions are correct, if not, set them
		current_visudo_file_permissions=$(stat -f "%Lp" $visudo_file)
		if [[ "$current_visudo_file_permissions" != "440" ]]; then
			sudo chmod 440 $visudo_file
		fi

		sudo rm $visudo_tmpfile 2>/dev/null
		# exit because no changes are needed
		exit 0

	fi

	# Validate that the visudo tempfile is valid
	if sudo visudo -c -f $visudo_tmpfile &>/dev/null; then

		# If the visudo folder does not exist, make it
		if ! test -d "$visudo_folder"; then
			sudo mkdir -p "$visudo_folder"
		fi

		# Copy the visudo file from tempfile to live location
		sudo cp $visudo_tmpfile $visudo_file

		# Delete tempfile
		rm $visudo_tmpfile

		# Set correct permissions on visudo file
		sudo chmod 440 $visudo_file

		echo "Visudo file updated successfully"

	else
		echo "Error validating visudo file, this should never happen:"
		sudo visudo -c -f $visudo_tmpfile
	fi

	sudo rm $visudo_tmpfile 2>/dev/null
	exit 0
fi

# Reinstall helper
if [[ "$action" == "reinstall" ]]; then
	echo "This will run curl -sS $github_link/setup.sh   | bash"
	if [[ ! "$setting" == "silent" ]]; then
		echo "Press any key to continue"
		read
	fi
	curl -sS $github_link/setup.sh | bash
	exit 0
fi

# Update helper
if [[ "$action" == "update" ]]; then

	# Check if we have the most recent version
	# fetch latest battery.sh

	if [[ "$setting" == "beta" ]]; then
		github_link="https://raw.githubusercontent.com/js4jiang5/BatteryOptimizer_for_MAC/refs/heads/$subsetting"
	fi
	battery_new=$(echo $(curl -sSL "$github_link/battery.sh"))
	battery_new_version=$(echo $(get_parameter "$battery_new" "BATTERY_CLI_VERSION") | tr -d \")
		
	if [[ $battery_new == "404: Not Found" ]]; then
		log "Error: the specified update file is not available"
		exit 1
	fi

	visudo_new_version=$(echo $(get_parameter "$battery_new" "BATTERY_VISUDO_VERSION") | tr -d \")
	if [[ $battery_new_version == $BATTERY_CLI_VERSION ]] && [[ $visudo_new_version == $BATTERY_VISUDO_VERSION ]] && [[ "$setting" != "force" ]]; then
		if $is_TW; then
			osascript -e 'display dialog "'"$BATTERY_CLI_VERSION 已是最新版，不需要更新"'" buttons {"OK"} default button 1 giving up after 60 with icon note with title "BatteryOptimizer for MAC"' >> /dev/null
		else
			osascript -e 'display dialog "'"Your version $BATTERY_CLI_VERSION is already the latest. No need to update."'" buttons {"OK"} default button 1 giving up after 60 with icon note with title "BatteryOptimizer for MAC"' >> /dev/null
		fi		
	else
		button_empty="                                                                                                                                                    "
		if $is_TW; then
			changelog=$(get_changelog CHANGELOG_TW)
			battery_new_version=$(get_version CHANGELOG_TW)
			osascript -e 'display dialog "'"$battery_new_version 更新內容如下\n\n$changelog"'" buttons {"'"$button_empty"'", "繼續"} default button 2 with icon note with title "BatteryOptimizer for MAC"' >> /dev/null
		else
			changelog=$(get_changelog CHANGELOG)
			battery_new_version=$(get_version CHANGELOG)
			osascript -e 'display dialog "'"$battery_new_version changes inlude\n\n$changelog"'" buttons {"'"$button_empty"'", "Continue"} default button 2 with icon note with title "BatteryOptimizer for MAC"' >> /dev/null
		fi
		if $is_TW; then
			answer="$(osascript -e 'display dialog "'"你現在要更新到$battery_new_version 嗎?"'" buttons {"立即更新", "跳過此版本"} default button 1 with icon note with title "BatteryOptimizer for MAC"' -e 'button returned of result')"
			if [[ $answer == "立即更新" ]]; then
				answer="Yes"
			fi	
		else
			answer="$(osascript -e 'display dialog "'"Do you want to update to version $battery_new_version now?"'" buttons {"Yes", "No"} default button 1 with icon note with title "BatteryOptimizer for MAC"' -e 'button returned of result')"
		fi
		
		if [[ $answer == "Yes" ]]; then
			# update visudo if necessary
			if [[ $visudo_new_version != $BATTERY_VISUDO_VERSION ]]; then
				curl -sS -o $configfolder/battery_tmp.sh "$github_link/battery.sh"
				chown $USER $configfolder/battery_tmp.sh
				chmod 755 $configfolder/battery_tmp.sh
				chmod u+x $configfolder/battery_tmp.sh
				sudo $configfolder/battery_tmp.sh visudo $USER
				rm -rf $configfolder/battery_tmp.sh
			fi
			curl -sS "$github_link/update.sh" | bash
		fi
	fi
	exit 0
fi

# Uninstall helper
if [[ "$action" == "uninstall" ]]; then

	if [[ ! "$setting" == "silent" ]]; then
		echo "This will enable charging, and remove the smc tool and battery script"
		echo "Press any key to continue"
		read
	fi
	enable_charging
	disable_discharging
	$battery_binary remove_daemon
	$battery_binary schedule disable
	rm $schedule_path 2>/dev/null
	rm $shutdown_path 2>/dev/null
	sudo rm -v "$binfolder/smc" "$binfolder/battery" $visudo_file "$binfolder/shutdown.sh"
	sudo rm -v -r "$configfolder"
	sudo rm -rf $HOME/.sleep $HOME/.wakeup $HOME/.shutdown $HOME/.reboot 
	pkill -f "/usr/local/bin/battery.*"
	exit 0
fi

# Charging on/off controller
if [[ "$action" == "charge" ]]; then

	trap charge_interrupted SIGINT SIGTERM

	if ! valid_percentage "$setting"; then
		log "Error: $setting is not a valid setting for battery charge. Please use a number between 0 and 100"
		exit 1
	fi

	# Disable running daemon
	$battery_binary maintain suspend

	# Start charging
	battery_percentage=$(get_battery_percentage)
	log "Charging to $setting% from $battery_percentage%"
	enable_charging # also disables discharging

	change_magsafe_led_color "orange" # LED orange for charging

	# Loop until battery percent is exceeded
	while [[ "$battery_percentage" -lt "$setting" ]]; do

		if [[ "$battery_percentage" -ge "$((setting - 3))" ]]; then
			sleep 5 &
		else
			caffeinate -is sleep 60 &
		fi
		wait $!
		battery_percentage=$(get_battery_percentage)

	done

	disable_charging
	change_magsafe_led_color "green" # LED orange for not charging
	if $is_TW; then
		log "電池已充電至 $battery_percentage%"
	else
		log "Charging completed at $battery_percentage%"
	fi

	if [[ $battery_percentage -ge $(get_maintain_percentage) ]] && [[ "$(calibrate_is_running)" == "0" ]]; then # if charge level is higher than maintain percentage, recover maintain won't cause discharge
		$battery_binary maintain recover
	fi

	exit 0

fi

# Discharging on/off controller
if [[ "$action" == "discharge" ]]; then

	trap discharge_interrupted SIGINT SIGTERM

	if ! valid_percentage "$setting"; then
		log "Error: $setting is not a valid setting for battery discharge. Please use a number between 0 and 100"
		exit 1
	fi

	if [[ $(lid_closed) == "Yes" ]]; then
		log "Error: macbook lid must be open before discharge"
		exit 1
	fi

	# Disable running daemon
	$battery_binary maintain suspend

	# Start discharging
	battery_percentage=$(get_battery_percentage)
	log "Discharging to $setting% from $battery_percentage%"
	enable_discharging

	change_magsafe_led_color "none" # LED none for discharging

	# Loop until battery percent is below target
	while [[ "$battery_percentage" -gt "$setting" ]]; do

		log "Battery at $battery_percentage% (target $setting%)"
		caffeinate -is sleep 60 &
		wait $!
		battery_percentage=$(get_battery_percentage)

	done

	disable_discharging
	
	is_charging=$(get_smc_charging_status)

	if [[ "$is_charging" == "enabled" ]]; then
		change_magsafe_led_color "orange"
	else
		change_magsafe_led_color "green"
	fi
	
	if $is_TW; then
		log "電池已放電至 $battery_percentage%"
	else
		log "Discharging completed at $battery_percentage%"
	fi

	if [[ $battery_percentage -ge $(get_maintain_percentage) ]] && [[ "$(calibrate_is_running)" == "0" ]]; then # if discharge level is higher than maintain percentage, recover maintain won't cause charge
		$battery_binary maintain recover
	fi

	exit 0

fi

# Maintain at level
if [[ "$action" == "maintain_synchronous" ]]; then
	if [[ $(get_cpu_type) == "apple" ]]; then # reset to default when reboot
		sudo smc -k CHWA -w 00
	fi

	# Recover old maintain status if old setting is found
	if [[ "$setting" == "recover" ]]; then

		# Before doing anything, log out environment details as a debugging trail
		log "Debug trail. User: $USER, config folder: $configfolder, logfile: $logfile, file called with 1: $1, 2: $2"

		maintain_percentage=$(cat $maintain_percentage_tracker_file 2>/dev/null)
		if [[ $maintain_percentage ]]; then
			log "Recovering maintenance percentage $maintain_percentage"
			setting=$(echo $maintain_percentage | awk '{print $1}')
			subsetting=$(echo $maintain_percentage | awk '{print $2}')
		else
			log "No setting to recover, exiting"
			exit 0
		fi
	fi

	if ! valid_percentage "$setting"; then
		log "Error: $setting is not a valid setting for battery maintain. Please use a number between 0 and 100"
		exit 1
	fi

	if ! valid_percentage "$subsetting"; then
		lower_limit=$((setting-5))
		if [ $lower_limit -lt 0 ]; then
			lower_limit=0
		fi
	else
		if [ $setting -le $subsetting ]; then
			log "Error: sailing target $subsetting larger than or equal to maintain level $setting is not allowed"
			exit
		fi
		lower_limit=$subsetting
	fi

	log "Starting battery maintenance at $setting% with sailing to $lower_limit% $thirdsetting"

	# Check if the user requested that the battery maintenance first discharge to the desired level
	if [[ "$subsetting" == "--force-discharge" ]] || [[ "$thirdsetting" == "--force-discharge" ]]; then
		if [[ $(lid_closed) == "Yes" ]]; then
			log "Error: macbook lid must be open before discharge"
			exit 1
		fi
		# Before we start maintaining the battery level, first discharge to the target level
		log "Triggering discharge to $setting before enabling charging limiter"
		$battery_binary discharge "$setting"
		log "Discharge pre battery maintenance complete, continuing to battery maintenance loop"
	else
		log "Not triggering discharge as it is not requested"
	fi

	# Start charging
	battery_percentage=$(get_battery_percentage)

	log "Charging to and maintaining at $setting% from $battery_percentage%"

	# Store pid of maintenance process
	echo $$ >$pidfile
	pid=$(cat "$pidfile" 2>/dev/null)

	# Loop until battery percent is exceeded
	maintain_status="active"
	pre_maintain_status=$maintain_status
	echo $maintain_status > $state_file
	daily_log_done=false
	ac_connection=$(get_charger_connection)
	pre_ac_connection=$ac_connection
	sleep_duration=5
	charging_status=$(get_charging_status)
	if [ "$charging_status" == "1" ]; then
		log "Battery is charging"
		color="orange"
	elif [ "$charging_status" == "2" ]; then
		log "Battery is discharging"
		color="none"
	else
		log "Battery is not charging"
		color="green"
	fi
	if ! test -f $daily_log; then
    	echo "Time Capacity Voltage Temperature Health Cycle" | awk '{printf "%-10s, %9s, %9s, %12s, %9s, %9s\n", $1, $2, $3, $4, $5, $6}' > $daily_log
	fi

	now=$(date +%s)
	check_update_timeout=$(($now + 60)) # check update one time each day
	
	if test -f $informed_version_file; then
		informed_version=$(cat < $informed_version_file)
	else
		informed_version=$BATTERY_CLI_VERSION
	fi
	
	change_magsafe_led_color $color
	trap ack_SIG SIGUSR1
	while true; do
		if [ "$maintain_status" != "$pre_maintain_status" ]; then # update state to state_file
			echo $maintain_status > $state_file
			pre_maintain_status=$maintain_status 
		fi
		
		if [ "$(date +%H)" == "01" ] && $daily_log_done; then # reset daily log at 1am
			daily_log_done=false
		elif [ "$(date +%H)" == "00" ] && ! $daily_log_done; then # update daily log at 12 am
			daily_log_done=true
			logd "$(get_accurate_battery_percentage)% $(get_voltage)V $(get_battery_temperature)°C $(get_battery_health)% $(get_cycle)" | awk '{printf "%-10s, %9s, %9s, %13s, %9s, %9s\n", $1, $2, $3, $4, $5, $6}' >> $daily_log
			#if [ "$(date +%d)" == "01" ]; then # monthly notification
				osascript -e 'display notification "'"Battery $(get_accurate_battery_percentage)%, $(get_voltage)V, $(get_battery_temperature)°C\nHealth $(get_battery_health)%, Cycle $(get_cycle)"'" with title "Battery" sound name "Blow"'
			#fi
		fi

		# check if there is update version
		if [[ $(date +%s) -gt $check_update_timeout ]]; then
			updated="$(curl -sS $github_link/battery.sh | grep "$informed_version")"
			new_version="$(curl -sS $github_link/battery.sh | grep "BATTERY_CLI_VERSION=")"
			new_version="$(echo $new_version | awk '{print $1}')"
			new_version=$(echo ${new_version/"BATTERY_CLI_VERSION="} | tr -d \")
			
			if [[ -z $updated ]]; then
				if $is_TW; then
					osascript -e 'display notification "'"有新版$new_version, 請在 Terminal 下輸入 \n\\\"battery update\\\" 更新"'" with title "BatteryOptimizer" sound name "Blow"'
				else
					osascript -e 'display notification "'"New version $new_version available \nUpdate with command \\\"battery update\\\""'" with title "BatteryOptimizer" sound name "Blow"'
				fi
				informed_version=$new_version
				echo "$informed_version" > $informed_version_file
			fi
			check_update_timeout=$(($check_update_timeout + 24*60*60))
		fi

		if [ "$maintain_status" == "active" ]; then
			# Keep track of LED status
			charging_status=$(get_charging_status)

			if [ "$charging_status" == "1" ] && [ "$color" != "orange" ] ; then # orange for charging
				color="orange"
				change_magsafe_led_color $color
			elif [ "$charging_status" == "0" ] && [ "$color" != "green" ] ; then # green for not charging
				color="green"
				change_magsafe_led_color $color
			elif [ "$charging_status" == "2" ] && [ "$color" != "none" ] ; then # none for discharging
				color="none"
				change_magsafe_led_color $color
			fi

			# Keep track of SMC charging status
			smc_charging_status=$(get_smc_charging_status)
			if [[ "$battery_percentage" -ge "$setting" ]] && [[ "$smc_charging_status" == "enabled" ]]; then

				log "Stop charge above $setting"
				disable_charging
				sleep_duration=5

			elif [[ "$battery_percentage" -lt "$lower_limit" ]] && [[ "$smc_charging_status" == "disabled" ]]; then

				log "Charge below $lower_limit"
				enable_charging
				sleep_duration=5 # reduce monitoring period to 5 seconds during charging
			fi
			
			sleep $sleep_duration &
			wait $!
		else
			sleep_duration=5
			sleep $sleep_duration &
			wait $!

			ac_connection=$(get_charger_connection) # update ac connection state

			# check if calibrate is running to decide if resume
			if [[ "$(calibrate_is_running)" == "0" ]]; then # if not running
				if [[ "$ac_connection" == "1" ]] && [[ "$pre_ac_connection" == "0" ]]; then # resume maintain to active when AC adapter is reconnected
					maintain_status="active"
					log "Battery maintain is recovered because AC adapter is reconnected"
					osascript -e 'display notification "Battery maintain is recovered" with title "Battery" sound name "Blow"'
				fi
			fi
			pre_ac_connection=$ac_connection
		fi

		battery_percentage=$(get_battery_percentage)

	done

	exit 0

fi

# Asynchronous battery level maintenance
if [[ "$action" == "maintain" ]]; then

	# check if this action is called by another battery process, if yes log only without notify
	if [[ $(ps aux | grep $PPID) == *"$battery_binary"* ]]; then
		notify=0
	else
		notify=1
	fi

	pid=$(cat "$pidfile" 2>/dev/null)
	if [[ "$setting" == "recover" ]]; then
		if [[ "$(maintain_is_running)" == "1" ]]; then
			maintain_status=$(cat "$state_file" 2>/dev/null)
			if [[ "$maintain_status" == "suspended" ]]; then # maintain is running but not active
				echo $$ > $pid_sig
				echo "recover" > $sigfile
				sleep 1

				# waiting for ack from $pid
				logn "Recover in 5 secs, wait ."
				ack_received=0
				trap confirm_SIG SIGUSR1
				kill -s USR1 $pid # inform running battery process to suspend
				for i in {1..10}; do # wait till timeout after 60 seconds
					echo -n "."
					sleep 1
				done
				if [ "$ack_received" == "1" ]; then
					logLF "Battery maintain is recovered"
					if [ "$notify" == "1" ]; then
						osascript -e 'display notification "Battery maintain is recovered" with title "Battery" sound name "Blow"'
					fi
					exit 0
				else
					logLF "Error: Battery maintain recover failed"
					if [ "$notify" == "1" ]; then
						osascript -e 'display notification "Error: Battery maintain recover failed" with title "Battery" sound name "Blow"'
					fi
					exit 1
				fi
			else
				log "Battery maintain is already running"
			fi
			exit 0
		fi
	fi

	if [[ "$setting" == "suspend" ]]; then
		if [[ "$(maintain_is_running)" == "0" ]]; then # maintain is not running
			log "Battery maintain is not running"
			exit 0
		else
			maintain_status=$(cat "$state_file" 2>/dev/null)
			if [[ "$maintain_status" == "active" ]]; then
				echo $$ > $pid_sig
				if [ "$notify" == "1" ]; then # if suspend is called by user, enable charging to 100%
					echo "suspend" > $sigfile
				else # if suspend is called by another battery process, let that process handle charging
					echo "suspend_no_charging" > $sigfile
				fi

				sleep 1

				# waiting for ack from $pid
				logn "Suspend in 5 secs, wait ."
				ack_received=0
				trap confirm_SIG SIGUSR1
				kill -s USR1 $pid # inform running battery process to suspend
				for i in {1..10}; do # wait till timeout after 60 seconds
					echo -n "."
					sleep 1
				done
				if [ "$ack_received" == "1" ]; then
					logLF "Battery maintain is suspended"
					if [ "$notify" == "1" ]; then
						osascript -e 'display notification "Battery maintain is suspended" with title "Battery" sound name "Blow"'
					fi
					exit 0
				else
					logLF "Error: Battery maintain suspend failed"
					if [ "$notify" == "1" ]; then
						osascript -e 'display notification "Error: Battery maintain suspend failed" with title "Battery" sound name "Blow"'
					fi
					exit 1
				fi
			else
				if [ "$notify" == "1" ]; then
					osascript -e 'display notification "Battery maintain is suspended" with title "Battery" sound name "Blow"'
				fi
				exit 0
			fi
		fi
	fi

	# Kill old process silently
	if test -f "$pidfile"; then
		log "Killing old maintain process at $(cat $pidfile)" >> $logfile
		pid=$(cat "$pidfile" 2>/dev/null)
		kill $pid &>/dev/null
	fi

	if [[ "$setting" == "stop" ]]; then
		log "Killing running maintain daemons & enabling charging as default state" >> $logfile
		rm $pidfile 2>/dev/null
		rm $state_file 2>/dev/null
		$battery_binary disable_daemon
		$battery_binary schedule disable
		enable_charging
		$battery_binary status
		exit 0
	fi

	# kill running calibration process
	if test -f "$calibrate_pidfile"; then
		pid=$(cat "$calibrate_pidfile" 2>/dev/null)
		kill $pid &>/dev/null
		rm $calibrate_pidfile 2>/dev/null
		log "🚨 Calibration process have been stopped"
	fi
	
	# Check if setting is value between 0 and 100
	if ! valid_percentage "$setting"; then
		# log "Called with $setting $action"
		# If non 0-100 setting is not a special keyword, exit with an error.
		if ! { [[ "$setting" == "stop" ]] || [[ "$setting" == "recover" ]]; }; then
			log "Error: $setting is not a valid setting for battery maintain. Please use a number between 0 and 100, or an action keyword like 'stop' or 'recover'."
			exit 1
		fi
	fi

	# Start maintenance script
	nohup $battery_binary maintain_synchronous $setting $subsetting $thirdsetting >> $logfile &
	log "New process ID $!" >> $logfile

	if ! [[ "$setting" == "recover" ]]; then
		# Update settings
		rm "$maintain_percentage_tracker_file" 2>/dev/null

		if ! valid_percentage $subsetting; then
			log "Writing new setting $setting to $maintain_percentage_tracker_file" >> $logfile
			echo $setting >$maintain_percentage_tracker_file
		else
			log "Writing new setting $setting $subsetting to $maintain_percentage_tracker_file" >> $logfile
			echo $setting $subsetting >$maintain_percentage_tracker_file
		fi
	fi

	# Enable the daemon that continues maintaining after reboot
	$battery_binary create_daemon

	# Enable schedule
	$battery_binary schedule enable >> $logfile

	# Report status
	$battery_binary status

	if [[ $(get_battery_percentage) > $setting ]]; then # if current battery percentage is higher than maintain percentage
		if ! [[ $(ps aux | grep $PPID) =~ "setup.sh" ]] && ! [[ $(ps aux | grep $PPID) =~ "update.sh" ]]; then 
			# Ask user if discharging right now unless this action is invoked by setup.sh
			if $is_TW; then
				answer="$(osascript -e 'display dialog "'"你要現在就放電到 $setting% 嗎?"'" buttons {"Yes", "No"} default button 1 giving up after 10 with icon note with title "BatteryOptimizer for MAC"' -e 'button returned of result')"
			else
				answer="$(osascript -e 'display dialog "'"Do you want to discharge battery to $setting% now?"'" buttons {"Yes", "No"} default button 1 giving up after 10 with icon note with title "BatteryOptimizer for MAC"' -e 'button returned of result')"
			fi
			if [[ "$answer" == "Yes" ]] || [ -z $answer ]; then
				log "Start discharging to $setting%"
				$battery_binary discharge $setting 
				$battery_binary maintain recover
			fi
		fi
	fi

	exit 0

fi

# Battery calibration
if [[ "$action" == "calibrate" ]]; then

	trap calibrate_interrupted SIGINT SIGTERM

	if ! [[ -t 0 ]]; then # if the command is not entered from stdin (terminal) by a person, meaning it is a scheduled calibration
		# check schedule to see if this week should calibrate
		schedule=$(cat "$schedule_tracker_file" 2>/dev/null)
		if [[ $schedule == *"every"* ]] && [[ $schedule == *"Week"* ]] && [[ $schedule == *"Year"* ]]; then
			week_period=$(echo $schedule | awk '{print $6}')
			week=$(echo $schedule | awk '{print $13}')
			year=$(echo $schedule | awk '{print $16}')

        	start_sec="$(echo `date -j -f "%Y-%V-%u %H:%M:%S" "$year-$week-1 00:00:00" +%s`)"
        	schedule_sec="$(echo `date -j -f "%Y-%V-%u %H:%M:%S" "$(date +%Y)-$(date +%V)-1 00:00:00" +%s`)"
			week_diff=$(( (schedule_sec - start_sec) % (week_period*7*24*60*60) ))

			#week_diff=$(((`date +%Y` - $year)*24 + `date +%V` - $week))
			#if [[ $(($week_diff % $week_period)) == 0 ]]; then
			if [[ $(( (schedule_sec - start_sec) % (week_period*7*24*60*60) )) -eq 0 ]]; then
				log "Calibrate on Week `date +%V` of Year `date +%Y`"
			else
				exit 0
			fi
		fi
	fi

	# Kill old process silently
	if test -f "$calibrate_pidfile"; then
		pid=$(cat "$calibrate_pidfile" 2>/dev/null)
		kill $pid &>/dev/null
	fi

	if [[ "$setting" == "stop" ]]; then
		log "Killing running calibration daemon" >> $logfile
		exit 0
	fi

	# make sure battery maintain is running
	if [ "$(maintain_is_running)" == "0" ]; then		
		if ! test -f "$daemon_path"; then # if daemon is not available, create one
			$battery_binary create_daemon
		fi

		# enable and reload to run battery maintain recover
		launchctl enable "gui/$(id -u $USER)/com.battery.app"
		launchctl unload "$daemon_path" 2> /dev/null
		launchctl load "$daemon_path" 2> /dev/null
	fi

	# wait till battery maintain is running
	for i in {1..10}; do
		if [ "$(maintain_is_running)" == "1" ]; then
			break
		fi
		sleep 1
	done

	# abort calibration if battery maintain is not running
	if [ "$(maintain_is_running)" == "0" ]; then
		if $is_TW; then
			osascript -e 'display notification "校正前必須先執行 battery maintain" with title "電池校正錯誤" sound name "Blow"'
		else
			osascript -e 'display notification "Battery maintain need to run before calibration" with title "Battery Calibration Error" sound name "Blow"'
		fi
		log "Calibration Error: Battery maintain need to run before calibration"
		exit 1
	fi

	# if lid is closed or AC is not connected, notify the user and wait until lid is open with AC or 1 day timeout
	if [[ $(lid_closed) == "Yes" ]] || [[ $(get_charger_connection) == "0" ]]; then
		ha_webhook "open_lid_remind"
		if $is_TW; then
			osascript -e 'display notification "準備進行電池校正, 請打開筆電上蓋並接上電源" with title "電池校正" sound name "Blow"'
		else
			osascript -e 'display notification "Please open macbook lid and connect AC to start calibration" with title "Battery Calibration" sound name "Blow"'
		fi
		
		log "Calibration: Please open macbook lid and connect AC to start calibration"
		now=$(date +%s)
		lid_open_timeout=$(($now + 24*60*60))
		while [[ $(date +%s)  -lt $lid_open_timeout ]]; do
			if [[ $(lid_closed) == "No" ]]; then
				break
			fi
			sleep 5
		done
	fi

	# check if lid is open or not
	if [[ $(lid_closed) == "Yes" ]] || [[ $(get_charger_connection) == "0" ]]; then # lid is still closed, terminate the calibration
		ha_webhook "err_lid_closed"
		if $is_TW; then
			osascript -e 'display notification "筆電上蓋沒打開或電源沒接" with title "電池校正錯誤" sound name "Blow"'
		else
			osascript -e 'display notification "Macbook lid is not open or no AC power!" with title "Battery Calibration Error" sound name "Blow"'
		fi
		log "Calibration Error: Macbook lid is not open or no AC power!"
		exit 1
	fi

	# Store pid of calibration process
	echo $$ >$calibrate_pidfile
	pid=$(cat "$calibrate_pidfile" 2>/dev/null)
	
	# check maintain percentage
	setting=$(echo $(cat $maintain_percentage_tracker_file 2>/dev/null) | awk '{print $1}')
	if [[ -z $setting ]]; then # default percentage is 80
		setting=80
	fi

	# Select calibrate method. Method 1: Discharge first. Method 2: Charge first
	method=1
	if test -f "$calibrate_method_file"; then
		method=$(cat "$calibrate_method_file" 2>/dev/null)
		if [[ "$method" != "1" ]] && [[ "$method" != "2" ]]; then # method can be 1 or 2 only
			method=1
		fi
	fi

	if [ "$method" == "1" ]; then
		ha_webhook "start" # inform HA calibration has started
		if $is_TW; then
			osascript -e 'display notification "校正開始! \n準備放電至15%" with title "電池校正" sound name "Blow"'
		else
			osascript -e 'display notification "Calibration has started! \nStart discharging to 15%" with title "Battery Calibration" sound name "Blow"'
		fi
		log  "Calibration: Calibration has started! Start discharging to 15%"

		# Suspend the maintaining
		$battery_binary maintain suspend

		# Discharge battery to 15%
		ha_webhook "discharge15_start"
		$battery_binary discharge 15 &
		wait $!
		if [[ $? != 0 ]]; then
			ha_webhook "err_discharge15"
			if $is_TW; then
				osascript -e 'display notification "未成功放電至15%" with title "電池校正錯誤" sound name "Blow"'
			else
				osascript -e 'display notification "Discharge to 15% fail" with title "Battery Calibration Error" sound name "Blow"'
			fi
			log "Calibration Error: Discharge to 15% fail"
			rm $calibrate_pidfile 2>/dev/null
			$battery_binary maintain recover # Recover old maintain status
			exit 1
		fi
		ha_webhook "discharge15_end"
		if $is_TW; then
			osascript -e 'display notification "已放電至15% \n開始充電到100%" with title "電池校正" sound name "Blow"'
		else
			osascript -e 'display notification "Calibration has discharged to 15% \nStart charging to 100%" with title "Battery Calibration" sound name "Blow"'
		fi
		log "Calibration: Calibration has discharged to 15%. Start charging to 100%"

		# Enable battery charging to 100%
		ha_webhook "charge100_start"
		enable_charging
		now=$(date +%s)
		charge100_timeout=$(($now + 6*60*60))
		while true; do
			if [[ $(date +%s) > $charge100_timeout ]]; then
				ha_webhook "err_charge100"
				if $is_TW; then
					osascript -e 'display notification "未成功在六小時內充電至100%" with title "電池校正錯誤" sound name "Blow"'
				else
					osascript -e 'display notification "Failed to charge to 100% after 6 hours" with title "Battery Calibration Error" sound name "Blow"'
				fi
				log "Calibration Error: Charge to 100% fail"
				rm $calibrate_pidfile 2>/dev/null
				$battery_binary maintain recover # Recover old maintain status
				exit 1
			fi

			# Check if battery level has reached 100%
			log "Battery at $(get_battery_percentage)% (target 100%)"
			if [ $(get_battery_percentage) == 100 ] ; then
				break
			else
				sleep 300 &
				wait $!
				continue
			fi
		done
		ha_webhook "charge100_end"
		if $is_TW; then
			osascript -e 'display notification "已充電至100% \n開始靜候一小時" with title "電池校正" sound name "Blow"'
		else
			osascript -e 'display notification "Calibration has charged to 100% \nWaiting for one hour" with title "Battery Calibration" sound name "Blow"'
		fi
		log "Calibration: Calibration has charged to 100%. Waiting for one hour"

		# Wait before discharging to target level
		sleep 3600 &
		wait $!
		ha_webhook "wait_1hr_done"
		if $is_TW; then
			osascript -e 'display notification "'"電池已維持在 100% 一小時 \n準備放電至 $setting%"'" with title "電池校正" sound name "Blow"'
		else
			osascript -e 'display notification "'"Battery has been maintained at 100% for one hour \nStart discharging to $setting%"'" with title "Battery Calibration" sound name "Blow"'
		fi
		log "Calibration: Battery has been maintained at 100% for one hour"
		log "Calibration: Start discharging to maintain percentage"

		# Discharge battery to maintain percentage%
		$battery_binary discharge $setting &
		wait $!

		if [[ $? != 0 ]]; then
			ha_webhook "err_discharge_target"
			if $is_TW; then
				osascript -e 'display notification "'"未成功放電至 $setting%"'" with title "電池校正錯誤" sound name "Blow"'
			else
				osascript -e 'display notification "'"Discharge to $setting% fail"'" with title "Battery Calibration Error" sound name "Blow"'
			fi
			log "Calibration Error: Discharge to $setting% fail"
			rm $calibrate_pidfile 2>/dev/null
			$battery_binary maintain recover # Recover old maintain status
			exit 1
		fi
	else
		ha_webhook "start" # inform HA calibration has started
		if $is_TW; then
			osascript -e 'display notification "校正開始！ \n準備充電至 100%" with title "電池校正" sound name "Blow"'
		else
			osascript -e 'display notification "Calibration has started! \nStart charging to 100%" with title "Battery Calibration" sound name "Blow"'
		fi
		log  "Calibration: Calibration has started! Start charging to 100%"

		# Suspend the maintaining
		$battery_binary maintain suspend
		
		# Enable battery charging to 100%
		enable_charging

		# Charge battery to 100%
		ha_webhook "charge100_start"

		now=$(date +%s)
		charge100_timeout=$(($now + 6*60*60))
		while true; do
			if [[ $(date +%s) > $charge100_timeout ]]; then
				ha_webhook "err_charge100"
				if $is_TW; then
					osascript -e 'display notification "未在六小時內成功充電至 100%" with title "電池校正錯誤" sound name "Blow"'
				else
					osascript -e 'display notification "Failed to charge to 100% after 6 hours" with title "Battery Calibration Error" sound name "Blow"'
				fi
				log "Calibration Error: Charge to 100% fail"
				rm $calibrate_pidfile 2>/dev/null
				$battery_binary maintain recover # Recover old maintain status
				exit 1
			fi

			# Check if battery level has reached 100%
			log "Battery at $(get_battery_percentage)% (target 100%)"
			if [ $(get_battery_percentage) == 100 ] ; then
				break
			else
				sleep 300 &
				wait $!
				continue
			fi
		done
		ha_webhook "charge100_end"
		if $is_TW; then
			osascript -e 'display notification "已充電至 100% \n開始靜候一小時" with title "電池校正" sound name "Blow"'
		else
			osascript -e 'display notification "Calibration has charged to 100% \nWaiting for one hour" with title "Battery Calibration" sound name "Blow"'
		fi
		log "Calibration: Calibration has charged to 100%. Waiting for one hour"

		# Wait before discharging to 15%
		sleep 3600 &
		wait $!
		ha_webhook "wait_1hr_done"
		
		if $is_TW; then
			osascript -e 'display notification "電池已維持在 100% 一小時 \n準備放電至 15%" with title "電池校正" sound name "Blow"'
		else
			osascript -e 'display notification "Battery has been maintained at 100% for one hour \nStart discharging to 15%" with title "Battery Calibration" sound name "Blow"'
		fi
		log "Calibration: Battery has been maintained at 100% for one hour"
		log "Calibration: Start discharging to 15%"

		# Discharge battery to 15%
		ha_webhook "discharge15_start"
		$battery_binary discharge 15
		if [[ $? != 0 ]]; then
			ha_webhook "err_discharge15"
			if $is_TW; then
				osascript -e 'display notification "未成功放電至 15%" with title "電池校正錯誤" sound name "Blow"'
			else
				osascript -e 'display notification "Discharge to 15% fail" with title "Battery Calibration Error" sound name "Blow"'
			fi
			log "Calibration Error: Discharge to 15% fail"
			rm $calibrate_pidfile 2>/dev/null
			$battery_binary maintain recover # Recover old maintain status
			exit 1
		fi
		ha_webhook "discharge15_end"
		if $is_TW; then
			osascript -e 'display notification "'"已放電至 15% \n開始充電至 $setting%"'" with title "電池校正" sound name "Blow"'
		else
			osascript -e 'display notification "'"Calibration has discharged to 15% \nStart charging to $setting%"'" with title "Battery Calibration" sound name "Blow"'
		fi
		log "Calibration: Calibration has discharged to 15%"
		log "Calibration: Start charging to maintain percentage"
		
		# Charge battery to maintain percentage%
		$battery_binary charge $setting

		if [[ $? != 0 ]]; then
			ha_webhook "err_charge_target"
			if $is_TW; then
				osascript -e 'display notification "'"未成功充電至 $setting%"'" with title "電池校正錯誤" sound name "Blow"'
			else
				osascript -e 'display notification "'"Charge to $setting% fail"'" with title "Battery Calibration Error" sound name "Blow"'
			fi
			log "Calibration Error: Charge to $setting% fail"
			rm $calibrate_pidfile 2>/dev/null
			$battery_binary maintain recover # Recover old maintain status
			exit 1
		fi
	fi

	ha_webhook "calibration_end" $(get_accurate_battery_percentage) $(get_voltage)
	
	if $is_TW; then
		osascript -e 'display notification "'"校正完成 \n電池目前 $(get_accurate_battery_percentage)%, $(get_voltage)V, $(get_battery_temperature)°C\n健康度 $(get_battery_health)%, 循環次數 $(get_cycle)"'" with title "電池校正" sound name "Blow"'
	else
		osascript -e 'display notification "'"Calibration completed.\nBattery $(get_accurate_battery_percentage)%, $(get_voltage)V, $(get_battery_temperature)°C\nHealth $(get_battery_health)%, Cycle $(get_cycle)"'" with title "Battery Calibration" sound name "Blow"'
	fi
	log "Calibration completed."
	log "Battery $(get_accurate_battery_percentage)%, $(get_voltage)V, $(get_battery_temperature)°C"
	log "Health $(get_battery_health)%, Cycle $(get_cycle)"	
	
	rm $calibrate_pidfile 2>/dev/null
	$battery_binary maintain recover # Recover old maintain status
	exit 0
fi

# Status logger
if [[ "$action" == "status" ]]; then

	echo
	if $is_TW; then
		case $(get_charging_status) in
			"0")
				log "電池目前 $(get_accurate_battery_percentage)%, $(get_voltage)V, $(get_battery_temperature)°C, 暫停充電";;
			"1")
				log "電池目前 $(get_accurate_battery_percentage)%, $(get_voltage)V, $(get_battery_temperature)°C, 充電中";;
			"2")
				log "電池目前 $(get_accurate_battery_percentage)%, $(get_voltage)V, $(get_battery_temperature)°C, 放電中";;
		esac

		log "電池健康度 $(get_battery_health)%, 循環次數 $(get_cycle)"
	else
		case $(get_charging_status) in
			"0")
				log "Battery at $(get_accurate_battery_percentage)%, $(get_voltage)V, $(get_battery_temperature)°C, no charging";;
			"1")
				log "Battery at $(get_accurate_battery_percentage)%, $(get_voltage)V, $(get_battery_temperature)°C, charging";;
			"2")
				log "Battery at $(get_accurate_battery_percentage)%, $(get_voltage)V, $(get_battery_temperature)°C, discharging";;
		esac
		log "Battery health $(get_battery_health)%, Cycle $(get_cycle)"
	fi

	if [[ "$(maintain_is_running)" == "1" ]]; then
		maintain_percentage=$(cat $maintain_percentage_tracker_file 2>/dev/null)
		maintain_status=$(cat $state_file 2>/dev/null)
		if [[ "$maintain_status" == "active" ]]; then
			if [[ $maintain_percentage ]]; then
				upper_limit=$(echo $maintain_percentage | awk '{print $1}')
				lower_limit=$(echo $maintain_percentage | awk '{print $2}')
				if [[ $upper_limit ]]; then
					if ! valid_percentage "$lower_limit"; then
						lower_limit=$((upper_limit-5))
					fi
					if $is_TW; then
						maintain_level=$(echo "$upper_limit"% 滑行至 "$lower_limit"%)
					else
						maintain_level=$(echo "$upper_limit"% with sailing to "$lower_limit"%)
					fi
				fi
			fi
			if $is_TW; then
				log "您的電池最佳化維持在 $maintain_level"
			else
				log "Your battery is currently being maintained at $maintain_level"
			fi
		else
			if $is_TW; then
				if [[ "$(calibrate_is_running)" == "1" ]]; then
					log "校正進行中，電池最佳化已暫停"
				else
					log "電池最佳化已暫停"
				fi
			else
				if [[ "$(calibrate_is_running)" == "1" ]]; then
					log "Calibration ongoing, battery maintain is suspended"
				else
					log "Battery maintain is suspended" 
				fi
			fi
		fi
	else
		if $is_TW; then
			log "電池最佳化已經停止運作"
		else
			log "Battery maintain is not running"
		fi
	fi
	
	show_schedule

	echo
	exit 0

fi

# Status logger in csv format
if [[ "$action" == "status_csv" ]]; then

	maintain_percentage=$(cat $maintain_percentage_tracker_file 2>/dev/null)
	maintain_percentage=$(echo $maintain_percentage | awk '{print $1}')
	echo "$(get_battery_percentage),$(get_remaining_time),$(get_smc_charging_status),$(get_smc_discharging_status),$maintain_percentage"

fi

# launchd daemon creator, inspiration: https://www.launchd.info/
if [[ "$action" == "create_daemon" ]]; then

	call_action="maintain_synchronous"

	daemon_definition="
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
	<dict>
		<key>Label</key>
		<string>com.battery.app</string>
		<key>ProgramArguments</key>
		<array>
			<string>$binfolder/battery</string>
			<string>$call_action</string>
			<string>recover</string>
		</array>
		<key>StandardOutPath</key>
		<string>$logfile</string>
		<key>StandardErrorPath</key>
		<string>$logfile</string>
		<key>RunAtLoad</key>
		<true/>
	</dict>
</plist>
"

	mkdir -p "${daemon_path%/*}"

	# check if daemon already exists
	if test -f "$daemon_path"; then

		log "Daemon already exists, checking for differences" >> $logfile
		daemon_definition_difference=$(diff --brief --ignore-space-change --strip-trailing-cr --ignore-blank-lines <(cat "$daemon_path" 2>/dev/null) <(echo "$daemon_definition"))

		# remove leading and trailing whitespaces
		daemon_definition_difference=$(echo "$daemon_definition_difference" | xargs)
		if [[ "$daemon_definition_difference" != "" ]]; then

			log "daemon_definition changed: replace with new definitions" >> $logfile
			echo "$daemon_definition" >"$daemon_path"

		fi
	else

		# daemon not available, create new launch deamon
		log "Daemon does not yet exist, creating daemon file at $daemon_path" >> $logfile
		echo "$daemon_definition" >"$daemon_path"

	fi

	# enable daemon
	launchctl enable "gui/$(id -u $USER)/com.battery.app"
	exit 0

fi

# Disable daemon
if [[ "$action" == "disable_daemon" ]]; then

	log "Disabling daemon at gui/$(id -u $USER)/com.battery.app" >> $logfile
	launchctl disable "gui/$(id -u $USER)/com.battery.app"
	exit 0

fi

# Remove daemon
if [[ "$action" == "remove_daemon" ]]; then

	rm $daemon_path 2>/dev/null
	exit 0

fi

# Calibrate schedule 
if [[ "$action" == "schedule" ]]; then
	n_days=0
	day_start=0
	#is_weekday=0 
	#is_week_period=0
	#is_month_period=0
	#is_hour=0
	#is_minute=0
	days[0]=1
	days[1]=
	days[2]=
	days[3]=
	weekday=
	week_period=4
	month_period=1
	hour=9
	minute=0

	if [ $2 == "disable" ]; then
		if test -f $schedule_tracker_file; then
			if $is_TW; then
				log "電池自動校正時程已暫停"
				echo
			else
				log "Schedule disabled"
				echo
			fi
			log "Disabling schedule at gui/$(id -u $USER)/com.battery_schedule.app" >> $logfile
			launchctl disable "gui/$(id -u $USER)/com.battery_schedule.app"
		fi
		exit 0
	fi

	if [ $2 == "enable" ]; then
		enable_exist="$(launchctl print gui/$(id -u $USER) | grep "=> enabled")"
		if [[ $enable_exist ]]; then # new version that replace => false with => enabled
			schedule_enabled="$(launchctl print gui/$(id -u $USER) | grep enabled | grep "com.battery_schedule.app")"
		else # old version that use => false
			schedule_enabled="$(launchctl print gui/$(id -u $USER) | grep "=> false" | grep "com.battery_schedule.app")"
			schedule_enabled=${schedule_enabled/false/enabled}
		fi
		if ! [[ $schedule_enabled =~ "enabled" ]]; then
			if test -f $schedule_tracker_file; then
				log "Enabling schedule at gui/$(id -u $USER)/com.battery_schedule.app" >> $logfile
				launchctl enable "gui/$(id -u $USER)/com.battery_schedule.app"
			fi
		fi
		show_schedule
		exit 0
	fi

	schedule_day=$@
	schedule_day=${schedule_day/weekday}
    day_loc=$(echo "$schedule_day" | tr " " "\n" | grep -n "day" | cut -d: -f1)
	weekday_loc=$(echo "$@" | tr " " "\n" | grep -n "weekday" | cut -d: -f1)
    month_period_loc=$(echo "$@" | tr " " "\n" | grep -n "month_period" | cut -d: -f1)
	week_period_loc=$(echo "$@" | tr " " "\n" | grep -n "week_period" | cut -d: -f1)
    hour_loc=$(echo "$@" | tr " " "\n" | grep -n "hour" | cut -d: -f1)
    minute_loc=$(echo "$@" | tr " " "\n" | grep -n "minute" | cut -d: -f1)
    n_words=$(echo "$@" | awk '{print NF}')

	if [[ $weekday_loc ]]; then
		weekday=$(echo $@ | awk '{print $"'"$((weekday_loc+1))"'"}');
		valid_weekday $weekday || { log "Error: weekday must be in [0..6]"; exit 1;}
	fi

	if [[ $month_period_loc ]]; then
		month_period=$(echo $@ | awk '{print $"'"$((month_period_loc+1))"'"}');
		valid_month_period $month_period || { log "Error: month_period must be in [1..3]"; exit 1;}
	fi

	if [[ $week_period_loc ]]; then
		week_period=$(echo $@ | awk '{print $"'"$((week_period_loc+1))"'"}');
		valid_week_period $week_period || { log "Error: week_period must be in [1..12]"; exit 1;}
	fi

	if [[ $hour_loc ]]; then
		hour=$(echo $@ | awk '{print $"'"$((hour_loc+1))"'"}');
		valid_hour $hour || { log "Error: hour must be in [0..23]"; exit 1;}
	fi

	if [[ $minute_loc ]]; then
		minute=$(echo $@ | awk '{print $"'"$((minute_loc+1))"'"}');
		valid_minute $minute || { log "Error: minute must be in [0..59]"; exit 1;}
	fi
	
	if [[ $day_loc ]]; then
		for i_day in {1..4}; do
			value=$(echo $schedule_day | awk '{print $"'"$((day_loc+i_day))"'"}')
			if valid_day $value; then
				days[$n_days]=$value
				n_days=$(($n_days+1))
			else
				if [[ $value -eq 29 ]] || [[ $value -eq 30 ]] || [[ $value -eq 31 ]]; then
					log "Error: day must be in [1..28]"
					exit 1
				fi
				break
			fi
		done 
	fi

	#for arg in $@; do
	#	# set day
	#	if [[ $day_start -eq 1 ]] && [[ $n_days < 4 ]]; then
	#		if valid_day $arg; then
	#			days[$n_days]=$arg
	#			n_days=$(($n_days+1))
	#		else # not valid days
	#			day_start=0 
	#		fi
	#	fi

	#	# search "day"
	#	if [ $arg == "day" ]; then
	#		day_start=1
	#	fi

	#	# set weekday
	#	if [ $is_weekday == 1 ]; then
	#		if valid_weekday $arg; then		
	#			weekday=$arg
	#			is_weekday=0
	#		else
	#			log "Error: weekday must be in [0..6]"
	#			exit 1
	#		fi
	#	fi

	#	# search "weekday"
	#	if [ $arg == "weekday" ]; then
	#		is_weekday=1
	#	fi

	#	# set week_period
	#	if [ $is_week_period == 1 ]; then
	#		if valid_week_period $arg; then		
	#			week_period=$arg
	#			is_week_period=0
	#		else
	#			log "Error: week_period must be in [1..4]"
	#			exit 1
	#		fi
	#	fi

	#	# search "week_period"
	#	if [ $arg == "week_period" ]; then
	#		is_week_period=1
	#	fi

	#	# set month_period
	#	if [ $is_week_period == 1 ]; then
	#		if valid_week_period $arg; then		
	#			week_period=$arg
	#			is_week_period=0
	#		else
	#			log "Error: week_period must be in [1..4]"
	#			exit 1
	#		fi
	#	fi

	#	# search "week_period"
	#	if [ $arg == "week_period" ]; then
	#		is_week_period=1
	#	fi

	#	# set hour
	#	if [ $is_hour == 1 ]; then
	#		if valid_hour $arg; then		
	#			hour=$arg
	#			is_hour=0
	#		else
	#			log "Error: hour must be in [0..23]"
	#			exit 1
	#		fi
	#	fi

	#	# search "hour"
	#	if [ $arg == "hour" ]; then
	#		is_hour=1
	#	fi

	#	# set minute
	#	if [ $is_minute == 1 ]; then
	#		if valid_minute $arg; then
	#			minute=$arg
	#			is_minute=0
	#		else
	#			log "Error: minute must be in [0..59]"
	#			exit 1
	#		fi
	#	fi

	#	# search "minute"
	#	if [ $arg == "minute" ]; then
	#		is_minute=1
	#	fi
	#done

	if [[ $n_days == 0 ]] && [[ -z $weekday ]]; then # default is calibrate 1 day per month if day and weekday is not specified
		n_days=1
	elif [[ $weekday ]]; then # weekday
		case $weekday in 
			0) weekday_name=SUN ;;
			1) weekday_name=MON ;;
			2) weekday_name=TUE ;;
			3) weekday_name=WED ;;
			4) weekday_name=THU ;;
			5) weekday_name=FRI ;;
			6) weekday_name=SAT ;;
		esac
	fi

	if [ $minute -lt 10 ]; then
		minute00=0$(echo $minute | tr -d '0')
		if [ "$minute00" == "0" ]; then
			minute00="00"
		fi
	else
		minute00=$minute
	fi

	if [[ $n_days > 0 ]] && [[ -z $weekday ]]; then
		if [[ $month_period -eq 1 ]]; then
			log "Schedule calibration on day ${days[*]} at $hour:$minute00" >> $logfile
			echo "Schedule calibration on day ${days[*]} at $hour:$minute00" > $schedule_tracker_file
		else
			n_days=1
			log "Schedule calibration on day ${days[0]} every $month_period month at $hour:$minute00 starting from Month `date +%m` of Year `date +%Y`" >> $logfile
			echo "Schedule calibration on day ${days[0]} every $month_period month at $hour:$minute00 starting from Month `date +%m` of Year `date +%Y`" > $schedule_tracker_file
		fi
	else
		log "Schedule calibration on $weekday_name every $week_period week at $hour:$minute00 starting from Week `date +%V` of Year `date +%Y`" >> $logfile
		echo "Schedule calibration on $weekday_name every $week_period week at $hour:$minute00 starting from Week `date +%V` of Year `date +%Y`" > $schedule_tracker_file
	fi

	# create schedule file
	call_action="calibrate"

	schedule_definition="
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
	<dict>
		<key>Label</key>
		<string>com.battery_schedule.app</string>
		<key>ProgramArguments</key>
		<array>
			<string>$binfolder/battery</string>
			<string>$call_action</string>
		</array>
		<key>StartCalendarInterval</key>
		<array>	
"
	if [[ $n_days > 0 ]]; then
		for i in $(seq 1 $n_days); do
			schedule_definition+="			<dict>
				<key>Day</key>
				<integer>${days[$((i-1))]}</integer>
				<key>Hour</key>
				<integer>$hour</integer>
				<key>Minute</key>
				<integer>$minute</integer>
			</dict>
"
		done
	else # weekday
		schedule_definition+="			<dict>
				<key>Weekday</key>
				<integer>$weekday</integer>
				<key>Hour</key>
				<integer>$hour</integer>
				<key>Minute</key>
				<integer>$minute</integer>
			</dict>
"
	fi
	schedule_definition+="		</array>
		<key>StandardOutPath</key>
		<string>$logfile</string>
		<key>StandardErrorPath</key>
		<string>$logfile</string>
	</dict>
</plist>
"

	mkdir -p "${schedule_path%/*}"

	# check if schedule already exists
	if test -f "$schedule_path"; then

		log "Schedule already exists, checking for differences" >> $logfile
		schedule_definition_difference=$(diff --brief --ignore-space-change --strip-trailing-cr --ignore-blank-lines <(cat "$schedule_path" 2>/dev/null) <(echo "$schedule_definition"))

		# remove leading and trailing whitespaces
		schedule_definition_difference=$(echo "$schedule_definition_difference" | xargs)
		if [[ "$schedule_definition_difference" != "" ]]; then

			log "schedule_definition changed: replace with new definitions" >> $logfile
			echo "$schedule_definition" >"$schedule_path"

		fi
	else

		# schedule not available, create new launch deamon
		log "Schedule does not yet exist, creating schedule file at $schedule_path" >> $logfile
		echo "$schedule_definition" >"$schedule_path"

	fi

	# enable schedule
	launchctl enable "gui/$(id -u $USER)/com.battery_schedule.app"
	launchctl unload "$schedule_path" 2> /dev/null
	launchctl load "$schedule_path" 2> /dev/null

	echo

	show_schedule

	echo
	exit 0
fi


# Display logs
if [[ "$action" == "logs" ]]; then

	amount="${2:-100}"

	echo -e "👾 Battery CLI logs:\n"
	tail -n $amount $logfile

	echo -e "\n🖥️	Battery GUI logs:\n"
	tail -n $amount "$configfolder/gui.log"

	echo -e "\n📁 Config folder details:\n"
	ls -lah $configfolder

	echo -e "\n⚙️	Battery data:\n"
	$battery_binary status
	$battery_binary | grep -E "v\d.*"

	exit 0

fi

# Display logs
if [[ "$action" == "dailylog" ]]; then

	echo
	echo -e "Daily log ($daily_log)\n"
	echo "$(cat $daily_log 2>/dev/null)"
	echo

	exit 0

fi

# Show changelog of the latest version
if [[ "$action" == "changelog" ]]; then

	button_empty="                                                                                                                                                    "
	if $is_TW; then
		changelog=$(get_changelog CHANGELOG_TW)
		battery_new_version=$(get_version CHANGELOG_TW)
		osascript -e 'display dialog "'"$battery_new_version 更新內容如下\n\n$changelog"'" buttons {"'"$button_empty"'", "OK"} default button 2 with icon note with title "BatteryOptimizer for MAC"' >> /dev/null
	else
		changelog=$(get_changelog CHANGELOG)
		battery_new_version=$(get_version CHANGELOG)
		osascript -e 'display dialog "'"$battery_new_version changes inlude\n\n$changelog"'" buttons {"'"$button_empty"'", "OK"} default button 2 with icon note with title "BatteryOptimizer for MAC"' >> /dev/null
	fi
	exit 0
fi


# Show version
if [[ "$action"  == "version" ]]; then
	echo -e "$BATTERY_CLI_VERSION"
	exit 0
fi


# Set language
if [[ "$action"  == "language" ]]; then
	if [[ "$2" == "tw" ]]; then
		echo $2 > $language_file
		log "顯示語言改為繁體中文"
	elif [[ "$2" == "us" ]]; then
		echo $2 > $language_file
		log "Change language to English"
	else
		log "Specified language is not recognized. Only [tw, us] are allowed"
	fi
	exit 0
fi
