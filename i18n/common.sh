# Battery CLI i18n common helpers and dispatchers
# Sourced by i18n/battery_i18n.sh. Language catalogs live in lang_*.sh.

if [[ -n "${BATTERY_I18N_COMMON_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
BATTERY_I18N_COMMON_LOADED=1

function normalize_language_code() {
	local raw="$1"
	raw=$(echo "$raw" | tr '[:upper:]' '[:lower:]' | tr '-' '_')
	case "$raw" in
		cn|zh_cn|zh_cn*|zh_sg|zh_sg*|zh_my|zh_my*|zh_hans|zh_hans*)
			echo "cn"
			;;
		tw|zh_tw|zh_tw*|zh_hk|zh_hk*|zh_mo|zh_mo*|zh_hant|zh_hant*)
			echo "tw"
			;;
		us|en|en_us|en_us*|en_gb|en_gb*)
			echo "us"
			;;
		"")
			echo
			;;
		*)
			echo
			;;
	esac
}

function resolve_cli_language() {
	local configured_language
	local system_locale
	configured_language=$(normalize_language_code "$(read_config language)")
	if [[ -n "$configured_language" ]]; then
		CLI_LANG="$configured_language"
	else
		system_locale=$(defaults read -g AppleLocale 2>/dev/null)
		CLI_LANG=$(normalize_language_code "$system_locale")
		[[ -z "$CLI_LANG" ]] && CLI_LANG="us"
	fi

	if [[ "$CLI_LANG" == "tw" ]]; then
		is_TW=true
	else
		is_TW=false
	fi
}


function i18n_text_for_lang() {
	local lang="$1"
	local key="$2"
	local fn="i18n_text_${lang}"
	if declare -f "$fn" >/dev/null; then
		"$fn" "$key"
	else
		return 1
	fi
}

function i18n_help_message_for_lang() {
	local lang="$1"
	local fn="i18n_help_message_${lang}"
	if declare -f "$fn" >/dev/null; then
		"$fn"
	else
		return 1
	fi
}

function i18n_schedule_display_text_for_lang() {
	local lang="$1"
	local schedule_txt="$2"
	local fn="i18n_schedule_display_text_${lang}"
	if declare -f "$fn" >/dev/null; then
		"$fn" "$schedule_txt"
	else
		return 1
	fi
}

function i18n_schedule_display_text() {
	local schedule_txt="$1"
	local lang="${CLI_LANG:-us}"
	if i18n_schedule_display_text_for_lang "$lang" "$schedule_txt"; then
		return 0
	fi
	if [[ "$lang" != "us" ]] && i18n_schedule_display_text_for_lang "us" "$schedule_txt"; then
		return 0
	fi
	schedule_txt=${schedule_txt%" starting"*}
	printf "%s\n" "$schedule_txt"
}

function i18n_text() {
	local key="$1"
	local lang="${CLI_LANG:-us}"
	if i18n_text_for_lang "$lang" "$key"; then
		return 0
	fi
	if [[ "$lang" != "us" ]] && i18n_text_for_lang "us" "$key"; then
		return 0
	fi
	echo "$key"
}

function i18n_format() {
	local key="$1"
	shift
	local format
	format=$(i18n_text "$key")
	printf "$format" "$@"
}

function i18n_log() {
	local key="$1"
	shift
	log "$(i18n_format "$key" "$@")"
}

function i18n_logLF() {
	local key="$1"
	shift
	logLF "$(i18n_format "$key" "$@")"
}

function i18n_logn() {
	local key="$1"
	shift
	logn "$(i18n_format "$key" "$@")"
}

function i18n_echo() {
	local key="$1"
	shift
	echo "$(i18n_format "$key" "$@")"
}

function lang_pick() {
	local tw_text="$1"
	local en_text="$2"
	if [[ "${CLI_LANG:-us}" == "tw" ]]; then
		printf "%s" "$tw_text"
	else
		printf "%s" "$en_text"
	fi
}

function log_lang() {
	local tw_text="$1"
	local en_text="$2"
	log "$(lang_pick "$tw_text" "$en_text")"
}

function logLF_lang() {
	local tw_text="$1"
	local en_text="$2"
	logLF "$(lang_pick "$tw_text" "$en_text")"
}

function logn_lang() {
	local tw_text="$1"
	local en_text="$2"
	logn "$(lang_pick "$tw_text" "$en_text")"
}

function echo_lang() {
	local tw_text="$1"
	local en_text="$2"
	echo "$(lang_pick "$tw_text" "$en_text")"
}

function notify_msg() {
	local title="$1"
	local message="$2"
	osascript -e 'display notification "'"$message"'" with title "'"$title"'" sound name "Blow"'
}

function notify_lang() {
	local tw_message="$1"
	local en_message="$2"
	local tw_title="${3:-電池}"
	local en_title="${4:-Battery}"
	notify_msg "$(lang_pick "$tw_title" "$en_title")" "$(lang_pick "$tw_message" "$en_message")"
}

function i18n_notify() {
	local title_key="$1"
	local message_key="$2"
	shift 2
	notify_msg "$(i18n_text "$title_key")" "$(i18n_format "$message_key" "$@")"
}

function show_help() {
	echo -e "$(i18n_format help_current_language)"
	echo -e "$(i18n_format help_i18n_note)"
	echo
	if ! i18n_help_message_for_lang "${CLI_LANG:-us}"; then
		i18n_help_message_for_lang "us" || true
	fi
}
