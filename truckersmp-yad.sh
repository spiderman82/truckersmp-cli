#!/bin/bash

# Определяем язык интерфейса
if [[ "$LANG" == ru* ]]; then
    UI_LANG="ru"
else
    UI_LANG="en"
fi

# Тексты на русском и английском
if [[ "$UI_LANG" == "ru" ]]; then
    TITLE="TruckersMP Launcher"
    TEXT="Управление мультиплеером Euro Truck Simulator 2"
    FIELD_LOGIN="Steam Login:"
    FIELD_ACTION="Действие:CB"
    ACTION_START="Запустить игру"
    ACTION_UPDATE="Обновить игру"
    FIELD_SKIP="Skip Proton update:CHK"
    FIELD_RUNTIME="Disable Steam Runtime:CHK"
    FIELD_DISCORD="Without Discord IPC Bridge:CHK"
    BTN_RUN="Выполнить"
    BTN_CANCEL="Закрыть"
    ERROR_NO_LOGIN="Steam Login не указан!"
    ERROR_PASSWORD="Пароль не введён. Обновление отменено."
    ERROR_XTERM="Для обновления нужен xterm.\nУстановите: sudo pacman -S xterm"
    TITLE_PASSWORD="Steam пароль"
    TEXT_PASSWORD="Введите пароль для аккаунта"
    TITLE_LOGS="Логи TruckersMP"
else
    TITLE="TruckersMP Launcher"
    TEXT="Euro Truck Simulator 2 Multiplayer Manager"
    FIELD_LOGIN="Steam Login:"
    FIELD_ACTION="Action:CB"
    ACTION_START="Start game"
    ACTION_UPDATE="Update game"
    FIELD_SKIP="Skip Proton update:CHK"
    FIELD_RUNTIME="Disable Steam Runtime:CHK"
    FIELD_DISCORD="Without Discord IPC Bridge:CHK"
    BTN_RUN="Run"
    BTN_CANCEL="Exit"
    ERROR_NO_LOGIN="Steam Login is required!"
    ERROR_PASSWORD="Password not entered. Update cancelled."
    ERROR_XTERM="xterm is required for update.\nInstall: sudo pacman -S xterm"
    TITLE_PASSWORD="Steam password"
    TEXT_PASSWORD="Enter password for account"
    TITLE_LOGS="TruckersMP Logs"
fi

# Функция для бэкапа libraryfolders.vdf
backup_libraryfolders() {
    LOCAL_STEAM_DIR="$HOME/.local/share/Steam"
    STEAM_LIBRARY_FILE="$LOCAL_STEAM_DIR/config/libraryfolders.vdf"
    BACKUP_FILE="$LOCAL_STEAM_DIR/config/libraryfolders.vdf.backup"
    
    if [[ -f "$STEAM_LIBRARY_FILE" ]]; then
        cp "$STEAM_LIBRARY_FILE" "$BACKUP_FILE"
        echo "Бэкап libraryfolders.vdf создан"
    else
        echo "Предупреждение: libraryfolders.vdf не найден"
    fi
}

# Функция для восстановления бэкапа libraryfolders.vdf
restore_libraryfolders() {
    LOCAL_STEAM_DIR="$HOME/.local/share/Steam"
    STEAM_LIBRARY_FILE="$LOCAL_STEAM_DIR/config/libraryfolders.vdf"
    BACKUP_FILE="$LOCAL_STEAM_DIR/config/libraryfolders.vdf.backup"
    
    if [[ -f "$BACKUP_FILE" ]]; then
        cp "$BACKUP_FILE" "$STEAM_LIBRARY_FILE"
        echo "Бэкап libraryfolders.vdf восстановлен"
    else
        echo "Предупреждение: бэкап libraryfolders.vdf не найден"
    fi
}

# Определяем директорию, где находится САМ СКРИПТ
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Путь к YAD GUI (в папке bin)
YAD_GUI="$SCRIPT_DIR/truckersmp_cli/bin/yad_gui_pp"

# Путь к truckersmp-cli
TRUCKERSMP_CLI="$SCRIPT_DIR/truckersmp-cli"

# Конфиг для сохранения настроек
CONFIG_DIR="$HOME/.config/truckersmp-launcher"
CONFIG_FILE="$CONFIG_DIR/settings.conf"
mkdir -p "$CONFIG_DIR"

# Загружаем сохранённые настройки
SAVED_LOGIN=""
SAVED_SKIP_PROTON="TRUE"
SAVED_DISABLE_RUNTIME="TRUE"
SAVED_WITHOUT_DISCORD="TRUE"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Проверяем, существует ли YAD_GUI
if [[ ! -f "$YAD_GUI" ]]; then
    zenity --title="Ошибка" --text="Не найден YAD GUI: $YAD_GUI" --error 2>/dev/null || \
    echo "Ошибка: не найден $YAD_GUI"
    exit 1
fi

# Проверяем, существует ли TRUCKERSMP_CLI
if [[ ! -f "$TRUCKERSMP_CLI" ]]; then
    zenity --title="Ошибка" --text="Не найден truckersmp-cli: $TRUCKERSMP_CLI" --error 2>/dev/null || \
    echo "Ошибка: не найден $TRUCKERSMP_CLI"
    exit 1
fi

# Создаём бэкап libraryfolders.vdf перед любыми действиями
backup_libraryfolders

# Главное окно с формой
result=$("$YAD_GUI" --form \
    --title="$TITLE" \
    --text="$TEXT" \
    --image="$SCRIPT_DIR/truckersmp_cli/themes/default/logo.png" \
    --image-size=48 \
    --field="$FIELD_LOGIN" "$SAVED_LOGIN" \
    --field="$FIELD_ACTION" "$ACTION_START!$ACTION_UPDATE" \
    --field="$FIELD_SKIP" "$SAVED_SKIP_PROTON" \
    --field="$FIELD_RUNTIME" "$SAVED_DISABLE_RUNTIME" \
    --field="$FIELD_DISCORD" "$SAVED_WITHOUT_DISCORD" \
    --button="$BTN_RUN:0" \
    --button="$BTN_CANCEL:1" \
    --width="500")

if [[ $? -ne 0 ]]; then
    exit 0
fi

IFS='|' read -r LOGIN ACTION SKIP_PROTON DISABLE_RUNTIME WITHOUT_DISCORD <<< "$result"

# Заменяем дефисы на подчёркивания в логине (для совместимости с SteamCMD)
LOGIN="${LOGIN//-/_}"

# Сохраняем настройки
echo "SAVED_LOGIN='$LOGIN'" > "$CONFIG_FILE"
echo "SAVED_SKIP_PROTON='$SKIP_PROTON'" >> "$CONFIG_FILE"
echo "SAVED_DISABLE_RUNTIME='$DISABLE_RUNTIME'" >> "$CONFIG_FILE"
echo "SAVED_WITHOUT_DISCORD='$WITHOUT_DISCORD'" >> "$CONFIG_FILE"

if [[ -z "$LOGIN" ]]; then
    "$YAD_GUI" --title="$TITLE" --text="$ERROR_NO_LOGIN" --button="$BTN_OK:0" --error
    exit 1
fi

case "$ACTION" in
    "$ACTION_UPDATE") CMD="update" ;;
    "$ACTION_START") CMD="start" ;;
    *) CMD="start" ;;
esac

EXTRA_OPTS=""
if [[ "$SKIP_PROTON" == "TRUE" ]]; then
    EXTRA_OPTS="$EXTRA_OPTS --skip-update-proton"
fi
if [[ "$DISABLE_RUNTIME" == "TRUE" ]]; then
    EXTRA_OPTS="$EXTRA_OPTS --disable-steamruntime"
fi
if [[ "$WITHOUT_DISCORD" == "TRUE" ]]; then
    EXTRA_OPTS="$EXTRA_OPTS --without-wine-discord-ipc-bridge"
fi

# Формируем команду
CMD_BASE="$TRUCKERSMP_CLI $CMD ets2mp -n \"$LOGIN\" -vv $EXTRA_OPTS"

# Проверяем наличие xterm (нужен для update)
if ! command -v xterm &>/dev/null; then
    "$YAD_GUI" --title="$TITLE" --text="$ERROR_XTERM" --button="$BTN_OK:0" --error
    exit 1
fi

# Если команда = update, запускаем в konsole для ручного ввода пароля
if [[ "$CMD" == "update" ]]; then
    # Запрашиваем пароль через YAD (GUI)
    STEAM_PASSWORD=$("$YAD_GUI" --entry \
        --title="$TITLE_PASSWORD" \
        --text="$TEXT_PASSWORD $LOGIN:" \
        --hide-text)

    if [[ -z "$STEAM_PASSWORD" ]]; then
        "$YAD_GUI" --title="$TITLE" --text="$ERROR_PASSWORD" --button="$BTN_OK:0" --error
        exit 1
    fi

    # Запускаем обновление в konsole с передачей пароля через переменную окружения
    konsole -e bash -c "export STEAM_PASSWORD=\"$STEAM_PASSWORD\"; $CMD_BASE; echo Нажми Enter для выхода...; read"
else
    # Для start — используем YAD с логами
    LOGFILE="/tmp/truckersmp-launcher.log"
    > "$LOGFILE"
    (
        export HOME="$HOME"
        export STEAMROOT="$HOME/.steam"
        export STEAMDATA="$HOME/.steam"
        $CMD_BASE
    ) > "$LOGFILE" 2>&1 &
    CMD_PID=$!
    tail -f "$LOGFILE" | "$YAD_GUI" --text-info --title="$TITLE_LOGS" \
        --width="800" --height="500" \
        --scroll \
        --tail \
        --button="$BTN_CANCEL:1" &
    YAD_PID=$!
    wait $CMD_PID
    kill $YAD_PID 2>/dev/null
    pkill -P $YAD_PID 2>/dev/null
    killall tail 2>/dev/null
    sleep 1
    rm -f "$LOGFILE"
fi
