#!/bin/bash

## ###############
## Update management
## variables are used by this binary as well at the update script
## ###############
BATTERY_CLI_VERSION="v2.0.28"
BATTERY_VISUDO_VERSION="v1.0.4"

# Path fixes for unexpected environments
PATH=/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

## ###############
## Variables
## ###############
binfolder=/usr/local/bin
visudo_folder=/private/etc/sudoers.d
visudo_file=${visudo_folder}/battery
configfolder=$HOME/.battery
config_file=$configfolder/config_battery
pidfile=$configfolder/battery.pid
logfile=$configfolder/battery.log
pid_sig=$configfolder/sig.pid
daemon_path=$HOME/Library/LaunchAgents/battery.plist
calibrate_pidfile=$configfolder/calibrate.pid
schedule_path=$HOME/Library/LaunchAgents/battery_schedule.plist
shutdown_path=$HOME/Library/LaunchAgents/battery_shutdown.plist
daily_log=$configfolder/daily.log
calibrate_log=$configfolder/calibrate.log
ssd_log=$configfolder/ssd.log
github_link="https://raw.githubusercontent.com/js4jiang5/BatteryOptimizer_for_MAC/main"

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
# CLI help and i18n helpers are loaded from i18n/battery_i18n.sh

# Load i18n catalog/helpers from installed config path or local repo path
battery_i18n_loaded=false
battery_i18n_candidates=(
  "$configfolder/i18n/battery_i18n.sh"
  "$(cd "$(dirname "$0")" 2>/dev/null && pwd)/i18n/battery_i18n.sh"
)
for battery_i18n_file in "${battery_i18n_candidates[@]}"; do
  if [[ -f "$battery_i18n_file" ]]; then
    # shellcheck disable=SC1090
    source "$battery_i18n_file"
    battery_i18n_loaded=true
    break
  fi
done
if ! $battery_i18n_loaded; then
  echo "Error: battery i18n file not found. Expected at ~/.battery/i18n/battery_i18n.sh or next to battery.sh." >&2
  exit 1
fi

# Visudo instructions
visudoconfig="
# Visudo settings for the battery utility installed from https://github.com/js4jiang5/BatteryOptimizer_for_MAC
# intended to be placed in $visudo_file on a mac
Cmnd_Alias      BATTERYOFF = $binfolder/smc -k CH0B -w 02, $binfolder/smc -k CH0C -w 02, $binfolder/smc -k CHTE -w 01000000, $binfolder/smc -k CH0B -r, $binfolder/smc -k CH0C -r, $binfolder/smc -k CHTE -r
Cmnd_Alias      BATTERYON = $binfolder/smc -k CH0B -w 00, $binfolder/smc -k CH0C -w 00, $binfolder/smc -k CHTE -w 00000000
Cmnd_Alias      DISCHARGEOFF = $binfolder/smc -k CH0I -w 00, $binfolder/smc -k CH0I -r, $binfolder/smc -k CH0J -w 00, $binfolder/smc -k CH0J -r, $binfolder/smc -k CH0K -w 00, $binfolder/smc -k CH0K -r, $binfolder/smc -k CHIE -w 00, $binfolder/smc -k CHIE -r, $binfolder/smc -d off
Cmnd_Alias      DISCHARGEON = $binfolder/smc -k CH0I -w 01, $binfolder/smc -k CH0J -w 01, $binfolder/smc -k CH0K -w 01, $binfolder/smc -k CHIE -w 08, $binfolder/smc -d on
Cmnd_Alias      LEDCONTROL = $binfolder/smc -k ACLC -w 04, $binfolder/smc -k ACLC -w 03, $binfolder/smc -k ACLC -w 02, $binfolder/smc -k ACLC -w 01, $binfolder/smc -k ACLC -w 00, $binfolder/smc -k ACLC -r
Cmnd_Alias      BATTERYBCLM = $binfolder/smc -k BCLM -w 0a, $binfolder/smc -k BCLM -w 64, $binfolder/smc -k BCLM -r
Cmnd_Alias      BATTERYCHWA = $binfolder/smc -k CHWA -w 00, $binfolder/smc -k CHWA -w 01, $binfolder/smc -k CHWA -r
Cmnd_Alias      BATTERYACEN = $binfolder/smc -k ACEN -w 00, $binfolder/smc -k ACEN -w 01, $binfolder/smc -k ACEN -r
Cmnd_Alias      BATTERYBFCL = $binfolder/smc -k BFCL -w 00, $binfolder/smc -k BFCL -w 5f, $binfolder/smc -k BFCL -r
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
ALL ALL = NOPASSWD: BATTERYBFCL
ALL ALL = NOPASSWD: BATTERYCHBI
ALL ALL = NOPASSWD: BATTERYB0AC
"

# Get parameters
battery_binary=$0
action=$1
setting=$2
subsetting=$3
thirdsetting=$4

# check the availability of SMC keys
[[ $(smc -k BCLM -r) =~ "no data" ]] && has_BCLM=false || has_BCLM=true;
[[ $(smc -k CH0B -r) =~ "no data" ]] && has_CH0B=false || has_CH0B=true;
[[ $(smc -k CH0C -r) =~ "no data" ]] && has_CH0C=false || has_CH0C=true;
[[ $(smc -k CH0I -r) =~ "no data" ]] && has_CH0I=false || has_CH0I=true;
[[ $(smc -k CH0J -r) =~ "no data" || $(smc -k CH0J -r) =~ "Error" ]] && has_CH0J=false || has_CH0J=true;
[[ $(smc -k CH0K -r) =~ "no data" ]] && has_CH0K=false || has_CH0K=true;
[[ $(smc -k ACEN -r) =~ "no data" ]] && has_ACEN=false || has_ACEN=true;
[[ $(smc -k ACLC -r) =~ "no data" ]] && has_ACLC=false || has_ACLC=true;
[[ $(smc -k CHWA -r) =~ "no data" ]] && has_CHWA=false || has_CHWA=true;
[[ $(smc -k BFCL -r) =~ "no data" ]] && has_BFCL=false || has_BFCL=true;
[[ $(smc -k ACFP -r) =~ "no data" ]] && has_ACFP=false || has_ACFP=true;
[[ $(smc -k CHTE -r) =~ "no data" ]] && has_CHTE=false || has_CHTE=true;
[[ $(smc -k CHIE -r) =~ "no data" ]] && has_CHIE=false || has_CHIE=true;

## ###############
## Helpers
## ###############


function valid_action() {
    local action=$1
    
    # List of valid actions
    VALID_ACTIONS=("" "visudo" "maintain" "calibrate" "schedule" "charge" "discharge" 
	"status" "dailylog" "calibratelog" "logs" "language" "update" "version" "reinstall" "uninstall" 
	"maintain_synchronous" "status_csv" "create_daemon" "disable_daemon" "remove_daemon" "changelog" "ssd" "ssdlog")
    
    VALID_ACTIONS_USER=("" "visudo" "maintain" "calibrate" "schedule" "charge" "discharge" 
	"status" "dailylog" "calibratelog" "logs" "language" "update" "version" "reinstall" "uninstall" "changelog" "ssd" "ssdlog")

    # Check if action is valid
    local action_valid=false
    for valid_action in "${VALID_ACTIONS[@]}"; do
        if [[ "$action" == "$valid_action" ]]; then
            action_valid=true
            break
        fi
    done
    
    if ! $action_valid; then
        echo "$(i18n_format invalid_action "$action")"
        echo "$(i18n_text did_you_mean)"
        for valid_action in "${VALID_ACTIONS_USER[@]}"; do
            if [[ "$valid_action" == *"${action:0:3}"* ]]; then
                echo "  - $valid_action"
            fi
        done
        echo "$(i18n_text run_battery_help)"
        return 1
    fi
    
    return 0
}

function ha_webhook() {
	DST=http://homeassistant.local:8123
	WEBHOOKID=$(read_config webhookid)
	if [[ $WEBHOOKID ]]; then
		if [ $4 ]; then
			curl -sS -X POST \
			-H "Content-Type: application/json"\
			-d "{\"stage\": \"$1\" , \"battery\": \"$2\" , \"voltage\": \"$3\" , \"health\": \"$4\"}" \
			$DST/api/webhook/$WEBHOOKID 
		elif [ $3 ]; then
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
	schedule=$(read_config calibrate_schedule)
	if [[ -z $schedule ]]; then
		echo 0
		return
	fi

	LANG=en_us_8859_1
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
		if [[ $((10#$(date +%V))) -eq 1 ]]; then # Week 1 is special, need to check if it is valid
			if [[ `date -v+7d +%Y` -gt `date +%Y` ]]; then # cross year for Week 1 if year is different after 7 days
        		schedule_sec="$(echo `date -j -f "%Y-%V-%u %H:%M:%S" "$(date +%Y)-$((10#$(date -v-7d +%V)+1))-$weekday $hour:$minute:00" +%s`)"
			elif [[ $weekday -lt `date +%u` ]]; then # weekday is before today that might be invalid for Week 1
				schedule_sec="$(echo `date -j -f "%Y-%V-%u %H:%M:%S" "$(date +%Y)-$((10#$(date +%V)+1))-$weekday $hour:$minute:00" +%s`)"
			else
				schedule_sec="$(echo `date -j -f "%Y-%V-%u %H:%M:%S" "$(date +%Y)-$(date +%V)-$weekday $hour:$minute:00" +%s`)"
			fi
		else
			schedule_sec="$(echo `date -j -f "%Y-%V-%u %H:%M:%S" "$(date +%Y)-$(date +%V)-$weekday $hour:$minute:00" +%s`)"
		fi
        now=`date +%s`
		for i in {0..12}; do # at most 12 weeks
			schedule_diff_sec=$((schedule_sec - start_sec))
			mod=$((schedule_diff_sec % (week_period*7*24*60*60)))
			
			# take into consideration daylight saving time of advance or lag of 1 hour
			if (( (mod <= 3600 || mod >= $(( week_period*7*24*60*60 - 3600))) && schedule_sec > now )); then
				# adjust hour for daylight saving time
				hour_schedule=`date -j -f "%s" "$schedule_sec" +%H`
				hour_diff=$(( 10#$hour_schedule - 10#$hour ))
				if (( hour_diff == 1 || hour_diff == -23 )); then # adjust for advance of 1 hour
					next_s=$(( schedule_sec - 3600 ))
				elif (( hour_diff == -1 || hour_diff == 23 )); then # adjust for lag of 1 hour
					next_s=$(( schedule_sec + 3600 ))
				else
					next_s=$schedule_sec
				fi
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
			month_diff=$(((`date +%Y` - $year)*12 + 10#`date +%m` - 10#$month))
		else # calibrate every month case
			month_period=1 
			month_diff=0
		fi

		now=`date +%s`

		diff_min=$((86400*100)) # need to find the min in case users put larger day in front
		for i_month in {0..3}; do # at most 3 months
			if [[ $((($month_diff + $i_month) % $month_period)) -eq 0 ]]; then
				for i_day in $(seq 0 $((n_days-1))); do # check this month
					if [[ $((10#`date +%m` + i_month)) -gt 12 ]]; then # cross year
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
	schedule_txt="$(read_config calibrate_schedule)"
	if [[ $schedule_enabled =~ "enabled" ]]; then
		if [[ $schedule_txt ]]; then
			log "$(i18n_schedule_display_text "$schedule_txt")"
			next_calibration_date="$(date -j -f "%s" "$(echo $(check_next_calibration_date) | awk '{print $NF}')" +%Y/%m/%d)"
			i18n_log schedule_next_date "$next_calibration_date"
		else
			i18n_log schedule_not_set
		fi
	else
		if [[ $schedule_txt ]]; then
			i18n_log schedule_disabled_enable_by
			log "battery schedule enable"
		else
			i18n_log schedule_not_set
		fi
	fi
}

## #################
## SMC Manipulation
## #################

# Change magsafe color
# see community sleuthing: https://github.com/actuallymentor/battery/issues/71
function change_magsafe_led_color() {
	color=$1

	if [[ "$color" == "auto" ]]; then
		charging_status=$(get_charging_status)
		if $has_ACLC; then 
			color=$(read_smc_hex ACLC); 
			if [ "$charging_status" == "1" ] && [ "$color" != "04" ] ; then # orange for charging
				color="orange"
			elif [ "$charging_status" == "0" ] && [ "$color" != "03" ] ; then # green for not charging
				color="green"
			elif [ "$charging_status" == "2" ] && [ "$color" != "01" ] ; then # none for discharging
				color="none"
			else
				return 0
			fi
		elif $has_BFCL; then
			color=$(read_smc_hex BFCL); 
			if [ "$charging_status" == "1" ] && [ "$color" != "5f" ] ; then # orange for charging
				color="orange"
			elif [ "$charging_status" == "0" ] && [ "$color" != "00" ] ; then # green for not charging
				color="green"
			else
				return 0
			fi
		else
			return 0
		fi
	fi

	if $has_ACLC || $has_BFCL; then
		#log "MagSafe LED function invoked"
		log "💡 Setting magsafe color to $color"
	else
		return 0
	fi

	if [[ "$color" == "green" ]]; then
		#log "setting LED to green"
		if $has_ACLC; then sudo smc -k ACLC -w 03; fi
		if $has_BFCL; then sudo smc -k BFCL -w 00; fi
	elif [[ "$color" == "orange" ]]; then
		#log "setting LED to orange"
		if $has_ACLC; then sudo smc -k ACLC -w 04; fi
		if $has_BFCL; then sudo smc -k BFCL -w 5f; fi
	elif [[ "$color" == "none" ]]; then
		#log "setting LED to none"
		if $has_ACLC; then sudo smc -k ACLC -w 01; fi
		if $has_BFCL; then sudo smc -k BFCL -w 5f; fi
	else
		# Default action: reset. Value 00 is a guess and needs confirmation
		#log "resetting LED"
		if $has_ACLC; then sudo smc -k ACLC -w 00; fi
		if $has_BFCL; then sudo smc -k BFCL -w 00; fi
	fi
}

# Re:discharging, we're using keys uncovered by @howie65: https://github.com/actuallymentor/battery/issues/20#issuecomment-1364540704
# CH0I seems to be the "disable the adapter" key
function enable_discharging() {
	disable_charging
	log "🔽🪫 Enabling battery discharging"
	if [[ $(get_cpu_type) == "apple" ]]; then
		if $has_CH0I; then 
			sudo smc -k CH0I -w 01;
		else
			if $has_CH0J; then sudo smc -k CH0J -w 01; fi
			if $has_CHIE; then sudo smc -k CHIE -w 08; fi
		fi
		if $has_ACLC; then sudo smc -k ACLC -w 01; fi
	else
		if $has_BCLM; then sudo smc -k BCLM -w 0a; fi
		if $has_ACEN; then sudo smc -k ACEN -w 00; fi
	fi
	sleep 1
}

function disable_discharging() {
	log "🔼🪫 Disabling battery discharging"
	if [[ $(get_cpu_type) == "apple" ]]; then
		if $has_CH0I; then 
			sudo smc -k CH0I -w 00;
		else
			if $has_CH0J; then sudo smc -k CH0J -w 00; fi
			if $has_CHIE; then sudo smc -k CHIE -w 00; fi
		fi
	else
		if $has_ACEN; then sudo smc -k ACEN -w 01; fi
	fi
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
	disable_discharging
	log "🔌🔋 Enabling battery charging"
	if [[ $(get_cpu_type) == "apple" ]]; then
		if $has_CH0B; then sudo smc -k CH0B -w 00; fi
		if $has_CH0C; then sudo smc -k CH0C -w 00; fi
		if $has_CHTE && ! $has_CH0B; then sudo smc -k CHTE -w 00000000; fi
	else
		if $has_BCLM; then sudo smc -k BCLM -w 64; fi
	fi
	sleep 1
}

function disable_charging() {
	log "🔌🪫 Disabling battery charging"
	if [[ $(get_cpu_type) == "apple" ]]; then
		if $has_CH0B; then sudo smc -k CH0B -w 02; fi
		if $has_CH0C; then sudo smc -k CH0C -w 02; fi
		if $has_CHTE && ! $has_CH0B; then sudo smc -k CHTE -w 01000000; fi
	else
		if $has_BCLM; then sudo smc -k BCLM -w 0a; fi
	fi
	sleep 1
}

function get_smc_charging_status() {
	if [[ $(get_cpu_type) == "apple" ]]; then
		if $has_CH0C; then
			hex_status=$(read_smc_hex CH0C)
			if [[ "$hex_status" == "00" ]]; then
				echo "enabled"
			else
				echo "disabled"
			fi
		else
			if $has_CHTE; then
				hex_status=$(read_smc_hex CHTE)
				if [[ "$hex_status" == "00000000" ]]; then
					echo "enabled"
				else
					echo "disabled"
				fi
			else
				echo "enabled"
			fi
		fi
	else
		bclm_hex_status=$(read_smc_hex BCLM)
		acen_hex_status=$(read_smc_hex ACEN)
		if [[ "$bclm_hex_status" == "64" ]] && [[ "$acen_hex_status" == "01" ]]; then
			echo "enabled"
		else
			echo "disabled"
		fi
	fi
}

function get_smc_discharging_status() {
	if [[ $(get_cpu_type) == "apple" ]]; then
		if $has_CH0I; then
			hex_status=$(read_smc_hex CH0I)
			if [[ "$hex_status" == "00" ]]; then
				echo "not discharging"
			else
				echo "discharging"
			fi
		elif $has_CH0J; then
			hex_status=$(read_smc_hex CH0J)
			if [[ "$hex_status" == "00" ]]; then
				echo "not discharging"
			else
				echo "discharging"
			fi
		elif $has_CHIE; then
			hex_status=$(read_smc_hex CHIE)
			if [[ "$hex_status" == "00" ]]; then
				echo "not discharging"
			else
				echo "discharging"
			fi
		else
			echo "not discharging"
		fi
	else
		acen_hex_status=$(read_smc_hex ACEN)
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
	battery_percentage=$(read_smc BRSC)
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
		charge_current=$(read_smc CHBI)
		discharge_current=$(read_smc B0AC)
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
	maintain_percentage=$(read_config maintain_percentage)
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
	ac_attached=$(pmset -g batt | head -n1 | awk '{ x=match($0, /AC Power/) > 0; print x }')
	discharge_current=$(read_smc B0AC)
	if $has_ACFP; then
		acfp=$(read_smc ACFP)
	else
		acfp=0
	fi
	
	if [[ $discharge_current == "0" ]]; then
		not_discharging=1
	else
		not_discharging=0
	fi
	ac_connected=$(($ac_attached || $not_discharging || $acfp > 0 ))
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

function get_parameter() { # get parameter value from configuration file. the format is var=value or var= value or var = value
	var_loc=$(echo $(echo "$1" | tr " " "\n" | grep -n "$2" | cut -d: -f1) | awk '{print $1}')
	if [ -z $var_loc ]; then
		echo
	else
		echo $1 | awk '{print $"'"$((var_loc))"'"}' | tr '=' ' ' | awk '{print $2}'
	fi
}

function get_changelog() { # get the latest changelog
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
		if [[ $line =~ "." ]] && [[ $line =~ "v" ]] && $is_version && [[ $n_num -eq 3 ]] && [[ $n_lines -gt 0 ]]; then
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

function get_version() { # get the latest version number
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

function get_ssd() { # get SSD status
	[[ -z $(which smartctl 2>&1) ]] && has_smartctl=false || has_smartctl=true # check if smartctl is available
	if $has_smartctl; then
		enable_smart=$(smartctl -s on disk0) # enable SMART on disk0
		smartinfo=$(smartctl -x disk0)
		#[[ -z $(echo "$smartinfo" | grep "Data Units Read:") ]] && firmware_support=false || firmware_support=true
		if [[ $(echo "$smartinfo" | grep "Data Units Read:") ]]; then
			firmware=1
			firmware_support=true
		elif [[ $(echo "$smartinfo" | grep "Logical Sectors Read") ]]; then
			firmware=2
			firmware_support=true
		else
			firmware_support=false
		fi
		if $firmware_support; then # run SSD log only when firmware support
			if [[ $firmware == 1 ]]; then
				result=$(echo "$smartinfo" | grep "test result:" | awk '{print $6}')
				read_unit=$(echo "$smartinfo" | grep "Data Units Read:" | sed -n 's/.*\[\(.*\)\]/\1/p' | tr -d ' ')
				write_unit=$(echo "$smartinfo" | grep "Data Units Written:" | sed -n 's/.*\[\(.*\)\]/\1/p' | tr -d ' ')
				used=$(echo "$smartinfo" | grep "Percentage Used:" | awk '{print $3}')
				power_cycles=$(echo "$smartinfo" | grep "Power Cycles:" | awk '{print $3}')
				power_hours=$(echo "$smartinfo" | grep "Power On Hours:" | awk '{print $4}')
				unsafe_shutdowns=$(echo "$smartinfo" | grep "Unsafe Shutdowns:" | awk '{print $3}')
				temperature=$(echo "$smartinfo" | grep "Temperature:" | awk '{print $2"°C"}')
				error=$(echo "$smartinfo" | grep "Media and Data Integrity Errors:" | awk '{print $6}')
			else
				result=$(echo "$smartinfo" | grep "test result:" | awk '{print $6}')
				read_unit=$(echo "$smartinfo" | grep "Host_Reads_MiB" | awk '{print $8}'); [[ "$read_unit" =~ ^[0-9]+$ ]] && read_unit=$(echo "scale=2; $read_unit/1048576" | bc)"TB" || read_unit=
				write_unit=$(echo "$smartinfo" | grep "Host_Writes_MiB" | awk '{print $8}'); [[ "$write_unit" =~ ^[0-9]+$ ]] && write_unit=$(echo "scale=2; $write_unit/1048576" | bc)"TB" || write_unit=
				used=$(echo "$smartinfo" | grep "Percentage Used" | awk '{print $4"%"}')
				power_cycles=$(echo "$smartinfo" | grep "Power_Cycle_Count" | awk '{print $8}')
				power_hours=$(echo "$smartinfo" | grep "Power_On_Hours" | awk '{print $8}')
				unsafe_shutdowns=$(echo "$smartinfo" | grep "Power-Off_Retract_Count" | awk '{print $8}')
				temperature=$(echo "$smartinfo" | grep "Temperature" | awk '{print $8"°C"}')
				error=$(echo "$smartinfo" | grep "Uncorrectable Errors" | awk '{print $4}')
			fi
			if [[ -z $result ]]; then result="NA"; fi
			if [[ -z $read_unit ]]; then read_unit="NA"; fi
			if [[ -z $write_unit ]]; then write_unit="NA"; fi
			if [[ -z $used ]]; then used="NA"; fi
			if [[ -z $power_cycles ]]; then power_cycles="NA"; fi
			if [[ -z $power_hours ]]; then power_hours="NA"; fi
			if [[ -z $unsafe_shutdowns ]]; then unsafe_shutdowns="NA"; fi
			if [[ -z $temperature ]]; then temperature="NA"; fi
			if [[ -z $error ]]; then error="NA"; fi
		fi
	fi
	echo $has_smartctl $firmware_support $result $read_unit $write_unit $used $power_cycles $power_hours $unsafe_shutdowns $temperature $error
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
	sigpid=$(echo $(cat "$pid_sig" 2>/dev/null) | awk '{print $1}')
	sig=$(echo $(cat "$pid_sig" 2>/dev/null) | awk '{print $2}')
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
	if [[ "$(maintain_is_running)" == "1" ]] && [[ "$(echo $(cat "$pidfile" 2>/dev/null) | awk '{print $2}')" == "suspended" ]]; then
		$battery_binary maintain recover
	fi
	#kill 0 # kill all child processes
	for pid in $pid_child; do
		kill -s USR1 $pid
	done
	exit 1
}

function charge_interrupted() {
	disable_charging
	if [[ "$(maintain_is_running)" == "1" ]] && [[ "$(echo $(cat "$pidfile" 2>/dev/null) | awk '{print $2}')" == "suspended" ]] && [[ "$original_maintain_status" == "active" ]]; then
		$battery_binary maintain recover
	fi
	exit 1
}

function charge_terminated() { # terminated by another battery process, no need to handle maintain process
	disable_charging
	exit 1
}

function discharge_interrupted() {
	disable_discharging
	if [[ "$(maintain_is_running)" == "1" ]] && [[ "$(echo $(cat "$pidfile" 2>/dev/null) | awk '{print $2}')" == "suspended" ]] && [[ "$original_maintain_status" == "active" ]]; then
		$battery_binary maintain recover
	fi
	exit 1
}

function discharge_terminated() { # terminated by another battery process, no need to handle maintain process
	disable_discharging
	exit 1
}

function maintain_is_running() {
	# check if battery maintain is running
	if test -f "$pidfile"; then # if maintain is ongoing
		local pid=$(cat "$pidfile" 2>/dev/null | awk '{print $1}')
		#n_pid=$(pgrep -f $battery_binary | awk 'END{print NR}')
		#pid_found=0
		#for ((i = 1; i <= n_pid; i++)); do
		#	pid_running=$(pgrep -f $battery_binary | head -n$i | tail -n1 | awk '{print $1}')
		#	if [ "$pid" == "$pid_running" ]; then # battery maintain is running
		#		pid_found=1
		#		break
		#	fi
		#done
		local pid_found=false
		local pids=$(ps x | grep battery | awk '{print $1}')
		for pid_running in $pids; do
			if [ "$pid" == "$pid_running" ]; then # battery maintain is running
				pid_found=true
				break
			fi
		done

		if $pid_found; then
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
		local pid_calibrate=$(cat "$calibrate_pidfile" 2>/dev/null)
		local pid_found=false
		local pids=$(ps x | grep battery | awk '{print $1}')
		for pid_running in $pids; do
			if [ "$pid_calibrate" == "$pid_running" ]; then # battery maintain is running
				pid_found=true
				break
			fi
		done
		if $pid_found; then
			echo 1
		else
			echo 0
		fi
	else
		echo 0
	fi
}

function read_smc() { # read smc decimal value
	val=$(read_smc_hex $1)
	[[ -z $val ]] && echo || echo $((0x${val}))
}

function read_smc_hex() { # read smc hex value
	key=$1
	line=$(echo $(smc -k $key -r))
	if [[ $line =~ "no data" ]]; then
		echo
	else
		echo ${line#*bytes} | tr -d ' ' | tr -d ')'
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

function print_calibrate_log() {
	calibrate_time="$1 $2"
	completed=$3
	health_before=$4
	health_after=$5
	echo -n "$calibrate_time $completed $health_before $health_after" | awk '{printf "%-10s %-5s, %9s, %13s, %12s, ", $1, $2, $3, $4, $5}' >> $calibrate_log
}

## ###############
## Actions
## ###############

# Resolve CLI language before help/validation so shared errors can be localized
resolve_cli_language

# Help message
if [ -z "$action" ] || [[ "$action" == "help" ]]; then
	show_help
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
	i18n_log visudo_set_owner "$setting"
	sudo chown -R $setting $configfolder

	# Write the visudo file to a tempfile
	visudo_tmpfile="$configfolder/visudo.tmp"
	sudo rm $visudo_tmpfile 2>/dev/null
	echo -e "$visudoconfig" >$visudo_tmpfile

	# If the visudo file is the same (no error, exit code 0), set the permissions just
	if sudo cmp $visudo_file $visudo_tmpfile &>/dev/null; then

			i18n_echo visudo_already_current "$BATTERY_CLI_VERSION"

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

			i18n_echo visudo_updated_success

	else
			i18n_echo visudo_validate_error
		sudo visudo -c -f $visudo_tmpfile
	fi

	sudo rm $visudo_tmpfile 2>/dev/null
	exit 0
fi

# Reinstall helper
if [[ "$action" == "reinstall" ]]; then
	i18n_echo reinstall_preview "$github_link"
	if [[ ! "$setting" == "silent" ]]; then
		i18n_echo press_any_key_continue
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
	else
		github_link="https://raw.githubusercontent.com/js4jiang5/BatteryOptimizer_for_MAC/main"
	fi
	battery_new=$(echo $(curl -sSL "$github_link/battery.sh"))
	battery_new_version=$(echo $(get_parameter "$battery_new" "BATTERY_CLI_VERSION") | tr -d \")
		
		if [[ $battery_new == "404: Not Found" ]]; then
			i18n_log update_specified_file_missing
			exit 1
		fi

	visudo_new_version=$(echo $(get_parameter "$battery_new" "BATTERY_VISUDO_VERSION") | tr -d \")
	if [[ $battery_new_version == $BATTERY_CLI_VERSION ]] && [[ $visudo_new_version == $BATTERY_VISUDO_VERSION ]] && [[ "$setting" != "force" ]]; then
		dialog_msg=$(i18n_format update_dialog_latest "$BATTERY_CLI_VERSION")
		dialog_ok=$(i18n_text dialog_button_ok)
		dialog_title=$(i18n_text title_battery_optimizer_mac)
		osascript -e 'display dialog "'"$dialog_msg"'" buttons {"'"$dialog_ok"'"} default button 1 giving up after 60 with icon note with title "'"$dialog_title"'"' >> /dev/null
	else
		button_empty="                                                                                                                                                    "
		if $is_TW; then
			changelog=$(get_changelog CHANGELOG_TW)
			battery_new_version=$(get_version CHANGELOG_TW)
		else
			changelog=$(get_changelog CHANGELOG)
			battery_new_version=$(get_version CHANGELOG)
		fi
		dialog_msg=$(i18n_format update_dialog_changelog "$battery_new_version" "$changelog")
		dialog_continue=$(i18n_text dialog_button_continue)
		dialog_title=$(i18n_text title_battery_optimizer_mac)
		osascript -e 'display dialog "'"$dialog_msg"'" buttons {"'"$button_empty"'", "'"$dialog_continue"'"} default button 2 with icon note with title "'"$dialog_title"'"' >> /dev/null
		update_yes_button=$(i18n_text dialog_button_update_now)
		update_no_button=$(i18n_text dialog_button_skip_version)
		dialog_msg=$(i18n_format update_dialog_confirm "$battery_new_version")
		answer="$(osascript -e 'display dialog "'"$dialog_msg"'" buttons {"'"$update_yes_button"'", "'"$update_no_button"'"} default button 1 with icon note with title "'"$dialog_title"'"' -e 'button returned of result')"
		
		if [[ $answer == "$update_yes_button" ]]; then
			curl -sS "$github_link/update.sh" | bash
		fi
	fi
	exit 0
fi

# Uninstall helper
if [[ "$action" == "uninstall" ]]; then

	if [[ ! "$setting" == "silent" ]]; then
		i18n_echo uninstall_preview
		i18n_echo press_any_key_continue
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
	pkill -9 -f "/usr/local/bin/battery.*"
	exit 0
fi

# Charging on/off controller
if [[ "$action" == "charge" ]]; then

	trap charge_interrupted SIGINT SIGTERM
	trap charge_terminated SIGUSR1

	# kill running charge process
	pids=$(pgrep -f battery)
	for pid_running in $pids; do
		if [[ $(ps x | grep $pid_running) =~ " charge" ]]; then
			kill $pid_running
		fi 
	done

	if ! valid_percentage "$setting"; then
			if [[ "$setting" == "stop" ]]; then
				exit 0
			else
				i18n_log charge_invalid_setting "$setting"
				exit 1
			fi
		fi

	# kill running discharge processes
	pids=$(pgrep -f battery)
	for pid_running in $pids; do
		if [[ $(ps x | grep $pid_running) =~ " discharge" ]]; then
			kill $pid_running
		fi 
	done

	# Disable running daemon
	original_maintain_status=$(echo $(cat "$pidfile" 2>/dev/null) | awk '{print $2}')
	$battery_binary maintain suspend

		# Start charging
		battery_percentage=$(get_battery_percentage)
		battery_pre=$battery_percentage
		i18n_log charge_start "$setting" "$battery_percentage"
		enable_charging # also disables discharging

	change_magsafe_led_color "orange" # LED orange for charging

	# Loop until battery percent is exceeded
	cnt_error=0
	charge_error=false
	#while [[ "$battery_percentage" -lt "$setting" ]]; do
	while (( $(echo "$(get_accurate_battery_percentage) < $setting"|bc -l) )); do

			if [[ $battery_percentage -ne $battery_pre ]]; then # print only when there is change
				i18n_log charge_progress "$battery_percentage" "$setting"
				battery_pre=$battery_percentage
			fi
		
		if [[ "$battery_percentage" -ge "$((setting - 3))" ]]; then
			if [[ $cnt_error -gt 36 ]]; then
				charge_error=true
				break;
			fi
			caffeinate -is sleep 5 &
		else
			if [[ $cnt_error -gt 3 ]]; then
				charge_error=true
				break;
			fi
			caffeinate -is sleep 60 &
		fi
		wait $!
		battery_percentage=$(get_battery_percentage)
		chbi=$(read_smc CHBI)
		if [[ $chbi -eq 0 ]]; then
			cnt_error=$((cnt_error+1))
		else
			cnt_error=0
		fi
	done

	if [[ "$(calibrate_is_running)" == "0" ]] || [[ "$setting" -ne "100" ]]; then # no need to disable charging in calibration when charging to 100%
		disable_charging
	fi
	
	sleep 5
	change_magsafe_led_color "auto"
	
		if ! $charge_error; then
			i18n_log charge_completed "$battery_percentage"

		if [[ $battery_percentage -ge $(get_maintain_percentage) ]] && [[ "$(calibrate_is_running)" == "0" ]] && [[ "$original_maintain_status" == "active" ]]; then # if charge level is higher than maintain percentage, recover maintain won't cause discharge
			$battery_binary maintain recover
		fi
		exit 0
		else
			i18n_log charge_abnormal
			if [[ "$(calibrate_is_running)" == "0" ]] && [[ "$original_maintain_status" == "active" ]]; then # if discharge level is higher than maintain percentage, recover maintain won't cause charge
				$battery_binary maintain recover
		fi
		exit 1
	fi

fi

# Discharging on/off controller
if [[ "$action" == "discharge" ]]; then

	trap discharge_interrupted SIGINT SIGTERM
	trap discharge_terminated SIGUSR1

	# kill running discharge process
	pids=$(pgrep -f battery)
	for pid_running in $pids; do
		if [[ $(ps x | grep $pid_running) =~ " discharge" ]]; then
			kill $pid_running
		fi 
	done

	if ! valid_percentage "$setting"; then
			if [[ "$setting" == "stop" ]]; then
				exit 0
			else
				i18n_log discharge_invalid_setting "$setting"
				exit 1
			fi
		fi

		if [[ $(lid_closed) == "Yes" ]]; then
			i18n_log discharge_lid_open_required
			exit 1
		fi

	# kill running charge processes
	pids=$(pgrep -f battery)
	for pid_running in $pids; do
		if [[ $(ps x | grep $pid_running) =~ " charge" ]]; then
			kill $pid_running
		fi 
	done

	# Disable running daemon
	original_maintain_status=$(echo $(cat "$pidfile" 2>/dev/null) | awk '{print $2}')
	$battery_binary maintain suspend

		# Start discharging
		battery_percentage=$(get_battery_percentage)
		battery_pre=$battery_percentage
		i18n_log discharge_start "$setting" "$battery_percentage"
		enable_discharging

	change_magsafe_led_color "none" # LED none for discharging

	# Loop until battery percent is below target
	cnt_error=0
	discharge_error=false
	#while [[ "$battery_percentage" -gt "$setting" ]]; do
	while (( $(echo "$(get_accurate_battery_percentage) > $setting"|bc -l) )); do

			if [[ $battery_percentage -ne $battery_pre ]]; then # print only when there is change
				i18n_log discharge_progress "$battery_percentage" "$setting"
				battery_pre=$battery_percentage
			fi
		caffeinate -is sleep 60 &
		wait $!
		battery_percentage=$(get_battery_percentage)
		chbi=$(read_smc CHBI)
		b0ac=$(read_smc B0AC)
		if [[ $b0ac -eq 0 ]] || [[ $chbi -gt 0 ]] ; then
			cnt_error=$((cnt_error+1))
			if [[ $cnt_error -gt 3 ]]; then
				discharge_error=true
				break;
			fi
		else
			cnt_error=0
		fi
	done

	disable_discharging
	sleep 5
	change_magsafe_led_color "auto"
	
		if ! $discharge_error; then
			i18n_log discharge_completed "$battery_percentage"

		if [[ $battery_percentage -ge $(get_maintain_percentage) ]] && [[ "$(calibrate_is_running)" == "0" ]] && [[ "$original_maintain_status" == "active" ]]; then # if discharge level is higher than maintain percentage, recover maintain won't cause charge
			$battery_binary maintain recover
		fi
		exit 0
		else
			i18n_log discharge_abnormal
			if [[ "$(calibrate_is_running)" == "0" ]] && [[ "$original_maintain_status" == "active" ]]; then # if discharge level is higher than maintain percentage, recover maintain won't cause charge
				$battery_binary maintain recover
		fi
		exit 1
	fi

fi

# Maintain at level
if [[ "$action" == "maintain_synchronous" ]]; then
	if [[ $(get_cpu_type) == "apple" ]]; then # reset to default when reboot
		if $has_CHWA; then sudo smc -k CHWA -w 00; fi
	fi

	# Recover old maintain status if old setting is found
	if [[ "$setting" == "recover" ]]; then

		# Before doing anything, log out environment details as a debugging trail
		log "Debug trail. User: $USER, config folder: $configfolder, logfile: $logfile, file called with 1: $1, 2: $2"

			maintain_percentage=$(read_config maintain_percentage)
			if [[ $maintain_percentage ]]; then
				i18n_log maintain_recovering_percentage "$maintain_percentage"
				setting=$(echo $maintain_percentage | awk '{print $1}')
				subsetting=$(echo $maintain_percentage | awk '{print $2}')
			else
				i18n_log maintain_no_setting_to_recover
				exit 0
			fi
		fi

		if ! valid_percentage "$setting"; then
			i18n_log maintain_invalid_setting "$setting"
			exit 1
		fi

	if ! valid_percentage "$subsetting"; then
		lower_limit=$((setting-5))
		if [ $lower_limit -lt 0 ]; then
			lower_limit=0
		fi
		else
			if [ $setting -le $subsetting ]; then
				i18n_log maintain_invalid_sailing_target "$subsetting" "$setting"
				exit
			fi
			lower_limit=$subsetting
		fi

		i18n_log maintain_start "$setting" "$lower_limit" "$thirdsetting"

	# Check if the user requested that the battery maintenance first discharge to the desired level
		if [[ "$subsetting" == "--force-discharge" ]] || [[ "$thirdsetting" == "--force-discharge" ]]; then
			if [[ $(lid_closed) == "Yes" ]]; then
				i18n_log maintain_lid_open_required
				exit 1
			fi
			# Before we start maintaining the battery level, first discharge to the target level
			i18n_log maintain_trigger_force_discharge "$setting"
			$battery_binary discharge "$setting"
			i18n_log maintain_force_discharge_done
		else
			i18n_log maintain_force_discharge_skipped
		fi

	# Start charging
	battery_percentage=$(get_battery_percentage)

		i18n_log maintain_charging_and_maintaining "$setting" "$battery_percentage"

	# Store pid of maintenance process
	echo $$ >$pidfile
	pid=$(cat "$pidfile" 2>/dev/null)

	# Loop until battery percent is exceeded
	now=$(date +%s)
	maintain_status="active"
	pre_maintain_status=$maintain_status
	echo "$$ $maintain_status" > $pidfile
	daily_log_timeout=$((now + (24*60*60))) # start daily log one day after running this program
	ac_connection=$(get_charger_connection)
	pre_ac_connection=$ac_connection
		sleep_duration=60
		if ! test -f $daily_log; then
	    	echo "$(i18n_text daily_log_table_header)" | awk '{printf "%-10s, %9s, %9s, %12s, %9s, %9s\n", $1, $2, $3, $4, $5, $6}' > $daily_log
		fi
	check_update_timeout=$((now + (3*24*60*60))) # first check update 3 days later
	
	informed_version=$(read_config informed_version)
	if [[ -z $informed_version ]]; then
		informed_version=$BATTERY_CLI_VERSION
	fi
	
	if [[ -z $(read_config calibrate_next) ]]; then 
		write_config calibrate_next $(check_next_calibration_date)
	fi

	change_magsafe_led_color "auto"

	trap ack_SIG SIGUSR1
	while true; do
		if [ "$maintain_status" != "$pre_maintain_status" ]; then # update state to state_file
			echo "$$ $maintain_status" > $pidfile
			pre_maintain_status=$maintain_status 
		fi
		now_sec=`date +%s`
		now_day=$((10#`date +%d`))
		tomorrow_day=$((10#`date -v+1d +%d`))
		timeout_day=$((10#`date -j -f "%s" $daily_log_timeout "+%d"`))

		# check if schedule is enabled
		enable_exist="$(launchctl print gui/$(id -u $USER) | grep "=> enabled")"
		
		if [[ $enable_exist ]] && [[ $(read_config calibrate_schedule) ]]; then # new version that replace => false with => enabled
			schedule_enabled="$(launchctl print gui/$(id -u $USER) | grep enabled | grep "com.battery_schedule.app")"
		else # old version that use => false
			schedule_enabled="$(launchctl print gui/$(id -u $USER) | grep "=> false" | grep "com.battery_schedule.app")"
			schedule_enabled=${schedule_enabled/false/enabled}
		fi

		if (( $now_sec > $daily_log_timeout || ($now_sec > $(($daily_log_timeout - 86400)) && $now_day == $timeout_day) )); then # if timeout or today is timeout day
			daily_log_timeout=$((`date +%s` + (24*60*60))) # set next daily_log timeout
			daily_last=$(read_config daily_last)
			now_date=`date +%Y-%m-%d`
			if [[ $now_date != $daily_last ]]; then
				logd "$(get_accurate_battery_percentage)% $(get_voltage)V $(get_battery_temperature)°C $(get_battery_health)% $(get_cycle)" | awk '{printf "%-10s, %9s, %9s, %13s, %9s, %9s\n", $1, $2, $3, $4, $5, $6}' >> $daily_log
				#if [ "$(date +%d)" == "01" ]; then # monthly notification
					i18n_notify title_battery notify_battery_monthly_summary "$(get_accurate_battery_percentage)" "$(get_voltage)" "$(get_battery_temperature)" "$(get_battery_health)" "$(get_cycle)"
				#fi

				# SSD log
				ssd_result=$(echo $(get_ssd))
				has_smartctl=$(echo $ssd_result | awk '{print $1}')
				firmware_support=$(echo $ssd_result | awk '{print $2}')
				smartinfo=$(echo $ssd_result | awk '{print $3, $4, $5, $6, $7, $8, $9, $10, $11}')
				if [[ $has_smartctl == true ]]; then
						if [[ $firmware_support == true ]]; then # run SSD log only when firmware support
							if ! test -f $ssd_log; then
								echo "$(i18n_text ssd_log_table_header)" | awk '{printf "%-10s, %6s, %11s, %12s, %5s, %12s, %11s, %16s, %11s, %5s\n", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10}' > $ssd_log
							fi
						logd "$smartinfo" | awk '{printf "%-10s, %6s, %11s, %12s, %5s, %12s, %11s, %16s, %12s, %5s\n", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10}' >> $ssd_log
					fi
				fi
			fi
			write_config daily_last $now_date

			# notify user if today or tomorrow is next calibration day
			if [[ $schedule_enabled =~ "enabled" ]]; then
				schedule_sec=$(check_next_calibration_date)
				diff_sec=$((schedule_sec - `date +%s`))
				schedule_day=$((10#`date -j -f "%s" $schedule_sec "+%d"`))
				 
				# remind if tomorrow is calibration date
				if [[ $tomorrow_day -eq $schedule_day ]] && [[ $diff_sec -lt $((48*60*60)) ]]; then
					schedule_time="$(echo `date -j -f "%s" $schedule_sec "+%Y/%m/%d %H:%M"`)"
						i18n_notify title_battery notify_calibration_tomorrow "$schedule_time"
				fi

				# remind if today is calibration date
				if [[ $now_day -eq $schedule_day ]] && [[ $diff_sec -lt $((24*60*60)) ]]; then
					schedule_time="$(echo `date -j -f "%s" $schedule_sec "+%Y/%m/%d %H:%M"`)"
						i18n_notify title_battery notify_calibration_today "$schedule_time"
				fi
			fi
		fi

		# run battery calibrate if calibration is missed due to sleep or shutdown at specified time
		calibrate_next=$(read_config calibrate_next)
		if [[ $now_sec -gt $calibrate_next ]] && [[ "$(calibrate_is_running)" == "0" ]] && [[ $schedule_enabled =~ "enabled" ]]; then
			$battery_binary calibrate force &
		fi

		# check if there is update version
		if [[ $(date +%s) -gt $check_update_timeout ]]; then
			updated="$(curl -sS $github_link/battery.sh | grep "$informed_version")"
			new_version="$(curl -sS $github_link/battery.sh | grep "BATTERY_CLI_VERSION=")"
			new_version="$(echo $new_version | awk '{print $1}')"
			new_version=$(echo ${new_version/"BATTERY_CLI_VERSION="} | tr -d \")
			
			if [[ -z $updated ]] && [[ $new_version ]]; then
					i18n_notify title_battery_optimizer notify_update_available "$new_version"
				informed_version=$new_version
				write_config informed_version $informed_version
			fi
			check_update_timeout=$((`date +%s` + (24*60*60))) # check update one time each day
		fi

		# Turn off AlDente if it is running to avoid conflict
		aldente_is_running=$(pgrep -f aldente)
		if [[ $aldente_is_running ]]; then
			i18n_log aldente_conflict_detected
			osascript -e 'quit app "aldente"'
		fi

		if [ "$maintain_status" == "active" ]; then
			# Keep track of LED status
			change_magsafe_led_color "auto"

			# Keep track of SMC charging status
			smc_charging_status=$(get_smc_charging_status)
			if [[ "$battery_percentage" -ge "$setting" ]] && [[ "$smc_charging_status" == "enabled" ]]; then

				i18n_log maintain_stop_charge_above "$setting"
				disable_charging
				sleep_duration=60

			elif [[ "$battery_percentage" -lt "$lower_limit" ]] && [[ "$smc_charging_status" == "disabled" ]]; then

				i18n_log maintain_start_charge_below "$lower_limit"
				enable_charging
				sleep_duration=5 # reduce monitoring period to 5 seconds during charging
			fi
			
			sleep $sleep_duration &
			wait $!
		else
			sleep_duration=60
			sleep $sleep_duration &
			wait $!

			ac_connection=$(get_charger_connection) # update ac connection state

			# check if calibrate is running to decide if resume
			if [[ "$(calibrate_is_running)" == "0" ]]; then # if not running
					if [[ "$ac_connection" == "1" ]] && [[ "$pre_ac_connection" == "0" ]]; then # resume maintain to active when AC adapter is reconnected
						maintain_status="active"
						i18n_log maintain_recovered_ac_reconnected
						i18n_notify title_battery maintain_recovered
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

	pid=$(echo $(cat "$pidfile" 2>/dev/null) | awk '{print $1}')
	if [[ "$setting" == "recover" ]]; then
		if [[ "$(maintain_is_running)" == "1" ]]; then
			maintain_status=$(echo $(cat "$pidfile" 2>/dev/null) | awk '{print $2}')
			if [[ "$maintain_status" == "suspended" ]]; then # maintain is running but not active
				echo "$$ recover"> $pid_sig
				sleep 1

				# waiting for ack from $pid
					i18n_logn maintain_recover_wait
				ack_received=0
				trap confirm_SIG SIGUSR1
				kill -s USR1 $pid # inform running battery process to suspend
				for i in {1..10}; do # wait till timeout after 60 seconds
					echo -n "."
					sleep 1
				done
				if [ "$ack_received" == "1" ]; then
						i18n_logLF maintain_recovered
						if [ "$notify" == "1" ]; then
							i18n_notify title_battery maintain_recovered
						fi
					exit 0
				else
						i18n_logLF maintain_recover_failed
						if [ "$notify" == "1" ]; then
							i18n_notify title_battery maintain_recover_failed
						fi
					exit 1
				fi
			else
					i18n_log maintain_already_running
			fi
			exit 0
		fi
	fi

	if [[ "$setting" == "suspend" ]]; then
		if [[ "$(maintain_is_running)" == "0" ]]; then # maintain is not running
				i18n_log maintain_not_running
			exit 0
		else
			maintain_status=$(echo $(cat "$pidfile" 2>/dev/null) | awk '{print $2}')
			if [[ "$maintain_status" == "active" ]]; then
				if [ "$notify" == "1" ]; then # if suspend is called by user, enable charging to 100%
					echo "$$ suspend" > $pid_sig
				else # if suspend is called by another battery process, let that process handle charging
					echo "$$ suspend_no_charging" > $pid_sig
				fi

				sleep 1

				# waiting for ack from $pid
					i18n_logn maintain_suspend_wait
				ack_received=0
				trap confirm_SIG SIGUSR1
				kill -s USR1 $pid # inform running battery process to suspend
				for i in {1..10}; do # wait till timeout after 60 seconds
					echo -n "."
					sleep 1
				done
				if [ "$ack_received" == "1" ]; then
						i18n_logLF maintain_suspended
						if [ "$notify" == "1" ]; then
							i18n_notify title_battery maintain_suspended
						fi
					exit 0
				else
						i18n_logLF maintain_suspend_failed
						if [ "$notify" == "1" ]; then
							i18n_notify title_battery maintain_suspend_failed
						fi
					exit 1
				fi
			else
					if [ "$notify" == "1" ]; then
						i18n_notify title_battery maintain_suspended
					fi
				exit 0
			fi
		fi
	fi

	# Kill old process silently
	if test -f "$pidfile"; then
		log "Killing old maintain process at $(cat $pidfile)" >> $logfile
		pid=$(echo $(cat "$pidfile" 2>/dev/null) | awk '{print $1}')
		kill $pid &>/dev/null
	fi

	if [[ "$setting" == "stop" ]]; then
		log "Killing running maintain daemons & enabling charging as default state" >> $logfile
		rm $pidfile 2>/dev/null
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
			i18n_log maintain_calibration_process_stopped
	fi
	
	# Check if setting is value between 0 and 100
	if ! valid_percentage "$setting"; then
		# log "Called with $setting $action"
		# If non 0-100 setting is not a special keyword, exit with an error.
			if ! { [[ "$setting" == "stop" ]] || [[ "$setting" == "recover" ]]; }; then
				i18n_log maintain_invalid_setting_with_keywords "$setting"
				exit 1
			fi
	fi

	# Start maintenance script
	nohup $battery_binary maintain_synchronous $setting $subsetting $thirdsetting >> $logfile &
	log "New process ID $!" >> $logfile

	if ! [[ "$setting" == "recover" ]]; then
		# Update settings

		if ! valid_percentage $subsetting; then
			log "Writing new setting $setting to maintain_percentage" >> $logfile
			write_config maintain_percentage $setting
		else
			log "Writing new setting $setting $subsetting to maintain_percentage" >> $logfile
			write_config maintain_percentage "$setting $subsetting"
		fi
	fi

	# Enable the daemon that continues maintaining after reboot
	$battery_binary create_daemon

	## Enable schedule
	#$battery_binary schedule enable >> $logfile

	# Report status
	$battery_binary status

	if valid_percentage "$setting"; then
		if [[ $(get_battery_percentage) -gt $setting ]]; then # if current battery percentage is higher than maintain percentage
			if ! [[ $(ps aux | grep $PPID) =~ "setup.sh" ]] && ! [[ $(ps aux | grep $PPID) =~ "update.sh" ]]; then 
				# Ask user if discharging right now unless this action is invoked by setup.sh
				dialog_yes=$(i18n_text dialog_button_yes)
				dialog_no=$(i18n_text dialog_button_no)
				dialog_title=$(i18n_text title_battery_optimizer_mac)
				dialog_msg=$(i18n_format maintain_prompt_discharge_now "$setting")
				answer="$(osascript -e 'display dialog "'"$dialog_msg"'" buttons {"'"$dialog_yes"'", "'"$dialog_no"'"} default button 1 giving up after 10 with icon note with title "'"$dialog_title"'"' -e 'button returned of result')"
					if [[ "$answer" == "$dialog_yes" ]] || [ -z $answer ]; then
						i18n_log maintain_start_discharge_now "$setting"
						$battery_binary discharge $setting 
						$battery_binary maintain recover
				fi
			fi
		fi
	fi

	exit 0

fi

# Battery calibration
if [[ "$action" == "calibrate" ]]; then

	trap calibrate_interrupted SIGINT SIGTERM

	if ! [[ -t 0 ]] && [[ "$setting" != "force" ]]; then # if the command is not entered from stdin (terminal) by a person, meaning it is a scheduled calibration
		# check schedule to see if this week should calibrate
		now=`date +%s`
		calibrate_next=$(read_config calibrate_next)
		if (( $((now - $calibrate_next)) < -30 || $((now - $calibrate_next)) > 30 )); then # if difference with scheduled calibrate time is within +-30 seconds
			i18n_log calibrate_skip_run
			exit 0
		fi
	fi

	# Kill old process silently
	if test -f "$calibrate_pidfile"; then
		pid=$(cat "$calibrate_pidfile" 2>/dev/null)
		kill $pid &>/dev/null
	fi

	if [[ "$setting" == "stop" ]]; then
		i18n_log calibrate_stop_running >> $logfile
		exit 0
	fi

	write_config calibrate_next $(check_next_calibration_date)

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

	if ! test -f $calibrate_log; then
		echo "$(i18n_text calibrate_log_table_header)" | awk '{printf "%-16s, %9s, %13s, %12s, %-s\n", $1, $2, $3, $4, $5}' > $calibrate_log
	fi

	calibrate_time=`date -j -f "%s" $(date +%s) "+%Y/%m/%d %H:%M"`
	health_before="$(get_battery_health)%"

	# abort calibration if battery maintain is not running
	if [ "$(maintain_is_running)" == "0" ]; then
		i18n_notify title_calibration_error calibrate_require_maintain_before
		i18n_log calibrate_error_require_maintain_before_log

		print_calibrate_log $calibrate_time No $health_before %
		i18n_echo calibrate_require_maintain_before >> $calibrate_log

		exit 1
	fi

	# if lid is closed or AC is not connected, notify the user and wait until lid is open with AC or 1 day timeout
	if [[ $(lid_closed) == "Yes" ]] || [[ $(get_charger_connection) == "0" ]]; then
		ha_webhook "open_lid_remind"
		i18n_notify title_calibration calibrate_wait_open_lid_ac_notify
		
		i18n_log calibrate_wait_open_lid_ac_log
		now=$(date +%s)
		lid_open_timeout=$(($now + 24*60*60))
		while [[ $(date +%s)  -lt $lid_open_timeout ]]; do
			if [[ $(lid_closed) == "No" ]] && [[ $(get_charger_connection) == "1" ]]; then
				break
			fi
			sleep 5
		done
	fi

	# check if lid is open or not
	if [[ $(lid_closed) == "Yes" ]] || [[ $(get_charger_connection) == "0" ]]; then # lid is still closed, terminate the calibration
		ha_webhook "err_lid_closed"
		if [[ $(lid_closed) == "Yes" ]]; then
			i18n_notify title_calibration_error calibrate_lid_not_open
			i18n_log calibrate_error_lid_not_open_log

			print_calibrate_log $calibrate_time No $health_before %
			i18n_echo calibrate_lid_not_open >> $calibrate_log
			
		fi
		if [[ $(get_charger_connection) == "0" ]]; then
			i18n_notify title_calibration_error calibrate_no_ac_power
			i18n_log calibrate_error_no_ac_power_log

			print_calibrate_log $calibrate_time No $health_before %
			i18n_echo calibrate_no_ac_power_logfile >> $calibrate_log
		fi
		exit 1
	fi

	start_t=`date +%s`

	# Store pid of calibration process
	echo $$ >$calibrate_pidfile
	pid=$(cat "$calibrate_pidfile" 2>/dev/null)
	
	# check maintain percentage
	setting=$(get_maintain_percentage)
	if [[ -z $setting ]]; then # default percentage is 80
		setting=80
	fi

	# Select calibrate method. Method 1: Discharge first. Method 2: Charge first
	method=1
	method=$(read_config calibrate_method)
	if [[ "$method" != "1" ]] && [[ "$method" != "2" ]]; then # method can be 1 or 2 only
		method=1
	fi

	if [ "$method" == "1" ]; then
		ha_webhook "start" $(get_accurate_battery_percentage) $(get_voltage) $(get_battery_health) # inform HA calibration has started
		i18n_notify title_calibration calibrate_start_discharge_15_notify
		i18n_log calibrate_start_discharge_15_log

		# Suspend the maintaining
		$battery_binary maintain suspend

		# Discharge battery to 15%
		ha_webhook "discharge15_start" $(get_accurate_battery_percentage) $(get_voltage) $(get_battery_health)
		$battery_binary discharge 15 &
		pid_child="$!"
		wait $!
		if [[ $? != 0 ]]; then
			ha_webhook "err_discharge15"
			i18n_notify title_calibration_error calibrate_fail_discharge_15
			i18n_log calibrate_error_discharge_15_log

			print_calibrate_log $calibrate_time No $health_before %
			i18n_echo calibrate_fail_discharge_15 >> $calibrate_log

			rm $calibrate_pidfile 2>/dev/null
			$battery_binary maintain recover # Recover old maintain status
			exit 1
		fi
		pid_child=""
		
		ha_webhook "discharge15_end" $(get_accurate_battery_percentage) $(get_voltage) $(get_battery_health)
		i18n_notify title_calibration calibrate_done_discharge_15_charge_100_notify
		i18n_log calibrate_done_discharge_15_charge_100_log
		i18n_log calibrate_health_snapshot_log "$(get_battery_health)" "$(get_voltage)" "$(get_battery_temperature)"

		# Enable battery charging to 100%
		ha_webhook "charge100_start" $(get_accurate_battery_percentage) $(get_voltage) $(get_battery_health)
		$battery_binary charge 100 &
		pid_child="$!"
		wait $!
		if [[ $? != 0 ]]; then
			ha_webhook "err_charge100"
			i18n_notify title_calibration_error calibrate_fail_charge_100
			i18n_log calibrate_error_charge_100_log

			print_calibrate_log $calibrate_time No $health_before %
			i18n_echo calibrate_fail_charge_100 >> $calibrate_log

			rm $calibrate_pidfile 2>/dev/null
			$battery_binary maintain recover # Recover old maintain status
			exit 1
		fi
		pid_child=""

		ha_webhook "charge100_end" $(get_accurate_battery_percentage) $(get_voltage) $(get_battery_health)
		i18n_notify title_calibration calibrate_done_charge_100_wait_1h_notify
		i18n_log calibrate_done_charge_100_wait_1h_log
		i18n_log calibrate_health_snapshot_log "$(get_battery_health)" "$(get_voltage)" "$(get_battery_temperature)"

		# Wait before discharging to target level
		change_magsafe_led_color "green"
		sleep 3600 &
		wait $!
		ha_webhook "wait_1hr_done" $(get_accurate_battery_percentage) $(get_voltage) $(get_battery_health)
		i18n_notify title_calibration calibrate_done_wait_1h_discharge_target_notify "$setting"
		i18n_log calibrate_done_wait_1h_log
		i18n_log calibrate_start_discharge_target_log
		i18n_log calibrate_health_snapshot_log "$(get_battery_health)" "$(get_voltage)" "$(get_battery_temperature)"

		# Discharge battery to maintain percentage%
		$battery_binary discharge $setting &
		pid_child="$!"
		wait $!
		if [[ $? != 0 ]]; then
			ha_webhook "err_discharge_target"
			i18n_notify title_calibration_error calibrate_fail_discharge_target "$setting"
			i18n_log calibrate_error_discharge_target_log "$setting"

			print_calibrate_log $calibrate_time No $health_before %
			i18n_echo calibrate_fail_discharge_target "$setting" >> $calibrate_log

			rm $calibrate_pidfile 2>/dev/null
			$battery_binary maintain recover # Recover old maintain status
			exit 1
		fi
		pid_child=""
	else
		ha_webhook "start" $(get_accurate_battery_percentage) $(get_voltage) $(get_battery_health) # inform HA calibration has started
		i18n_notify title_calibration calibrate_start_charge_100_notify
		i18n_log calibrate_start_charge_100_log

		# Suspend the maintaining
		$battery_binary maintain suspend
		
		# Enable battery charging to 100%
		$battery_binary charge 100 &
		pid_child="$!"
		wait $!
		if [[ $? != 0 ]]; then
			ha_webhook "err_charge100"
			i18n_notify title_calibration_error calibrate_fail_charge_100
			i18n_log calibrate_error_charge_100_log

			print_calibrate_log $calibrate_time No $health_before %
			i18n_echo calibrate_fail_charge_100 >> $calibrate_log

			rm $calibrate_pidfile 2>/dev/null
			$battery_binary maintain recover # Recover old maintain status
			exit 1
		fi
		pid_child=""

		ha_webhook "charge100_end" $(get_accurate_battery_percentage) $(get_voltage) $(get_battery_health)
		i18n_notify title_calibration calibrate_done_charge_100_wait_1h_notify
		i18n_log calibrate_done_charge_100_wait_1h_log
		i18n_log calibrate_health_snapshot_log "$(get_battery_health)" "$(get_voltage)" "$(get_battery_temperature)"

		# Wait before discharging to 15%
		change_magsafe_led_color "green"
		sleep 3600 &
		wait $!
		ha_webhook "wait_1hr_done" $(get_accurate_battery_percentage) $(get_voltage) $(get_battery_health)
		
		i18n_notify title_calibration calibrate_done_wait_1h_discharge_15_notify
		i18n_log calibrate_done_wait_1h_log
		i18n_log calibrate_start_discharge_15_phase_log
		i18n_log calibrate_health_snapshot_log "$(get_battery_health)" "$(get_voltage)" "$(get_battery_temperature)"

		# Discharge battery to 15%
		ha_webhook "discharge15_start" $(get_accurate_battery_percentage) $(get_voltage) $(get_battery_health)
		$battery_binary discharge 15 &
		pid_child="$!"
		wait $!
		if [[ $? != 0 ]]; then
			ha_webhook "err_discharge15"
			i18n_notify title_calibration_error calibrate_fail_discharge_15
			i18n_log calibrate_error_discharge_15_log
			rm $calibrate_pidfile 2>/dev/null
			$battery_binary maintain recover # Recover old maintain status
			exit 1
		fi
		pid_child=""

		ha_webhook "discharge15_end" $(get_accurate_battery_percentage) $(get_voltage) $(get_battery_health)
		i18n_notify title_calibration calibrate_done_discharge_15_charge_target_notify "$setting"
		i18n_log calibrate_done_discharge_15_log
		i18n_log calibrate_start_charge_target_log
		i18n_log calibrate_health_snapshot_log "$(get_battery_health)" "$(get_voltage)" "$(get_battery_temperature)"
		
		# Charge battery to maintain percentage%
		$battery_binary charge $setting &
		pid_child="$!"
		wait $!
		if [[ $? != 0 ]]; then
			ha_webhook "err_charge_target"
			i18n_notify title_calibration_error calibrate_fail_charge_target "$setting"
			i18n_log calibrate_error_charge_target_log "$setting"
			rm $calibrate_pidfile 2>/dev/null
			$battery_binary maintain recover # Recover old maintain status
			exit 1
		fi
		pid_child=""
	fi

	ha_webhook "calibration_end" $(get_accurate_battery_percentage) $(get_voltage) $(get_battery_health)

	end_t=`date +%s`
	diff=$((end_t-$start_t))

	n_days_count=$((diff/(24*60*60)))
	n_hours_count=$(((diff/(60*60)) % 24))
	n_minutes_count=$(((diff/60) % 60))
	n_seconds_count=$((diff % 60))
	if [[ $n_days_count -gt 0 ]]; then
		n_days=$(i18n_format duration_days_part "$n_days_count")
	else
		n_days=""
	fi
	n_hours=$(i18n_format duration_hours_part "$n_hours_count")
	n_minutes=$(i18n_format duration_minutes_part "$n_minutes_count")
	n_seconds=$(i18n_format duration_seconds_part "$n_seconds_count")

	i18n_notify title_calibration calibrate_completed_notify "$n_days" "$n_hours" "$n_minutes" "$(get_accurate_battery_percentage)" "$(get_voltage)" "$(get_battery_temperature)" "$(get_battery_health)" "$(get_cycle)"
	i18n_log calibrate_completed_log "$n_days" "$n_hours" "$n_minutes" "$n_seconds"
	i18n_log calibrate_completed_battery_log "$(get_accurate_battery_percentage)" "$(get_voltage)" "$(get_battery_temperature)"
	i18n_log calibrate_completed_health_log "$(get_battery_health)" "$(get_cycle)"
	
	print_calibrate_log $calibrate_time Yes $health_before $(get_battery_health)%
	echo "$n_days$n_hours $n_minutes $n_seconds" >> $calibrate_log

	rm $calibrate_pidfile 2>/dev/null
	$battery_binary maintain recover # Recover old maintain status
	exit 0
fi

# Status logger
if [[ "$action" == "status" ]]; then

	echo
	status_percent=$(get_accurate_battery_percentage)
	status_voltage=$(get_voltage)
	status_temp=$(get_battery_temperature)
	case $(get_charging_status) in
		"0")
			i18n_log status_battery_no_charging "$status_percent" "$status_voltage" "$status_temp";;
		"1")
			i18n_log status_battery_charging "$status_percent" "$status_voltage" "$status_temp";;
		"2")
			i18n_log status_battery_discharging "$status_percent" "$status_voltage" "$status_temp";;
	esac

	i18n_log status_health_cycle "$(get_battery_health)" "$(get_cycle)"

	if [[ "$(maintain_is_running)" == "1" ]]; then
		maintain_percentage=$(read_config maintain_percentage)
		maintain_status=$(echo $(cat "$pidfile" 2>/dev/null) | awk '{print $2}')
		if [[ "$maintain_status" == "active" ]]; then
			if [[ $maintain_percentage ]]; then
				upper_limit=$(echo $maintain_percentage | awk '{print $1}')
				lower_limit=$(echo $maintain_percentage | awk '{print $2}')
				if [[ $upper_limit ]]; then
					if ! valid_percentage "$lower_limit"; then
						lower_limit=$((upper_limit-5))
					fi
						maintain_level=$(i18n_format status_maintain_level_sailing "$upper_limit" "$lower_limit")
					fi
				fi
				i18n_log status_maintain_active "$maintain_level"
			else
				if [[ "$(calibrate_is_running)" == "1" ]]; then
					i18n_log status_maintain_suspended_calibrating
				else
					i18n_log status_maintain_suspended
				fi
			fi
		else
			i18n_log status_maintain_not_running
		fi
	
	show_schedule

	echo
	exit 0

fi

# Status logger in csv format
if [[ "$action" == "status_csv" ]]; then

	maintain_percentage=$(get_maintain_percentage)
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

	if [ $2 ]; then
		if [ $2 == "disable" ]; then
				if [[ $(read_config calibrate_schedule) ]]; then
					i18n_log schedule_disabled
					echo
					log "Disabling schedule at gui/$(id -u $USER)/com.battery_schedule.app" >> $logfile
				launchctl disable "gui/$(id -u $USER)/com.battery_schedule.app"
				launchctl unload "$schedule_path" 2> /dev/null
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
				if [[ $(read_config calibrate_schedule) ]]; then
					write_config calibrate_next $(check_next_calibration_date)
					log "Enabling schedule at gui/$(id -u $USER)/com.battery_schedule.app" >> $logfile
					launchctl enable "gui/$(id -u $USER)/com.battery_schedule.app"
				fi
			fi
			show_schedule
			exit 0
		fi
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
			valid_weekday $weekday || { i18n_log schedule_invalid_weekday; exit 1;}
	fi

	if [[ $month_period_loc ]]; then
		month_period=$(echo $@ | awk '{print $"'"$((month_period_loc+1))"'"}');
			valid_month_period $month_period || { i18n_log schedule_invalid_month_period; exit 1;}
	fi

	if [[ $week_period_loc ]]; then
		week_period=$(echo $@ | awk '{print $"'"$((week_period_loc+1))"'"}');
			valid_week_period $week_period || { i18n_log schedule_invalid_week_period; exit 1;}
	fi

	if [[ $hour_loc ]]; then
		hour=$(echo $@ | awk '{print $"'"$((hour_loc+1))"'"}');
			valid_hour $hour || { i18n_log schedule_invalid_hour; exit 1;}
	fi

	if [[ $minute_loc ]]; then
		minute=$(echo $@ | awk '{print $"'"$((minute_loc+1))"'"}');
			valid_minute $minute || { i18n_log schedule_invalid_minute; exit 1;}
	fi
	
	if [[ $day_loc ]]; then
		for i_day in {1..4}; do
			value=$(echo $schedule_day | awk '{print $"'"$((day_loc+i_day))"'"}')
			if valid_day $value; then
				days[$n_days]=$value
				n_days=$(($n_days+1))
			else
				if [[ $value -eq 29 ]] || [[ $value -eq 30 ]] || [[ $value -eq 31 ]]; then
						i18n_log schedule_invalid_day
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

	if [[ $n_days -gt 0 ]] && [[ -z $weekday ]]; then
		if [[ $month_period -eq 1 ]]; then
			log "Schedule calibration on day ${days[*]} at $hour:$minute00" >> $logfile
			write_config calibrate_schedule "Schedule calibration on day ${days[*]} at $hour:$minute00"
		else
			n_days=1
			log "Schedule calibration on day ${days[0]} every $month_period month at $hour:$minute00 starting from Month `date +%m` of Year `date +%Y`" >> $logfile
			write_config calibrate_schedule "Schedule calibration on day ${days[0]} every $month_period month at $hour:$minute00 starting from Month `date +%m` of Year `date +%Y`"
		fi
	else
		if [[ $weekday -eq 0 ]]; then # change sunday to 7
			weekday=7
		fi
		if [[ $((10#$(date +%V))) -eq 1 ]]; then # Week 1 is special, need to check if it is valid
			if [[ `date -v+7d +%Y` -gt `date +%Y` ]]; then # cross year for Week 1 if year is different after 7 days
				log "Schedule calibration on $weekday_name every $week_period week at $hour:$minute00 starting from Week $((10#`date -v-7d +%V`+1)) of Year `date +%Y`" >> $logfile
				write_config calibrate_schedule "Schedule calibration on $weekday_name every $week_period week at $hour:$minute00 starting from Week $((10#`date -v-7d +%V`+1)) of Year `date +%Y`"
			elif [[ $weekday -lt 10#`date +%u` ]]; then # weekday is before today that might be invalid for Week 1
				log "Schedule calibration on $weekday_name every $week_period week at $hour:$minute00 starting from Week $((10#`date +%V`+1)) of Year `date +%Y`" >> $logfile
				write_config calibrate_schedule "Schedule calibration on $weekday_name every $week_period week at $hour:$minute00 starting from Week $((10#`date +%V`+1)) of Year `date +%Y`"
			else
				log "Schedule calibration on $weekday_name every $week_period week at $hour:$minute00 starting from Week `date +%V` of Year `date +%Y`" >> $logfile
				write_config calibrate_schedule "Schedule calibration on $weekday_name every $week_period week at $hour:$minute00 starting from Week `date +%V` of Year `date +%Y`"
			fi
		else
			log "Schedule calibration on $weekday_name every $week_period week at $hour:$minute00 starting from Week `date +%V` of Year `date +%Y`" >> $logfile
			write_config calibrate_schedule "Schedule calibration on $weekday_name every $week_period week at $hour:$minute00 starting from Week `date +%V` of Year `date +%Y`"
		fi
	fi

	write_config calibrate_next $(check_next_calibration_date)

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
	if [[ $n_days -gt 0 ]]; then
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

	echo -e "$(i18n_format logs_cli_heading)\n"
	tail -n $amount $logfile

	echo -e "\n$(i18n_format logs_gui_heading)\n"
	tail -n $amount "$configfolder/gui.log"

	echo -e "\n$(i18n_format logs_config_heading)\n"
	ls -lah $configfolder

	echo -e "\n$(i18n_format logs_data_heading)\n"
	$battery_binary status
	$battery_binary | grep -E "v\d.*"

	exit 0

fi

# Display dailylog
if [[ "$action" == "dailylog" ]]; then

	echo
	echo -e "$(i18n_format dailylog_heading "$daily_log")\n"
	echo "$(cat $daily_log 2>/dev/null)"
	echo

	exit 0
fi

# Display ssdlog
if [[ "$action" == "ssdlog" ]]; then

	if test -f $ssd_log; then
		echo
		echo -e "$(i18n_format ssdlog_heading "$ssd_log")\n"
		echo "$(cat $ssd_log 2>/dev/null)"
		echo
	fi

	exit 0
fi

# Display calibrate logs
if [[ "$action" == "calibratelog" ]]; then

	echo
	echo -e "$(i18n_format calibratelog_heading "$calibrate_log")\n"
	echo "$(cat $calibrate_log 2>/dev/null)"
	echo

	exit 0
fi

# Show changelog of the latest version
if [[ "$action" == "changelog" ]]; then

	button_empty="                                                                                                                                                    "
	if $is_TW; then
		changelog=$(get_changelog CHANGELOG_TW)
		battery_new_version=$(get_version CHANGELOG_TW)
	else
		changelog=$(get_changelog CHANGELOG)
		battery_new_version=$(get_version CHANGELOG)
	fi
	dialog_msg=$(i18n_format update_dialog_changelog "$battery_new_version" "$changelog")
	dialog_ok=$(i18n_text dialog_button_ok)
	dialog_title=$(i18n_text title_battery_optimizer_mac)
	osascript -e 'display dialog "'"$dialog_msg"'" buttons {"'"$button_empty"'", "'"$dialog_ok"'"} default button 2 with icon note with title "'"$dialog_title"'"' >> /dev/null
	exit 0
fi


# Show version
if [[ "$action"  == "version" ]]; then
	echo -e "$BATTERY_CLI_VERSION"
	exit 0
fi


# Set language
if [[ "$action"  == "language" ]]; then
	requested_language="$2"
	normalized_language=$(normalize_language_code "$requested_language")

	if [[ -z "$requested_language" ]] || [[ "$requested_language" == "list" ]]; then
		if [[ "$CLI_LANG" == "tw" ]]; then
			log "$(i18n_format language_current_tw)"
		elif [[ "$CLI_LANG" == "cn" ]]; then
			log "$(i18n_format language_current_cn)"
		else
			log "$(i18n_format language_current_us)"
		fi
		echo "$(i18n_text language_list_header)"
		echo "$(i18n_text language_list_tw)"
		echo "$(i18n_text language_list_cn)"
		echo "$(i18n_text language_list_us)"
	elif [[ "$normalized_language" == "tw" ]]; then
		write_config language tw
		log "$(i18n_format language_changed_tw)"
	elif [[ "$normalized_language" == "cn" ]]; then
		write_config language cn
		log "$(i18n_format language_changed_cn)"
	elif [[ "$normalized_language" == "us" ]]; then
		write_config language us
		log "$(i18n_format language_changed_us)"
	else
		log "$(i18n_format language_invalid)"
		echo "$(i18n_text language_list_header)"
		echo "$(i18n_text language_list_tw)"
		echo "$(i18n_text language_list_cn)"
		echo "$(i18n_text language_list_us)"
	fi
	exit 0
fi

# Get SSD status
if [[ "$action"  == "ssd" ]]; then
	ssd_result=$(echo $(get_ssd))
	has_smartctl=$(echo $ssd_result | awk '{print $1}')
	firmware_support=$(echo $ssd_result | awk '{print $2}')
	smartinfo=$(echo $ssd_result | awk '{print $3, $4, $5, $6, $7, $8, $9, $10, $11}')
		if [[ $has_smartctl == true ]]; then
			if [[ $firmware_support == true ]]; then # run SSD log only when firmware support
				echo "$(i18n_text ssd_log_table_header)" | awk '{printf "%-10s, %6s, %11s, %12s, %5s, %12s, %11s, %16s, %11s, %5s\n", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10}'
			logd "$smartinfo" | awk '{printf "%-10s, %6s, %11s, %12s, %5s, %12s, %11s, %16s, %12s, %5s\n", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10}'
		else
				i18n_echo ssd_firmware_not_supported
			fi
		else
			i18n_echo ssd_tool_not_installed
		fi
fi
