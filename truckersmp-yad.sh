#!/bin/bash

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
    --title="TruckersMP Launcher" \
    --text="Euro Truck Simulator 2 мультиплеер" \
    --image="$SCRIPT_DIR/truckersmp_cli/themes/default/logo.png" \
    --image-size=64 \
    --field="Steam Login:" "$SAVED_LOGIN" \
    --field="Действие:CB" "Запустить игру!Обновить игру" \
    --field="Skip Proton update:CHK" "$SAVED_SKIP_PROTON" \
    --field="Disable Steam Runtime:CHK" "$SAVED_DISABLE_RUNTIME" \
    --field="Without Discord IPC Bridge:CHK" "$SAVED_WITHOUT_DISCORD" \
    --button="Выполнить:0" \
    --button="Отмена:1" \
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
    "$YAD_GUI" --title="Ошибка" --text="Steam Login не указан!" --button="OK:0" --error
    exit 1
fi

case "$ACTION" in
    "Обновить игру")
        CMD="update"
        restore_libraryfolders
        ;;
    "Запустить игру")
        CMD="start"
        restore_libraryfolders
        ;;
    *) CMD="start"
        restore_libraryfolders
        ;;
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

# Если команда = update, запускаем в konsole для ручного ввода пароля
if [[ "$CMD" == "update" ]]; then
    konsole -e bash -c "$CMD_BASE; echo Нажми Enter для выхода...; read"
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
    tail -f "$LOGFILE" | "$YAD_GUI" --text-info --title="Логи TruckersMP" \
        --width="1024" --height="500" \
        --scroll \
        --tail \
        --button="Отмена:1" &
    YAD_PID=$!
    wait $CMD_PID
    kill $YAD_PID 2>/dev/null
    pkill -P $YAD_PID 2>/dev/null
    killall tail 2>/dev/null
    sleep 1
    rm -f "$LOGFILE"
fi
