# Battery CLI i18n Simplified Chinese catalog

if [[ -n "${BATTERY_I18N_LANG_CN_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
BATTERY_I18N_LANG_CN_LOADED=1

helpmessage_cn="

Battery CLI 工具 $BATTERY_CLI_VERSION

用法:

  battery maintain PERCENTAGE[10-100,stop,suspend,recover] SAILING_TARGET[5-99]
  - PERCENTAGE 为停止充电的上限电量百分比
  - SAILING_TARGET 为重新开始充电的下限电量百分比；未指定时，默认为 PERCENTAGE-5
    示例:
    battery maintain 80 50    # 维持在 80%，滑行至 50%
    battery maintain 80    # 等同于 battery maintain 80 75
    battery maintain stop   # 停止维持程序、停用 daemon 并恢复充电；重启后不会自动执行
    battery maintain suspend   # 暂停维持程序并恢复充电；重新接通电源后会自动恢复维持（例如旅行前暂时充到 100%）
    battery maintain recover   # 恢复电池维持程序

  battery calibrate
    将电池放电至 15%，再充电至 100%，维持 1 小时后，再放电回维持电量，完成校准
    如果笔记本上盖未开启或未接上电源，会先发送提醒通知
    当上盖开启且已接上电源后，会自动开始校准
    校准期间每个步骤完成或发生错误都会发送通知
    如果希望通知会停留直到手动关闭，请设置：
        settings > notifications > applications > Script Editor > Choose \"Alerts\"
    如果使用外接屏幕，请设置：
        system settings > notifications > check 'Allow notifications when mirroring or sharing the display'
    eg: battery calibrate   # 开始校准
    eg: battery calibrate stop # 停止校准并恢复 maintain

  battery schedule
    设置定期校准日程：每月最多 4 个日期、或每 1~12 周指定星期、或每 1~3 个月指定单一日期；默认为每月 1 号 9:00
    示例:
    battery schedule    # 每月 1 号 9:00 校准
    battery schedule day 1 8 15 22    # 每月 1、8、15、22 号 9:00 校准
    battery schedule day 3 18 hour 13    # 每月 3、18 号 13:00 校准
    battery schedule day 6 16 26 hour 18 minute 30    # 每月 6、16、26 号 18:30 校准
    battery schedule weekday 0 week_period 2 hour 21 minute 30 # 每 2 周的星期日 21:30 校准
    battery schedule day 5 month_period 3 hour 21 minute 30 # 每 3 个月的 5 号 21:00 校准
    battery schedule disable    # 禁用定期校准
    battery schedule enable    # 启用定期校准
    限制:
        1. 每月最多 4 个日期
        2. day 范围 [1-28]
        3. hour 范围 [0-23]
        4. minute 范围 [0-59]
        5. weekday 范围 [0-6] 0:Sunday, 1:Monday, ...
        6. week_period 范围 [1-12]
        7. month_period 范围 [1-3]

  battery charge LEVEL[1-100, stop]
    将电池充到指定百分比，达到后停止充电
    eg: battery charge 90
    eg: battery charge stop # 停止正在运行的 charge 进程并停止充电

  battery discharge LEVEL[1-100, stop]
    阻止电源输入，直到电池下降到指定百分比
    eg: battery discharge 90
    eg: battery discharge stop # 停止正在运行的 discharge 进程并停止放电

  battery status
    显示电池 SMC 状态、容量、温度、健康度与循环次数

  battery dailylog
    显示每日日志与日志存放位置

  battery changelog
    显示 GitHub 最新版本更新内容

  battery calibratelog
    显示校准历史

  battery logs LINES[integer, optional]
    显示 Battery CLI 与 GUI 日志
    eg: battery logs 100

  battery language LANG[tw,cn,us,en,zh-TW,zh-CN,zh-Hant,zh-Hans,list]
    eg: battery language cn     # 以简体中文显示状态与通知（若支持）
    eg: battery language zh-CN  # cn 的别名
    eg: battery language tw     # 以繁体中文显示状态与通知（若支持）
    eg: battery language zh-TW  # tw 的别名
    eg: battery language en     # us 的别名（英文）
    eg: battery language us     # 以英文显示状态与通知
    eg: battery language list   # 显示支持语言与别名

  battery ssd
    显示 SSD disk0 状态

  battery ssdlog
    显示 SSD disk0 每日日志

  battery update
    将 battery 工具更新到最新版本

  battery version
    显示当前版本

  battery reinstall
    重新安装最新版 battery 工具（重新执行安装脚本）

  battery uninstall
    恢复充电，并移除 smc 工具与 battery 脚本
"



function i18n_help_message_cn() {
	printf "%s\n" "$helpmessage_cn"
}

function i18n_schedule_display_text_cn() {
	local schedule_txt="$1"
	if ! [[ $schedule_txt =~ "week" ]]; then
		if ! [[ $schedule_txt =~ "month" ]]; then
			schedule_txt=${schedule_txt/"Schedule calibration on day"/"电池自动校准日程安排在"}
			schedule_txt=${schedule_txt/"at"/"日"}
		else
			schedule_txt=${schedule_txt/"Schedule calibration on day"/"电池自动校准日程安排在"}
			schedule_txt=${schedule_txt/"every "/"日每"}
			schedule_txt=${schedule_txt/"month at"/"个月"}
			schedule_txt=${schedule_txt%" starting"*}
		fi
	else
		schedule_txt=${schedule_txt/"Schedule calibration on"/"电池自动校准日程安排在"}
		schedule_txt=${schedule_txt/"SUN"/"星期日"}
		schedule_txt=${schedule_txt/"MON"/"星期一"}
		schedule_txt=${schedule_txt/"TUE"/"星期二"}
		schedule_txt=${schedule_txt/"WED"/"星期三"}
		schedule_txt=${schedule_txt/"THU"/"星期四"}
		schedule_txt=${schedule_txt/"FRI"/"星期五"}
		schedule_txt=${schedule_txt/"SAT"/"星期六"}
		schedule_txt=${schedule_txt/"every "/"每"}
		schedule_txt=${schedule_txt/"week at"/"周"}
		schedule_txt=${schedule_txt%" starting"*}
	fi
	printf "%s\n" "$schedule_txt 开始"
}

function i18n_text_cn() {
	local key="$1"
	case "$key" in
		invalid_action) echo "错误：未知命令 '%s'" ;;
		did_you_mean) echo "你是不是想用以下指令？" ;;
		run_battery_help) echo "执行 'battery'（不带参数）以查看可用命令列表。" ;;
		help_current_language) echo "当前语言：简体中文 (cn)" ;;
		help_i18n_note) echo "提示：CLI 说明、状态、通知与主要命令输出均已支持国际化；少量复杂对话框仍沿用既有中英分支逻辑。" ;;
		logs_cli_heading) echo "👾 Battery CLI 日志：" ;;
		logs_gui_heading) echo "🖥️ Battery GUI 日志：" ;;
		logs_config_heading) echo "📁 设置文件夹内容：" ;;
		logs_data_heading) echo "⚙️ Battery 状态数据：" ;;
		dailylog_heading) echo "每日日志 (%s)" ;;
		ssdlog_heading) echo "SSD 每日日志 (%s)" ;;
		calibratelog_heading) echo "校准日志 (%s)" ;;
		language_list_header) echo "支持的语言（可用别名）：" ;;
		language_list_tw) echo "  - tw / zh-TW / zh_TW / zh-Hant -> 繁体中文" ;;
		language_list_cn) echo "  - cn / zh-CN / zh_CN / zh-Hans -> 简体中文" ;;
		language_list_us) echo "  - us / en / en-US -> English" ;;
		language_current_tw) echo "当前设置语言：繁体中文 (tw)" ;;
		language_current_cn) echo "当前设置语言：简体中文 (cn)" ;;
		language_current_us) echo "当前设置语言：英文 (us)" ;;
		language_changed_tw) echo "显示语言改为繁体中文" ;;
		language_changed_cn) echo "显示语言改为简体中文" ;;
		language_changed_us) echo "显示语言改为英文" ;;
		language_invalid) echo "指定语言无效。仅支持 [tw, cn, us]（也接受 en、zh-TW、zh-CN 等别名）" ;;
		charge_invalid_setting) echo "错误：%s 不是有效的 battery charge 设置。请使用 0 到 100 的数字" ;;
		charge_start) echo "开始充电至 %s%%（目前 %s%%）" ;;
		charge_progress) echo "电池目前 %s%%（目标 %s%%）" ;;
		charge_completed) echo "电池已充电至 %s%%" ;;
		charge_abnormal) echo "错误：电池充电异常" ;;
		discharge_invalid_setting) echo "错误：%s 不是有效的 battery discharge 设置。请使用 0 到 100 的数字" ;;
		discharge_lid_open_required) echo "错误：放电前必须先打开笔记本上盖" ;;
		discharge_start) echo "开始放电至 %s%%（目前 %s%%）" ;;
		discharge_progress) echo "电池目前 %s%%（目标 %s%%）" ;;
		discharge_completed) echo "电池已放电至 %s%%" ;;
		discharge_abnormal) echo "错误：电池放电异常" ;;
		maintain_recovering_percentage) echo "恢复电池优化设置 %s" ;;
		maintain_no_setting_to_recover) echo "没有可恢复的设置，结束" ;;
		maintain_invalid_setting) echo "错误：%s 不是有效的 battery maintain 设置。请使用 0 到 100 的数字" ;;
		maintain_invalid_setting_with_keywords) echo "错误：%s 不是有效的 battery maintain 设置。请使用 0 到 100 的数字，或 'stop' / 'recover' 等动作关键字。" ;;
		maintain_invalid_sailing_target) echo "错误：滑行目标 %s 不可大于或等于维持上限 %s" ;;
		maintain_start) echo "开始电池优化：维持 %s%%，滑行至 %s%% %s" ;;
		maintain_lid_open_required) echo "错误：放电前必须先打开笔记本上盖" ;;
		maintain_trigger_force_discharge) echo "启用充电限制前，先放电至 %s%%" ;;
		maintain_force_discharge_done) echo "预先放电完成，继续进入维持循环" ;;
		maintain_force_discharge_skipped) echo "未要求预先放电，跳过" ;;
		maintain_charging_and_maintaining) echo "开始充电并维持在 %s%%（目前 %s%%）" ;;
		maintain_recover_wait) echo "5 秒内恢复，请稍等 ." ;;
		maintain_suspend_wait) echo "5 秒内暂停，请稍等 ." ;;
		maintain_recovered) echo "电池优化已恢复" ;;
		maintain_recovered_ac_reconnected) echo "重新接通电源，电池优化已恢复" ;;
		maintain_recover_failed) echo "错误：电池优化恢复失败" ;;
		maintain_already_running) echo "电池优化已在执行中" ;;
		maintain_not_running) echo "电池优化未在执行" ;;
		maintain_suspended) echo "电池优化已暂停" ;;
		maintain_suspend_failed) echo "错误：电池优化暂停失败" ;;
		maintain_calibration_process_stopped) echo "🚨 已停止校准程序" ;;
		maintain_start_discharge_now) echo "开始放电至 %s%%" ;;
		status_battery_no_charging) echo "电池目前 %s%%, %sV, %s°C, 暂停充电" ;;
		status_battery_charging) echo "电池目前 %s%%, %sV, %s°C, 充电中" ;;
		status_battery_discharging) echo "电池目前 %s%%, %sV, %s°C, 放电中" ;;
		status_health_cycle) echo "电池健康度 %s%%, 循环次数 %s" ;;
		status_maintain_level_sailing) echo "%s%% 滑行至 %s%%" ;;
		status_maintain_active) echo "你的电池当前维持在 %s" ;;
		status_maintain_suspended_calibrating) echo "校准进行中，电池优化已暂停" ;;
		status_maintain_suspended) echo "电池优化已暂停" ;;
		status_maintain_not_running) echo "电池优化已经停止运行" ;;
		title_battery) echo "电池" ;;
		title_battery_optimizer) echo "BatteryOptimizer" ;;
		title_battery_optimizer_mac) echo "BatteryOptimizer for MAC" ;;
		title_calibration) echo "电池校准" ;;
		title_calibration_error) echo "电池校准错误" ;;
		dialog_button_ok) echo "OK" ;;
		dialog_button_continue) echo "继续" ;;
		dialog_button_yes) echo "Yes" ;;
		dialog_button_no) echo "No" ;;
		dialog_button_update_now) echo "立即更新" ;;
		dialog_button_skip_version) echo "跳过此版本" ;;
		press_any_key_continue) echo "按任意键继续" ;;
		reinstall_preview) echo "这将执行 curl -sS %s/setup.sh | bash" ;;
		uninstall_preview) echo "这会恢复充电，并移除 smc 工具与 battery 脚本" ;;
		visudo_set_owner) echo "设置 visudo 文件权限给 %s" ;;
		visudo_already_current) echo "当前 battery visudo 文件已符合版本 %s 的要求" ;;
		visudo_updated_success) echo "Visudo 文件更新成功" ;;
		visudo_validate_error) echo "验证 visudo 文件时发生错误（理论上不应发生）：" ;;
		update_specified_file_missing) echo "错误：指定的更新文件不存在" ;;
		update_dialog_latest) echo "%s 已是最新版，不需要更新" ;;
		update_dialog_changelog) echo "%s 更新内容如下\n\n%s" ;;
		update_dialog_confirm) echo "你现在要更新到%s 吗?" ;;
		daily_log_table_header) echo "时间 容量 电压 温度 健康度 循环次数" ;;
		ssd_log_table_header) echo "日期 结果 读取量 写入量 已用度 电源循环 通电时数 非正常关机 温度 错误" ;;
		calibrate_log_table_header) echo "时间 已完成 校准前健康度 校准后健康度 耗时/错误" ;;
		notify_battery_monthly_summary) echo "电池目前 %s%%, %sV, %s°C\n健康度 %s%%, 循环次数 %s" ;;
		notify_calibration_tomorrow) echo "提醒你，明天 (%s) 将进行电池校准" ;;
		notify_calibration_today) echo "提醒你，今天 (%s) 将进行电池校准" ;;
		notify_update_available) echo "发现新版本 %s，请在 Terminal 中输入 \n\\\"battery update\\\" 更新" ;;
		aldente_conflict_detected) echo "检测到 AlDente 正在运行，将其关闭以避免冲突" ;;
		maintain_stop_charge_above) echo "高于 %s%% 停止充电" ;;
		maintain_start_charge_below) echo "低于 %s%% 开始充电" ;;
		maintain_prompt_discharge_now) echo "你要现在就放电到 %s%% 吗?" ;;
		schedule_disabled) echo "电池自动校准日程已暂停" ;;
		schedule_not_set) echo "你还没有设置电池自动校准日程" ;;
		schedule_disabled_enable_by) echo "你的电池自动校准日程已暂停，可执行以下命令恢复" ;;
		schedule_next_date) echo "下次校准日期是 %s" ;;
		schedule_invalid_weekday) echo "错误：weekday 必须在 [0..6]" ;;
		schedule_invalid_month_period) echo "错误：month_period 必须在 [1..3]" ;;
		schedule_invalid_week_period) echo "错误：week_period 必须在 [1..12]" ;;
		schedule_invalid_hour) echo "错误：hour 必须在 [0..23]" ;;
		schedule_invalid_minute) echo "错误：minute 必须在 [0..59]" ;;
		schedule_invalid_day) echo "错误：day 必须在 [1..28]" ;;
		calibrate_skip_run) echo "跳过本次校准" ;;
		calibrate_stop_running) echo "停止正在运行的校准进程" ;;
		calibrate_require_maintain_before) echo "校准前必须先执行 battery maintain" ;;
		calibrate_error_require_maintain_before_log) echo "校准错误：校准前必须先执行 battery maintain" ;;
		calibrate_wait_open_lid_ac_notify) echo "准备进行电池校准, 您打开笔记本上盖并接上电源后将立刻开始" ;;
		calibrate_wait_open_lid_ac_log) echo "校准：请打开笔记本上盖并接上电源以开始校准" ;;
		calibrate_lid_not_open) echo "笔记本上盖没打开" ;;
		calibrate_error_lid_not_open_log) echo "校准错误：笔记本上盖没打开" ;;
		calibrate_no_ac_power) echo "电源没接" ;;
		calibrate_error_no_ac_power_log) echo "校准错误：未接上电源" ;;
		calibrate_no_ac_power_logfile) echo "未接上电源" ;;
		calibrate_start_discharge_15_notify) echo "校准开始! \n开始放电至15%%" ;;
		calibrate_start_discharge_15_log) echo "校准：校准开始，开始放电至 15%%" ;;
		calibrate_fail_discharge_15) echo "未成功放电至15%%" ;;
		calibrate_error_discharge_15_log) echo "校准错误：未成功放电至15%%" ;;
		calibrate_done_discharge_15_charge_100_notify) echo "已放电至15%% \n开始充电到100%%" ;;
		calibrate_done_discharge_15_charge_100_log) echo "校准：已放电至 15%%，开始充电到 100%%" ;;
		calibrate_fail_charge_100) echo "未成功充电至100%%" ;;
		calibrate_error_charge_100_log) echo "校准错误：未成功充电至100%%" ;;
		calibrate_done_charge_100_wait_1h_notify) echo "已充电至100%% \n等待一小时" ;;
		calibrate_done_charge_100_wait_1h_log) echo "校准：已充电至 100%%，等待一小时" ;;
		calibrate_done_wait_1h_log) echo "校准：电池已维持在 100%% 一小时" ;;
		calibrate_start_discharge_target_log) echo "校准：开始放电至维持电量" ;;
		calibrate_done_wait_1h_discharge_target_notify) echo "电池已维持在 100%% 一小时 \n开始放电至 %s%%" ;;
		calibrate_fail_discharge_target) echo "未成功放电至 %s%%" ;;
		calibrate_error_discharge_target_log) echo "校准错误：未成功放电至 %s%%" ;;
		calibrate_start_charge_100_notify) echo "校准开始！ \n准备充电至 100%%" ;;
		calibrate_start_charge_100_log) echo "校准：校准开始，开始充电至 100%%" ;;
		calibrate_done_wait_1h_discharge_15_notify) echo "电池已维持在 100%% 一小时 \n开始放电至 15%%" ;;
		calibrate_start_discharge_15_phase_log) echo "校准：开始放电至 15%%" ;;
		calibrate_done_discharge_15_log) echo "校准：已放电至 15%%" ;;
		calibrate_start_charge_target_log) echo "校准：开始充电至维持电量" ;;
		calibrate_done_discharge_15_charge_target_notify) echo "已放电至 15%% \n开始充电至 %s%%" ;;
		calibrate_fail_charge_target) echo "未成功充电至 %s%%" ;;
		calibrate_error_charge_target_log) echo "校准错误：未成功充电至 %s%%" ;;
		calibrate_health_snapshot_log) echo "电池健康度 %s%%, %sV, %s°C" ;;
		duration_days_part) echo "%s 天 " ;;
		duration_hours_part) echo "%s 小时" ;;
		duration_minutes_part) echo "%s 分" ;;
		duration_seconds_part) echo "%s 秒" ;;
		calibrate_completed_notify) echo "校准完成, 共花 %s%s %s\n电池目前 %s%%, %sV, %s°C\n健康度 %s%%, 循环次数 %s" ;;
		calibrate_completed_log) echo "校准完成, 共花 %s%s %s %s." ;;
		calibrate_completed_battery_log) echo "电池目前 %s%%, %sV, %s°C" ;;
		calibrate_completed_health_log) echo "健康度 %s%%, 循环次数 %s" ;;
		ssd_firmware_not_supported) echo "你的 SMART 固件目前不支持。" ;;
		ssd_tool_not_installed) echo "你的 Mac 尚未安装 SMART 监控工具，可执行 \\\"brew install smartmontools\\\" 安装。" ;;
		*) return 1 ;;
	esac
}
