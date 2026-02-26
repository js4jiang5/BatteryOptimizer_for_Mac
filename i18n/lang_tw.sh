# Battery CLI i18n Traditional Chinese catalog

if [[ -n "${BATTERY_I18N_LANG_TW_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
BATTERY_I18N_LANG_TW_LOADED=1

helpmessage_tw="

Battery CLI 工具 $BATTERY_CLI_VERSION

用法:

  battery maintain PERCENTAGE[10-100,stop,suspend,recover] SAILING_TARGET[5-99]
  - PERCENTAGE 為停止充電的上限電量百分比
  - SAILING_TARGET 為重新開始充電的下限電量百分比；若未指定，預設為 PERCENTAGE-5
    範例:
    battery maintain 80 50    # 維持在 80%，滑行至 50%
    battery maintain 80    # 等同於 battery maintain 80 75
    battery maintain stop   # 停止維持程序、停用 daemon 並恢復充電；重開機後不會自動執行
    battery maintain suspend   # 暫停維持程序並恢復充電；重新接上電源後會自動恢復維持（例如旅行前暫時充到 100%）
    battery maintain recover   # 恢復電池維持程序

  battery calibrate
    將電池放電至 15%，再充電至 100%，維持 1 小時後，再放電回維持電量，完成校正
    若筆電上蓋未開啟或未接上電源，會先發送提醒通知
    當上蓋開啟且已接上電源後，會自動開始校正
    校正期間每個步驟完成或發生錯誤都會發送通知
    若希望通知會停留直到手動關閉，請設定：
        settings > notifications > applications > Script Editor > Choose \"Alerts\"
    若使用外接螢幕，請設定：
        system settings > notifications > check 'Allow notifications when mirroring or sharing the display'
    eg: battery calibrate   # 開始校正
    eg: battery calibrate stop # 停止校正並恢復 maintain

  battery schedule
    設定定期校正時程：每月最多 4 個日期、或每 1~12 週指定星期、或每 1~3 個月指定單一日期；預設為每月 1 號 9:00
    範例:
    battery schedule    # 每月 1 號 9:00 校正
    battery schedule day 1 8 15 22    # 每月 1、8、15、22 號 9:00 校正
    battery schedule day 3 18 hour 13    # 每月 3、18 號 13:00 校正
    battery schedule day 6 16 26 hour 18 minute 30    # 每月 6、16、26 號 18:30 校正
    battery schedule weekday 0 week_period 2 hour 21 minute 30 # 每 2 週的星期日 21:30 校正
    battery schedule day 5 month_period 3 hour 21 minute 30 # 每 3 個月的 5 號 21:00 校正
    battery schedule disable    # 停用定期校正
    battery schedule enable    # 啟用定期校正
    限制:
        1. 每月最多 4 個日期
        2. day 範圍 [1-28]
        3. hour 範圍 [0-23]
        4. minute 範圍 [0-59]
        5. weekday 範圍 [0-6] 0:Sunday, 1:Monday, ...
        6. week_period 範圍 [1-12]
        7. month_period 範圍 [1-3]

  battery charge LEVEL[1-100, stop]
    將電池充到指定百分比，達到後停止充電
    eg: battery charge 90
    eg: battery charge stop # 停止執行中的 charge 程序並停止充電

  battery discharge LEVEL[1-100, stop]
    阻止電源輸入，直到電池下降到指定百分比
    eg: battery discharge 90
    eg: battery discharge stop # 停止執行中的 discharge 程序並停止放電

  battery status
    顯示電池 SMC 狀態、容量、溫度、健康度與循環次數

  battery dailylog
    顯示每日日誌與日誌存放位置

  battery changelog
    顯示 Github 最新版本更新內容

  battery calibratelog
    顯示校正歷史

  battery logs LINES[integer, optional]
    顯示 Battery CLI 與 GUI 日誌
    eg: battery logs 100

  battery language LANG[tw,cn,us,en,zh-TW,zh-CN,zh-Hant,zh-Hans,list]
    eg: battery language cn     # 以簡體中文顯示狀態與通知（若支援）
    eg: battery language zh-CN  # cn 的別名
    eg: battery language tw     # 以繁體中文顯示狀態與通知（若支援）
    eg: battery language zh-TW  # tw 的別名
    eg: battery language en     # us 的別名（英文）
    eg: battery language us     # 以英文顯示狀態與通知
    eg: battery language list   # 顯示支援語言與別名

  battery ssd
    顯示 SSD disk0 狀態

  battery ssdlog
    顯示 SSD disk0 每日日誌

  battery update
    將 battery 工具更新到最新版本

  battery version
    顯示目前版本

  battery reinstall
    重新安裝最新版 battery 工具（重新執行安裝腳本）

  battery uninstall
    恢復充電，並移除 smc 工具與 battery 腳本

"


function i18n_help_message_tw() {
	printf "%s\n" "$helpmessage_tw"
}

function i18n_schedule_display_text_tw() {
	local schedule_txt="$1"
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
	printf "%s\n" "$schedule_txt 開始"
}

function i18n_text_tw() {
	local key="$1"
	case "$key" in
		invalid_action) echo "錯誤：未知命令 '%s'" ;;
		did_you_mean) echo "你是不是想用以下指令？" ;;
		run_battery_help) echo "執行 'battery'（不帶參數）以查看可用指令清單。" ;;
		help_current_language) echo "目前語言：繁體中文 (tw)" ;;
		help_i18n_note) echo "提示：CLI 說明、狀態、通知與主要命令輸出皆已支援國際化；少量複雜對話框仍沿用既有中英分支邏輯。" ;;
		logs_cli_heading) echo "👾 Battery CLI 日誌：" ;;
		logs_gui_heading) echo "🖥️ Battery GUI 日誌：" ;;
		logs_config_heading) echo "📁 設定資料夾內容：" ;;
		logs_data_heading) echo "⚙️ Battery 狀態資料：" ;;
		dailylog_heading) echo "每日日誌 (%s)" ;;
		ssdlog_heading) echo "SSD 每日日誌 (%s)" ;;
		calibratelog_heading) echo "校正日誌 (%s)" ;;
		language_list_header) echo "支援語言（可用別名）：" ;;
		language_list_tw) echo "  - tw / zh-TW / zh_TW / zh-Hant -> 繁體中文" ;;
		language_list_cn) echo "  - cn / zh-CN / zh_CN / zh-Hans -> 簡體中文" ;;
		language_list_us) echo "  - us / en / en-US -> English" ;;
		language_current_tw) echo "目前設定語言：繁體中文 (tw)" ;;
		language_current_cn) echo "目前設定語言：簡體中文 (cn)" ;;
		language_current_us) echo "目前設定語言：英文 (us)" ;;
		language_changed_tw) echo "顯示語言改為繁體中文" ;;
		language_changed_cn) echo "顯示語言改為簡體中文" ;;
		language_changed_us) echo "顯示語言改為英文" ;;
		language_invalid) echo "指定語言無效。僅支援 [tw, cn, us]（也接受 en、zh-TW、zh-CN 等別名）" ;;
		charge_invalid_setting) echo "錯誤：%s 不是有效的 battery charge 設定。請使用 0 到 100 的數字" ;;
		charge_start) echo "開始充電至 %s%%（目前 %s%%）" ;;
		charge_progress) echo "電池目前 %s%%（目標 %s%%）" ;;
		charge_completed) echo "電池已充電至 %s%%" ;;
		charge_abnormal) echo "錯誤：電池充電異常" ;;
		discharge_invalid_setting) echo "錯誤：%s 不是有效的 battery discharge 設定。請使用 0 到 100 的數字" ;;
		discharge_lid_open_required) echo "錯誤：放電前必須先打開筆電上蓋" ;;
		discharge_start) echo "開始放電至 %s%%（目前 %s%%）" ;;
		discharge_progress) echo "電池目前 %s%%（目標 %s%%）" ;;
		discharge_completed) echo "電池已放電至 %s%%" ;;
		discharge_abnormal) echo "錯誤：電池放電異常" ;;
		maintain_recovering_percentage) echo "恢復電池最佳化設定 %s" ;;
		maintain_no_setting_to_recover) echo "沒有可恢復的設定，結束" ;;
		maintain_invalid_setting) echo "錯誤：%s 不是有效的 battery maintain 設定。請使用 0 到 100 的數字" ;;
		maintain_invalid_setting_with_keywords) echo "錯誤：%s 不是有效的 battery maintain 設定。請使用 0 到 100 的數字，或 'stop' / 'recover' 等動作關鍵字。" ;;
		maintain_invalid_sailing_target) echo "錯誤：滑行目標 %s 不可大於或等於維持上限 %s" ;;
		maintain_start) echo "開始電池最佳化：維持 %s%%，滑行至 %s%% %s" ;;
		maintain_lid_open_required) echo "錯誤：放電前必須先打開筆電上蓋" ;;
		maintain_trigger_force_discharge) echo "啟用充電限制前，先放電至 %s%%" ;;
		maintain_force_discharge_done) echo "預先放電完成，繼續進入維持迴圈" ;;
		maintain_force_discharge_skipped) echo "未要求預先放電，略過" ;;
		maintain_charging_and_maintaining) echo "開始充電並維持在 %s%%（目前 %s%%）" ;;
		maintain_recover_wait) echo "5 秒內恢復，請稍候 ." ;;
		maintain_suspend_wait) echo "5 秒內暫停，請稍候 ." ;;
		maintain_recovered) echo "電池最佳化已恢復" ;;
		maintain_recovered_ac_reconnected) echo "電源重新接上，電池最佳化已恢復" ;;
		maintain_recover_failed) echo "錯誤：電池最佳化恢復失敗" ;;
		maintain_already_running) echo "電池最佳化已在執行中" ;;
		maintain_not_running) echo "電池最佳化未在執行" ;;
		maintain_suspended) echo "電池最佳化已暫停" ;;
		maintain_suspend_failed) echo "錯誤：電池最佳化暫停失敗" ;;
		maintain_calibration_process_stopped) echo "🚨 已停止校正程序" ;;
		maintain_start_discharge_now) echo "開始放電至 %s%%" ;;
		status_battery_no_charging) echo "電池目前 %s%%, %sV, %s°C, 暫停充電" ;;
		status_battery_charging) echo "電池目前 %s%%, %sV, %s°C, 充電中" ;;
		status_battery_discharging) echo "電池目前 %s%%, %sV, %s°C, 放電中" ;;
		status_health_cycle) echo "電池健康度 %s%%, 循環次數 %s" ;;
		status_maintain_level_sailing) echo "%s%% 滑行至 %s%%" ;;
		status_maintain_active) echo "您的電池最佳化維持在 %s" ;;
		status_maintain_suspended_calibrating) echo "校正進行中，電池最佳化已暫停" ;;
		status_maintain_suspended) echo "電池最佳化已暫停" ;;
		status_maintain_not_running) echo "電池最佳化已經停止運作" ;;
		title_battery) echo "電池" ;;
		title_battery_optimizer) echo "BatteryOptimizer" ;;
		title_battery_optimizer_mac) echo "BatteryOptimizer for MAC" ;;
		title_calibration) echo "電池校正" ;;
		title_calibration_error) echo "電池校正錯誤" ;;
		dialog_button_ok) echo "OK" ;;
		dialog_button_continue) echo "繼續" ;;
		dialog_button_yes) echo "Yes" ;;
		dialog_button_no) echo "No" ;;
		dialog_button_update_now) echo "立即更新" ;;
		dialog_button_skip_version) echo "跳過此版本" ;;
		press_any_key_continue) echo "按任意鍵繼續" ;;
		reinstall_preview) echo "這將執行 curl -sS %s/setup.sh | bash" ;;
		uninstall_preview) echo "這會恢復充電，並移除 smc 工具與 battery 腳本" ;;
		visudo_set_owner) echo "設定 visudo 檔案權限給 %s" ;;
		visudo_already_current) echo "目前的 battery visudo 檔案與版本 %s 所需內容一致" ;;
		visudo_updated_success) echo "Visudo 檔案更新成功" ;;
		visudo_validate_error) echo "驗證 visudo 檔案時發生錯誤（理論上不應發生）：" ;;
		update_specified_file_missing) echo "錯誤：指定的更新檔案不存在" ;;
		update_dialog_latest) echo "%s 已是最新版，不需要更新" ;;
		update_dialog_changelog) echo "%s 更新內容如下\n\n%s" ;;
		update_dialog_confirm) echo "你現在要更新到%s 嗎?" ;;
		daily_log_table_header) echo "時間 容量 電壓 溫度 健康度 循環次數" ;;
		ssd_log_table_header) echo "日期 結果 讀取量 寫入量 已用度 電源循環 通電時數 非正常關機 溫度 錯誤" ;;
		calibrate_log_table_header) echo "時間 已完成 校正前健康度 校正後健康度 耗時/錯誤" ;;
		notify_battery_monthly_summary) echo "電池目前 %s%%, %sV, %s°C\n健康度 %s%%, 循環次數 %s" ;;
		notify_calibration_tomorrow) echo "提醒您，明天 (%s) 將進行電池校正" ;;
		notify_calibration_today) echo "提醒您，今天 (%s) 將進行電池校正" ;;
		notify_update_available) echo "有新版%s, 請在 Terminal 下輸入 \n\\\"battery update\\\" 更新" ;;
		aldente_conflict_detected) echo "偵測到 AlDente 正在執行，將其關閉以避免衝突" ;;
		maintain_stop_charge_above) echo "高於 %s%% 停止充電" ;;
		maintain_start_charge_below) echo "低於 %s%% 開始充電" ;;
		maintain_prompt_discharge_now) echo "你要現在就放電到 %s%% 嗎?" ;;
		schedule_disabled) echo "電池自動校正時程已暫停" ;;
		schedule_not_set) echo "您尚未設定電池自動校正時程" ;;
		schedule_disabled_enable_by) echo "您的電池自動校正時程已暫停，要恢復請執行" ;;
		schedule_next_date) echo "下次校正日期是 %s" ;;
		schedule_invalid_weekday) echo "錯誤：weekday 必須在 [0..6]" ;;
		schedule_invalid_month_period) echo "錯誤：month_period 必須在 [1..3]" ;;
		schedule_invalid_week_period) echo "錯誤：week_period 必須在 [1..12]" ;;
		schedule_invalid_hour) echo "錯誤：hour 必須在 [0..23]" ;;
		schedule_invalid_minute) echo "錯誤：minute 必須在 [0..59]" ;;
		schedule_invalid_day) echo "錯誤：day 必須在 [1..28]" ;;
		calibrate_skip_run) echo "略過本次校正" ;;
		calibrate_stop_running) echo "停止執行中的校正程序" ;;
		calibrate_require_maintain_before) echo "校正前必須先執行 battery maintain" ;;
		calibrate_error_require_maintain_before_log) echo "校正錯誤：校正前必須先執行 battery maintain" ;;
		calibrate_wait_open_lid_ac_notify) echo "準備進行電池校正, 您打開筆電上蓋並接上電源後將立刻開始" ;;
		calibrate_wait_open_lid_ac_log) echo "校正：請打開筆電上蓋並接上電源以開始校正" ;;
		calibrate_lid_not_open) echo "筆電上蓋沒打開" ;;
		calibrate_error_lid_not_open_log) echo "校正錯誤：筆電上蓋沒打開" ;;
		calibrate_no_ac_power) echo "電源沒接" ;;
		calibrate_error_no_ac_power_log) echo "校正錯誤：未接上電源" ;;
		calibrate_no_ac_power_logfile) echo "未接上電源" ;;
		calibrate_start_discharge_15_notify) echo "校正開始! \n開始放電至15%%" ;;
		calibrate_start_discharge_15_log) echo "校正：校正開始，開始放電至 15%%" ;;
		calibrate_fail_discharge_15) echo "未成功放電至15%%" ;;
		calibrate_error_discharge_15_log) echo "校正錯誤：未成功放電至15%%" ;;
		calibrate_done_discharge_15_charge_100_notify) echo "已放電至15%% \n開始充電到100%%" ;;
		calibrate_done_discharge_15_charge_100_log) echo "校正：已放電至 15%%，開始充電到 100%%" ;;
		calibrate_fail_charge_100) echo "未成功充電至100%%" ;;
		calibrate_error_charge_100_log) echo "校正錯誤：未成功充電至100%%" ;;
		calibrate_done_charge_100_wait_1h_notify) echo "已充電至100%% \n靜候一小時" ;;
		calibrate_done_charge_100_wait_1h_log) echo "校正：已充電至 100%%，等待一小時" ;;
		calibrate_done_wait_1h_log) echo "校正：電池已維持在 100%% 一小時" ;;
		calibrate_start_discharge_target_log) echo "校正：開始放電至維持電量" ;;
		calibrate_done_wait_1h_discharge_target_notify) echo "電池已維持在 100%% 一小時 \n開始放電至 %s%%" ;;
		calibrate_fail_discharge_target) echo "未成功放電至 %s%%" ;;
		calibrate_error_discharge_target_log) echo "校正錯誤：未成功放電至 %s%%" ;;
		calibrate_start_charge_100_notify) echo "校正開始！ \n準備充電至 100%%" ;;
		calibrate_start_charge_100_log) echo "校正：校正開始，開始充電至 100%%" ;;
		calibrate_done_wait_1h_discharge_15_notify) echo "電池已維持在 100%% 一小時 \n開始放電至 15%%" ;;
		calibrate_start_discharge_15_phase_log) echo "校正：開始放電至 15%%" ;;
		calibrate_done_discharge_15_log) echo "校正：已放電至 15%%" ;;
		calibrate_start_charge_target_log) echo "校正：開始充電至維持電量" ;;
		calibrate_done_discharge_15_charge_target_notify) echo "已放電至 15%% \n開始充電至 %s%%" ;;
		calibrate_fail_charge_target) echo "未成功充電至 %s%%" ;;
		calibrate_error_charge_target_log) echo "校正錯誤：未成功充電至 %s%%" ;;
		calibrate_health_snapshot_log) echo "電池健康度 %s%%, %sV, %s°C" ;;
		duration_days_part) echo "%s 天 " ;;
		duration_hours_part) echo "%s 小時" ;;
		duration_minutes_part) echo "%s 分" ;;
		duration_seconds_part) echo "%s 秒" ;;
		calibrate_completed_notify) echo "校正完成, 共花 %s%s %s\n電池目前 %s%%, %sV, %s°C\n健康度 %s%%, 循環次數 %s" ;;
		calibrate_completed_log) echo "校正完成, 共花 %s%s %s %s." ;;
		calibrate_completed_battery_log) echo "電池目前 %s%%, %sV, %s°C" ;;
		calibrate_completed_health_log) echo "健康度 %s%%, 循環次數 %s" ;;
		ssd_firmware_not_supported) echo "你的 SMART 韌體目前不支援。" ;;
		ssd_tool_not_installed) echo "你的 Mac 尚未安裝 SMART 監控工具，可執行 \\\"brew install smartmontools\\\" 安裝。" ;;
		*) return 1 ;;
	esac
}
