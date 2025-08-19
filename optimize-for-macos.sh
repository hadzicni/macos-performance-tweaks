#!/bin/zsh

set -euo pipefail

RED=$(tput setaf 1 2>/dev/null || echo "")
GREEN=$(tput setaf 2 2>/dev/null || echo "")
YELLOW=$(tput setaf 3 2>/dev/null || echo "")
BLUE=$(tput setaf 4 2>/dev/null || echo "")
BOLD=$(tput bold 2>/dev/null || echo "")
RESET=$(tput sgr0 2>/dev/null || echo "")

LOGFILE=~/macos_tweaks.log
if [[ -f $LOGFILE ]]; then
  mv "$LOGFILE" "$LOGFILE.$(date +%Y%m%d_%H%M%S)"
fi
exec > >(tee -a "$LOGFILE") 2>&1

trap "echo ''; echo \"${RED}Script aborted. Logfile: $LOGFILE${RESET}\"; exit 130" INT TERM

if [[ ! -t 1 ]]; then
  echo "${YELLOW}⚠️  This script is not running in an interactive terminal. User interaction might not work as expected.${RESET}"
fi

USER_NAME=$(whoami)
MACOS_VERSION=$(sw_vers -productVersion)
MACOS_BUILD=$(sw_vers -buildVersion)
MACOS_MAJOR=$(echo "$MACOS_VERSION" | cut -d. -f1)
MACOS_MINOR=$(echo "$MACOS_VERSION" | cut -d. -f2)
MAC_MODEL=$(sysctl -n hw.model 2>/dev/null || echo "unknown")
RAM_GB=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))" GB"
CPU=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "unknown")
UPTIME=$(uptime -p 2>/dev/null || echo "$(uptime)")

IS_VM="No"
if sysctl -n kern.hv_vmm_present 2>/dev/null | grep -q 1; then
  IS_VM="Yes"
fi

OCLP="No"
if [ -d "/Library/Application Support/OpenCore-Patcher" ] || \
   [ -d "/Applications/OpenCore-Patcher.app" ] || \
   [ -f "$HOME/Library/LaunchAgents/com.dortania.opencore-legacy-patcher.auto-patch.plist" ]; then
  OCLP="Yes"
fi

SCRIPT_VERSION="2025-08-19"
MIN_MACOS=12

if ! sudo -v; then
  echo "${RED}Root privileges are required. Exiting.${RESET}"
  exit 1
fi
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

if (( MACOS_MAJOR < MIN_MACOS )); then
  echo "${YELLOW}⚠️  Warning: This script was not tested on macOS versions older than $MIN_MACOS.${RESET}"
fi

profiles status -type configuration | grep "There are no configuration profiles" > /dev/null
if [[ $? -ne 0 ]]; then
  echo "${YELLOW}⚠️  Warning: Configuration profiles detected. Some settings may be managed by your organization.${RESET}"
fi

clear
echo "${BOLD}==============================================${RESET}"
echo "${BOLD}🔧 macOS Performance Tweaks – Logging enabled${RESET}"
echo "${BOLD}----------------------------------------------${RESET}"
echo "User        : $USER_NAME"
echo "macOS       : $MACOS_VERSION ($MACOS_BUILD)"
echo "Model       : $MAC_MODEL"
echo "CPU         : $CPU"
echo "RAM         : $RAM_GB"
echo "Uptime      : $UPTIME"
echo "VM          : $IS_VM"
echo "OCLP        : $OCLP"
echo "Script Ver. : $SCRIPT_VERSION"
echo "Started at  : $(date)"
echo "${BOLD}==============================================${RESET}"
echo ""

MODE="interactive"
[[ $# -ge 1 && "$1" == "--auto" ]] && MODE="auto"

declare -A SUMMARY

function ask() {
  local prompt="$1"
  local __resultvar=$2
  if [[ "$MODE" == "auto" ]]; then
    echo "$prompt [auto: yes]"
    eval "$__resultvar='y'"
  else
    read "?$prompt (y/N): " choice
    case "$choice" in
      [yY]*) eval "$__resultvar='y'" ;;
      *)     eval "$__resultvar='n'" ;;
    esac
  fi
}

ask "1️⃣ Reduce UI transparency and motion?" do_ui
ask "2️⃣ Disable Spotlight indexing?" do_spotlight
ask "3️⃣ Disable iCloud as default save location?" do_icloud
if (( MACOS_MAJOR > 12 )) || (( MACOS_MAJOR == 12 && MACOS_MINOR >= 0 )); then
  if (( MACOS_MAJOR >= 13 )); then
    ask "4️⃣ Disable Stage Manager?" do_stage
  else
    do_stage="n"
  fi
else
  do_stage="n"
fi
ask "5️⃣ Hide Control Center widgets?" do_widgets
ask "6️⃣ Disable automatic software updates?" do_updates
ask "7️⃣ Disable Siri and analytics?" do_siri
ask "8️⃣ Clean system & user caches?" do_caches
ask "9️⃣ Disable Gatekeeper & app quarantine?" do_gatekeeper
ask "🔁 Delete Xcode DerivedData?" do_derived

echo ""
echo "${BLUE}⚙️  Applying selected tweaks...${RESET}"

if [[ "$do_ui" =~ ^[Yy]$ ]]; then
  defaults write com.apple.universalaccess reduceTransparency -bool true
  defaults write com.apple.universalaccess reduceMotion -bool true
  echo "${GREEN}→ Reduced UI transparency and motion${RESET}"
  SUMMARY["UI transparency/motion"]="Applied"
else
  SUMMARY["UI transparency/motion"]="Skipped"
fi

if [[ "$do_spotlight" =~ ^[Yy]$ ]]; then
  sudo mdutil -a -i off || true
  echo "${GREEN}→ Disabled Spotlight indexing${RESET}"
  SUMMARY["Spotlight indexing"]="Applied"
else
  SUMMARY["Spotlight indexing"]="Skipped"
fi

if [[ "$do_icloud" =~ ^[Yy]$ ]]; then
  defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
  echo "${GREEN}→ Disabled iCloud default save location${RESET}"
  SUMMARY["iCloud default save"]="Applied"
else
  SUMMARY["iCloud default save"]="Skipped"
fi

if [[ "$do_stage" =~ ^[Yy]$ ]]; then
  if (( MACOS_MAJOR >= 13 )); then
    defaults write com.apple.WindowManager GloballyEnabled -bool false
    echo "${GREEN}→ Disabled Stage Manager${RESET}"
    SUMMARY["Stage Manager"]="Applied"
  else
    echo "${YELLOW}→ Stage Manager not supported on this macOS version${RESET}"
    SUMMARY["Stage Manager"]="Unavailable"
  fi
else
  SUMMARY["Stage Manager"]="Skipped"
fi

if [[ "$do_widgets" =~ ^[Yy]$ ]]; then
  defaults write com.apple.controlcenter "NSStatusItem Visible NowPlaying" -bool false
  defaults write com.apple.controlcenter "NSStatusItem Visible ScreenRecording" -bool false
  defaults write com.apple.controlcenter "NSStatusItem Visible StageManager" -bool false
  echo "${GREEN}→ Hid Control Center widgets${RESET}"
  SUMMARY["Control Center widgets"]="Applied"
else
  SUMMARY["Control Center widgets"]="Skipped"
fi

if [[ "$do_updates" =~ ^[Yy]$ ]]; then
  sudo softwareupdate --schedule off
  sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool false
  sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool false
  echo "${GREEN}→ Disabled automatic software updates${RESET}"
  SUMMARY["Software updates"]="Applied"
else
  SUMMARY["Software updates"]="Skipped"
fi

if [[ "$do_siri" =~ ^[Yy]$ ]]; then
  defaults write com.apple.assistant.support "Assistant Enabled" -bool false
  defaults write com.apple.assistant.support "Siri Data Sharing Opt-In Status" -int 2
  defaults write com.apple.SubmitDiagInfo AutoSubmit -bool false
  sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.SubmitDiagInfo.plist 2>/dev/null || true
  echo "${GREEN}→ Disabled Siri and analytics${RESET}"
  SUMMARY["Siri and analytics"]="Applied"
else
  SUMMARY["Siri and analytics"]="Skipped"
fi

if [[ "$do_caches" =~ ^[Yy]$ ]]; then
  read "?Clearing caches may cause unexpected behavior. Continue? (y/N): " cache_confirm
  if [[ "$cache_confirm" =~ ^[Yy]$ ]]; then
    set +e
    rm -rf ~/Library/Caches/* 2>/dev/null
    sudo rm -rf /Library/Caches/* 2>/dev/null
    set -e
    echo "${GREEN}→ Cleaned user and system caches${RESET}"
    SUMMARY["System/user caches"]="Applied"
  else
    echo "${YELLOW}→ Cache cleaning skipped${RESET}"
    SUMMARY["System/user caches"]="Skipped"
  fi
else
  SUMMARY["System/user caches"]="Skipped"
fi

if [[ "$do_gatekeeper" =~ ^[Yy]$ ]]; then
  sudo spctl --master-disable || true
  defaults write com.apple.LaunchServices LSQuarantine -bool false
  echo "${GREEN}→ Disabled Gatekeeper and app quarantine${RESET}"
  SUMMARY["Gatekeeper/quarantine"]="Applied"
else
  SUMMARY["Gatekeeper/quarantine"]="Skipped"
fi

if [[ "$do_derived" =~ ^[Yy]$ ]]; then
  read "?Delete Xcode DerivedData? (y/N): " derived_confirm
  if [[ "$derived_confirm" =~ ^[Yy]$ ]]; then
    rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null || true
    echo "${GREEN}→ Deleted Xcode DerivedData${RESET}"
    SUMMARY["Xcode DerivedData"]="Applied"
  else
    echo "${YELLOW}→ DerivedData deletion skipped${RESET}"
    SUMMARY["Xcode DerivedData"]="Skipped"
  fi
else
  SUMMARY["Xcode DerivedData"]="Skipped"
fi

echo ""
echo "${BOLD}📋 Summary:${RESET}"
for key value in ${(kv)SUMMARY}; do
  printf " - %-28s : %s\n" "$key" "$value"
done

echo ""
read "?Do you want to restart your Mac now to apply all changes? (y/N): " restart_now
if [[ "$restart_now" =~ ^[Yy]$ ]]; then
  echo "${YELLOW}Restarting now...${RESET}"
  sudo shutdown -r now
else
  echo "${GREEN}✅ Done. Please restart your Mac manually for all changes to take full effect.${RESET}"
fi
