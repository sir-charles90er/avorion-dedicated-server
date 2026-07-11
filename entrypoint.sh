#!/usr/bin/env bash
set -Eeuo pipefail

log() {
    printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

die() {
    log "FEHLER: $*"
    exit 1
}

is_true() {
    case "${1,,}" in
        1|true|yes|on) return 0 ;;
        *) return 1 ;;
    esac
}

require_uint() {
    local name="$1"
    local value="$2"
    [[ "$value" =~ ^[0-9]+$ ]] || die "${name} muss eine nichtnegative Ganzzahl sein."
}

require_port() {
    local name="$1"
    local value="$2"
    require_uint "$name" "$value"
    (( value >= 1 && value <= 65535 )) || die "${name} muss zwischen 1 und 65535 liegen."
}

# Die Bind-Mounts werden als root vorbereitet; der eigentliche Server läuft danach unprivilegiert.
if [[ "$(id -u)" -eq 0 ]]; then
    PUID="${PUID:-1000}"
    PGID="${PGID:-1000}"
    require_uint PUID "$PUID"
    require_uint PGID "$PGID"
    (( PUID > 0 && PGID > 0 )) || die "PUID und PGID dürfen nicht 0 sein."

    current_gid="$(id -g avorion)"
    current_uid="$(id -u avorion)"

    if [[ "$current_gid" != "$PGID" ]]; then
        groupmod --non-unique --gid "$PGID" avorion
    fi
    if [[ "$current_uid" != "$PUID" ]]; then
        usermod --non-unique --uid "$PUID" --gid "$PGID" avorion
    else
        usermod --gid "$PGID" avorion
    fi

    mkdir -p "$STEAMCMD_DIR" "$AVORION_DIR" "$AVORION_DATA_DIR" "$HOME"
    chown -R "$PUID:$PGID" "$STEAMCMD_DIR" "$AVORION_DIR" "$AVORION_DATA_DIR" "$HOME"

    exec setpriv --reuid=avorion --regid=avorion --init-groups "$0" "$@"
fi

STEAM_APP_ID=565060
GALAXY_NAME="${GALAXY_NAME:-avorion_galaxy}"
SERVER_NAME="${SERVER_NAME:-Avorion Server}"
SERVER_PORT="${SERVER_PORT:-27000}"
MAX_PLAYERS="${MAX_PLAYERS:-10}"
SAVE_INTERVAL="${SAVE_INTERVAL:-300}"
DIFFICULTY="${DIFFICULTY:-0}"
SERVER_THREADS="${SERVER_THREADS:-}"
PUBLIC="${PUBLIC:-1}"
LISTED="${LISTED:-1}"
USE_STEAM_NETWORKING="${USE_STEAM_NETWORKING:-1}"
UPDATE_ON_START="${UPDATE_ON_START:-true}"
VALIDATE_ON_START="${VALIDATE_ON_START:-false}"
STEAM_BRANCH="${STEAM_BRANCH:-}"
SHUTDOWN_SAVE_WAIT="${SHUTDOWN_SAVE_WAIT:-10}"
SHUTDOWN_TIMEOUT="${SHUTDOWN_TIMEOUT:-120}"
EXTRA_SERVER_ARGS="${EXTRA_SERVER_ARGS:-}"
ADMIN_STEAM_ID="${ADMIN_STEAM_ID:-}"

[[ -n "$ADMIN_STEAM_ID" ]] || die "ADMIN_STEAM_ID ist nicht gesetzt."
[[ "$ADMIN_STEAM_ID" =~ ^[0-9]{16,20}$ ]] || die "ADMIN_STEAM_ID muss eine numerische SteamID64 sein."
[[ "$GALAXY_NAME" =~ ^[A-Za-z0-9._-]+$ ]] || die "GALAXY_NAME darf nur ASCII-Buchstaben, Ziffern, Punkt, Unterstrich und Bindestrich enthalten."

require_port SERVER_PORT "$SERVER_PORT"
require_uint MAX_PLAYERS "$MAX_PLAYERS"
require_uint SAVE_INTERVAL "$SAVE_INTERVAL"
require_uint SHUTDOWN_SAVE_WAIT "$SHUTDOWN_SAVE_WAIT"
require_uint SHUTDOWN_TIMEOUT "$SHUTDOWN_TIMEOUT"
[[ "$DIFFICULTY" =~ ^-?[0-3]$ ]] || die "DIFFICULTY muss zwischen -3 und 3 liegen."
if [[ -n "$SERVER_THREADS" ]]; then
    require_uint SERVER_THREADS "$SERVER_THREADS"
    (( SERVER_THREADS >= 1 )) || die "SERVER_THREADS muss mindestens 1 sein."
fi

update_server() {
    local -a steam_args=(
        +force_install_dir "$AVORION_DIR"
        +login anonymous
        +app_update "$STEAM_APP_ID"
    )

    if [[ -n "$STEAM_BRANCH" ]]; then
        steam_args+=(-beta "$STEAM_BRANCH")
    fi
    if is_true "$VALIDATE_ON_START"; then
        steam_args+=(validate)
    fi
    steam_args+=(+quit)

    log "Installiere bzw. aktualisiere den Avorion Dedicated Server über SteamCMD."
    "$STEAMCMD_DIR/steamcmd.sh" "${steam_args[@]}"
    chmod 0755 "$AVORION_DIR/server.sh"
}

if is_true "$UPDATE_ON_START" || [[ ! -x "$AVORION_DIR/server.sh" ]]; then
    update_server
fi

[[ -x "$AVORION_DIR/server.sh" ]] || die "server.sh wurde nicht gefunden oder ist nicht ausführbar."
mkdir -p "$AVORION_DATA_DIR"

SERVER_ARGS=(
    --galaxy-name "$GALAXY_NAME"
    --admin "$ADMIN_STEAM_ID"
    --datapath "$AVORION_DATA_DIR"
    --server-name "$SERVER_NAME"
    --port "$SERVER_PORT"
    --max-players "$MAX_PLAYERS"
    --save-interval "$SAVE_INTERVAL"
    --difficulty "$DIFFICULTY"
    --public "$PUBLIC"
    --listed "$LISTED"
    --use-steam-networking "$USE_STEAM_NETWORKING"
)

if [[ -n "$SERVER_THREADS" ]]; then
    SERVER_ARGS+=(--threads "$SERVER_THREADS")
fi

if [[ -n "$EXTRA_SERVER_ARGS" ]]; then
    read -r -a extra_args <<< "$EXTRA_SERVER_ARGS"
    SERVER_ARGS+=("${extra_args[@]}")
fi

FIFO=/tmp/avorion-console.fifo
PID_FILE=/tmp/avorion-server.pid
SERVER_PID=''
SHUTDOWN_STARTED=0
CONSOLE_FD_OPEN=0

cleanup() {
    rm -f "$PID_FILE" "$FIFO"
    if (( CONSOLE_FD_OPEN )); then
        exec 3>&- || true
    fi
}

server_is_running() {
    [[ -n "$SERVER_PID" ]] || return 1
    kill -0 "$SERVER_PID" 2>/dev/null || return 1

    local state
    state="$(ps -o stat= -p "$SERVER_PID" 2>/dev/null | tr -d '[:space:]')"
    [[ -n "$state" && "$state" != Z* ]]
}

wait_for_server_exit() {
    local timeout="$1"
    local deadline=$((SECONDS + timeout))

    while server_is_running; do
        (( SECONDS < deadline )) || return 1
        sleep 1
    done
    return 0
}

send_console_command() {
    local command="$1"
    if (( CONSOLE_FD_OPEN )) && server_is_running; then
        printf '%s\n' "$command" >&3 || true
    fi
}

graceful_shutdown() {
    if (( SHUTDOWN_STARTED )); then
        return 0
    fi
    SHUTDOWN_STARTED=1

    if ! server_is_running; then
        return 0
    fi

    log "Stoppsignal empfangen: speichere die Galaxie mit /save."
    send_console_command /save
    sleep "$SHUTDOWN_SAVE_WAIT"

    log "Beende den Avorion-Server geordnet mit /stop."
    send_console_command /stop

    if wait_for_server_exit "$SHUTDOWN_TIMEOUT"; then
        log "Der Avorion-Server wurde sauber beendet."
        return 0
    fi

    log "WARNUNG: /stop wurde nicht rechtzeitig abgeschlossen; sende SIGTERM an die Server-Prozessgruppe."
    kill -TERM -- "-$SERVER_PID" 2>/dev/null || true
    if wait_for_server_exit 15; then
        return 0
    fi

    log "WARNUNG: Der Server reagiert weiterhin nicht; erzwinge das Beenden."
    kill -KILL -- "-$SERVER_PID" 2>/dev/null || true
}

trap graceful_shutdown TERM INT
trap cleanup EXIT

rm -f "$FIFO" "$PID_FILE"
mkfifo "$FIFO"
exec 3<>"$FIFO"
CONSOLE_FD_OPEN=1

log "Starte Galaxie '${GALAXY_NAME}' auf Port ${SERVER_PORT}."
cd "$AVORION_DIR"
setsid "$AVORION_DIR/server.sh" "${SERVER_ARGS[@]}" <"$FIFO" 3>&- &
SERVER_PID=$!
printf '%s\n' "$SERVER_PID" > "$PID_FILE"

set +e
wait "$SERVER_PID"
status=$?

# Falls wait durch ein Signal unterbrochen wurde, wird das inzwischen beendete Kind hier sauber eingesammelt.
if [[ -e "/proc/$SERVER_PID" ]]; then
    wait "$SERVER_PID"
    status=$?
fi
set -e

if (( SHUTDOWN_STARTED )); then
    exit 0
fi
exit "$status"
