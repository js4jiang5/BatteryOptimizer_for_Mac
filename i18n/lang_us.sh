# Battery CLI i18n English catalog

if [[ -n "${BATTERY_I18N_LANG_US_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
BATTERY_I18N_LANG_US_LOADED=1

helpmessage="

Battery CLI utility $BATTERY_CLI_VERSION

Usage:

  battery maintain PERCENTAGE[10-100,stop,suspend,recover] SAILING_TARGET[5-99]
  - PERCENTAGE is battery level upper bound above which charging is stopped
  - SAILING_TARGET is battery level lower bound below which charging is started. default value is PERCENTAGE-5 if not specified
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
        settings > notifications > applications > Script Editor > Choose "Alerts"
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

  battery charge LEVEL[1-100, stop]
    charge the battery to a certain percentage, and disable charging when that percentage is reached
    eg: battery charge 90
    eg: battery charge stop # kill running battery charge process and stop charging

  battery discharge LEVEL[1-100, stop]
    block power input from the adapter until battery falls to this level
    eg: battery discharge 90
    eg: battery discharge stop # kill running battery discharge process and stop discharging

  battery status
    output battery SMC status, capacity, temperature, health, and cycle count 

  battery dailylog
    output daily log and show daily log store location

  battery changelog
    show the changelog of the latest version on Github

  battery calibratelog
    show calibrate history

  battery logs LINES[integer, optional]
    output logs of the battery CLI and GUI
    eg: battery logs 100

  battery language LANG[tw,cn,us,en,zh-TW,zh-CN,zh-Hant,zh-Hans,list]
    eg: battery language cn     # show status and notification in Simplified Chinese if available
    eg: battery language zh-CN  # alias of cn
    eg: battery language tw     # show status and notification in traditional Chinese if available
    eg: battery language zh-TW  # alias of tw
    eg: battery language en     # alias of us (English)
    eg: battery language us     # show status and notification in English
    eg: battery language list   # list supported language aliases

  battery ssd
    show SSD disk0 status

  battery ssdlog
    show SSD disk0 dailylog

  battery update
    update the battery utility to the latest version

  battery version
    show current version

  battery reinstall
    reinstall the battery utility to the latest version (reruns the installation script)

  battery uninstall
    enable charging, remove the smc tool, and the battery script

"


function i18n_help_message_us() {
	printf "%s\n" "$helpmessage"
}

function i18n_schedule_display_text_us() {
	local schedule_txt="$1"
	schedule_txt=${schedule_txt%" starting"*}
	printf "%s\n" "$schedule_txt"
}

function i18n_text_us() {
	local key="$1"
	case "$key" in
		invalid_action) echo "Error: Unknown command '%s'" ;;
		did_you_mean) echo "Did you mean one of these?" ;;
		run_battery_help) echo "Run 'battery' without parameters, for list of valid commands." ;;
		help_current_language) echo "Current language: English (us)" ;;
		help_i18n_note) echo "Note: CLI help, status, notifications, and major command outputs are localized; a few complex dialogs still use legacy TW/EN branch logic." ;;
		logs_cli_heading) echo "👾 Battery CLI logs:" ;;
		logs_gui_heading) echo "🖥️ Battery GUI logs:" ;;
		logs_config_heading) echo "📁 Config folder details:" ;;
		logs_data_heading) echo "⚙️ Battery data:" ;;
		dailylog_heading) echo "Daily log (%s)" ;;
		ssdlog_heading) echo "SSD daily log (%s)" ;;
		calibratelog_heading) echo "Calibrate log (%s)" ;;
		language_list_header) echo "Supported languages (accepted aliases):" ;;
		language_list_tw) echo "  - tw / zh-TW / zh_TW / zh-Hant -> Traditional Chinese" ;;
		language_list_cn) echo "  - cn / zh-CN / zh_CN / zh-Hans -> Simplified Chinese" ;;
		language_list_us) echo "  - us / en / en-US -> English" ;;
		language_current_tw) echo "Current language setting: Traditional Chinese (tw)" ;;
		language_current_cn) echo "Current language setting: Simplified Chinese (cn)" ;;
		language_current_us) echo "Current language setting: English (us)" ;;
		language_changed_tw) echo "Change language to Traditional Chinese" ;;
		language_changed_cn) echo "Change language to Simplified Chinese" ;;
		language_changed_us) echo "Change language to English" ;;
		language_invalid) echo "Specified language is not recognized. Supported values: [tw, cn, us] (aliases like en, zh-TW, zh-CN are accepted)" ;;
		charge_invalid_setting) echo "Error: %s is not a valid setting for battery charge. Please use a number between 0 and 100" ;;
		charge_start) echo "Charging to %s%% from %s%%" ;;
		charge_progress) echo "Battery at %s%% (target %s%%)" ;;
		charge_completed) echo "Charging completed at %s%%" ;;
		charge_abnormal) echo "Error: battery charge abnormal" ;;
		discharge_invalid_setting) echo "Error: %s is not a valid setting for battery discharge. Please use a number between 0 and 100" ;;
		discharge_lid_open_required) echo "Error: macbook lid must be open before discharge" ;;
		discharge_start) echo "Discharging to %s%% from %s%%" ;;
		discharge_progress) echo "Battery at %s%% (target %s%%)" ;;
		discharge_completed) echo "Discharging completed at %s%%" ;;
		discharge_abnormal) echo "Error: battery discharge abnormal" ;;
		maintain_recovering_percentage) echo "Recovering maintenance percentage %s" ;;
		maintain_no_setting_to_recover) echo "No setting to recover, exiting" ;;
		maintain_invalid_setting) echo "Error: %s is not a valid setting for battery maintain. Please use a number between 0 and 100" ;;
		maintain_invalid_setting_with_keywords) echo "Error: %s is not a valid setting for battery maintain. Please use a number between 0 and 100, or an action keyword like 'stop' or 'recover'." ;;
		maintain_invalid_sailing_target) echo "Error: sailing target %s larger than or equal to maintain level %s is not allowed" ;;
		maintain_start) echo "Starting battery maintenance at %s%% with sailing to %s%% %s" ;;
		maintain_lid_open_required) echo "Error: macbook lid must be open before discharge" ;;
		maintain_trigger_force_discharge) echo "Triggering discharge to %s before enabling charging limiter" ;;
		maintain_force_discharge_done) echo "Discharge pre battery maintenance complete, continuing to battery maintenance loop" ;;
		maintain_force_discharge_skipped) echo "Not triggering discharge as it is not requested" ;;
		maintain_charging_and_maintaining) echo "Charging to and maintaining at %s%% from %s%%" ;;
		maintain_recover_wait) echo "Recover in 5 secs, wait ." ;;
		maintain_suspend_wait) echo "Suspend in 5 secs, wait ." ;;
		maintain_recovered) echo "Battery maintain is recovered" ;;
		maintain_recovered_ac_reconnected) echo "Battery maintain is recovered because AC adapter is reconnected" ;;
		maintain_recover_failed) echo "Error: Battery maintain recover failed" ;;
		maintain_already_running) echo "Battery maintain is already running" ;;
		maintain_not_running) echo "Battery maintain is not running" ;;
		maintain_suspended) echo "Battery maintain is suspended" ;;
		maintain_suspend_failed) echo "Error: Battery maintain suspend failed" ;;
		maintain_calibration_process_stopped) echo "🚨 Calibration process have been stopped" ;;
		maintain_start_discharge_now) echo "Start discharging to %s%%" ;;
		status_battery_no_charging) echo "Battery at %s%%, %sV, %s°C, no charging" ;;
		status_battery_charging) echo "Battery at %s%%, %sV, %s°C, charging" ;;
		status_battery_discharging) echo "Battery at %s%%, %sV, %s°C, discharging" ;;
		status_health_cycle) echo "Battery health %s%%, Cycle %s" ;;
		status_maintain_level_sailing) echo "%s%% with sailing to %s%%" ;;
		status_maintain_active) echo "Your battery is currently being maintained at %s" ;;
		status_maintain_suspended_calibrating) echo "Calibration ongoing, battery maintain is suspended" ;;
		status_maintain_suspended) echo "Battery maintain is suspended" ;;
		status_maintain_not_running) echo "Battery maintain is not running" ;;
		title_battery) echo "Battery" ;;
		title_battery_optimizer) echo "BatteryOptimizer" ;;
		title_battery_optimizer_mac) echo "BatteryOptimizer for MAC" ;;
		title_calibration) echo "Battery Calibration" ;;
		title_calibration_error) echo "Battery Calibration Error" ;;
		dialog_button_ok) echo "OK" ;;
		dialog_button_continue) echo "Continue" ;;
		dialog_button_yes) echo "Yes" ;;
		dialog_button_no) echo "No" ;;
		dialog_button_update_now) echo "Yes" ;;
		dialog_button_skip_version) echo "No" ;;
		press_any_key_continue) echo "Press any key to continue" ;;
		reinstall_preview) echo "This will run curl -sS %s/setup.sh | bash" ;;
		uninstall_preview) echo "This will enable charging, and remove the smc tool and battery script" ;;
		visudo_set_owner) echo "Setting visudo file permissions to %s" ;;
		visudo_already_current) echo "The existing battery visudo file is what it should be for version %s" ;;
		visudo_updated_success) echo "Visudo file updated successfully" ;;
		visudo_validate_error) echo "Error validating visudo file, this should never happen:" ;;
		update_specified_file_missing) echo "Error: the specified update file is not available" ;;
		update_dialog_latest) echo "Your version %s is already the latest. No need to update." ;;
		update_dialog_changelog) echo "%s changes include\n\n%s" ;;
		update_dialog_confirm) echo "Do you want to update to version %s now?" ;;
		daily_log_table_header) echo "Time Capacity Voltage Temperature Health Cycle" ;;
		ssd_log_table_header) echo "Date Result Data_Read Data_Written Used Power_Cycles Power_Hours Unsafe_Shutdowns Temperature Error" ;;
		calibrate_log_table_header) echo "Time Completed Health_before Health_after Duration/Error" ;;
		notify_battery_monthly_summary) echo "Battery %s%%, %sV, %s°C\nHealth %s%%, Cycle %s" ;;
		notify_calibration_tomorrow) echo "Remind you, tomorrow (%s) is battery calibration day." ;;
		notify_calibration_today) echo "Remind you, today (%s) is battery calibration day." ;;
		notify_update_available) echo "New version %s available \nUpdate with command \\\"battery update\\\"" ;;
		aldente_conflict_detected) echo "AlDente is running. Turn it off" ;;
		maintain_stop_charge_above) echo "Stop charge above %s" ;;
		maintain_start_charge_below) echo "Charge below %s" ;;
		maintain_prompt_discharge_now) echo "Do you want to discharge battery to %s%% now?" ;;
		schedule_disabled) echo "Schedule disabled" ;;
		schedule_not_set) echo "You haven't scheduled calibration yet" ;;
		schedule_disabled_enable_by) echo "Your calibration schedule is disabled. Enable it by" ;;
		schedule_next_date) echo "Next calibration date is %s" ;;
		schedule_invalid_weekday) echo "Error: weekday must be in [0..6]" ;;
		schedule_invalid_month_period) echo "Error: month_period must be in [1..3]" ;;
		schedule_invalid_week_period) echo "Error: week_period must be in [1..12]" ;;
		schedule_invalid_hour) echo "Error: hour must be in [0..23]" ;;
		schedule_invalid_minute) echo "Error: minute must be in [0..59]" ;;
		schedule_invalid_day) echo "Error: day must be in [1..28]" ;;
		calibrate_skip_run) echo "Skip this calibration" ;;
		calibrate_stop_running) echo "Killing running calibration daemon" ;;
		calibrate_require_maintain_before) echo "Battery maintain need to run before calibration" ;;
		calibrate_error_require_maintain_before_log) echo "Calibration Error: Battery maintain need to run before calibration" ;;
		calibrate_wait_open_lid_ac_notify) echo "Battery calibration will start immediately after you open macbook lid and connect AC power" ;;
		calibrate_wait_open_lid_ac_log) echo "Calibration: Please open macbook lid and connect AC to start calibration" ;;
		calibrate_lid_not_open) echo "Macbook lid is not open!" ;;
		calibrate_error_lid_not_open_log) echo "Calibration Error: Macbook lid is not open!" ;;
		calibrate_no_ac_power) echo "No AC power!" ;;
		calibrate_error_no_ac_power_log) echo "Calibration Error: Macbook has no AC power!" ;;
		calibrate_no_ac_power_logfile) echo "Macbook has no AC power!" ;;
		calibrate_start_discharge_15_notify) echo "Calibration has started! \nStart discharging to 15%%" ;;
		calibrate_start_discharge_15_log) echo "Calibration: Calibration has started! Start discharging to 15%%" ;;
		calibrate_fail_discharge_15) echo "Discharge to 15%% fail" ;;
		calibrate_error_discharge_15_log) echo "Calibration Error: Discharge to 15%% fail" ;;
		calibrate_done_discharge_15_charge_100_notify) echo "Calibration has discharged to 15%% \nStart charging to 100%%" ;;
		calibrate_done_discharge_15_charge_100_log) echo "Calibration: Calibration has discharged to 15%%. Start charging to 100%%" ;;
		calibrate_fail_charge_100) echo "Charge to 100%% fail" ;;
		calibrate_error_charge_100_log) echo "Calibration Error: Charge to 100%% fail" ;;
		calibrate_done_charge_100_wait_1h_notify) echo "Calibration has charged to 100%% \nWaiting for one hour" ;;
		calibrate_done_charge_100_wait_1h_log) echo "Calibration: Calibration has charged to 100%%. Waiting for one hour" ;;
		calibrate_done_wait_1h_log) echo "Calibration: Battery has been maintained at 100%% for one hour" ;;
		calibrate_start_discharge_target_log) echo "Calibration: Start discharging to maintain percentage" ;;
		calibrate_done_wait_1h_discharge_target_notify) echo "Battery has been maintained at 100%% for one hour \nStart discharging to %s%%" ;;
		calibrate_fail_discharge_target) echo "Discharge to %s%% fail" ;;
		calibrate_error_discharge_target_log) echo "Calibration Error: Discharge to %s%% fail" ;;
		calibrate_start_charge_100_notify) echo "Calibration has started! \nStart charging to 100%%" ;;
		calibrate_start_charge_100_log) echo "Calibration: Calibration has started! Start charging to 100%%" ;;
		calibrate_done_wait_1h_discharge_15_notify) echo "Battery has been maintained at 100%% for one hour \nStart discharging to 15%%" ;;
		calibrate_start_discharge_15_phase_log) echo "Calibration: Start discharging to 15%%" ;;
		calibrate_done_discharge_15_log) echo "Calibration: Calibration has discharged to 15%%" ;;
		calibrate_start_charge_target_log) echo "Calibration: Start charging to maintain percentage" ;;
		calibrate_done_discharge_15_charge_target_notify) echo "Calibration has discharged to 15%% \nStart charging to %s%%" ;;
		calibrate_fail_charge_target) echo "Charge to %s%% fail" ;;
		calibrate_error_charge_target_log) echo "Calibration Error: Charge to %s%% fail" ;;
		calibrate_health_snapshot_log) echo "Battery health %s%%, %sV, %s°C" ;;
		duration_days_part) echo "%s day " ;;
		duration_hours_part) echo "%s hour" ;;
		duration_minutes_part) echo "%s min" ;;
		duration_seconds_part) echo "%s sec" ;;
		calibrate_completed_notify) echo "Calibration completed in %s%s %s.\nBattery %s%%, %sV, %s°C\nHealth %s%%, Cycle %s" ;;
		calibrate_completed_log) echo "Calibration completed in %s%s %s %s." ;;
		calibrate_completed_battery_log) echo "Battery %s%%, %sV, %s°C" ;;
		calibrate_completed_health_log) echo "Health %s%%, Cycle %s" ;;
		ssd_firmware_not_supported) echo "Your SMART firmware is not supported." ;;
		ssd_tool_not_installed) echo "SMART monitor tool is not available in your Mac. You may run \\\"brew install smartmontools\\\" to get it." ;;
		*) return 1 ;;
	esac
}
