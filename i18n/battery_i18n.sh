# Battery CLI i18n loader (compatibility entrypoint)
# battery.sh sources this file; this loader then sources common helpers and all lang_*.sh catalogs.

if [[ -n "${BATTERY_I18N_LOADER_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
BATTERY_I18N_LOADER_LOADED=1

battery_i18n_loader_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
if [[ -z "$battery_i18n_loader_dir" ]]; then
  echo "Error: unable to resolve battery i18n loader directory" >&2
  return 1 2>/dev/null || exit 1
fi

if [[ ! -f "$battery_i18n_loader_dir/common.sh" ]]; then
  echo "Error: missing i18n component: common.sh" >&2
  return 1 2>/dev/null || exit 1
fi
# shellcheck disable=SC1090
source "$battery_i18n_loader_dir/common.sh"

battery_i18n_lang_found=false
for battery_i18n_part in "$battery_i18n_loader_dir"/lang_*.sh; do
  [[ -f "$battery_i18n_part" ]] || continue
  # shellcheck disable=SC1090
  source "$battery_i18n_part"
  battery_i18n_lang_found=true
done

if ! $battery_i18n_lang_found; then
  echo "Error: no i18n language catalogs found in $battery_i18n_loader_dir" >&2
  return 1 2>/dev/null || exit 1
fi

unset battery_i18n_part
unset battery_i18n_lang_found
unset battery_i18n_loader_dir
