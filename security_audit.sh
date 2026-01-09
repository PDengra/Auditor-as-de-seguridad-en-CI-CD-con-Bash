#!/bin/bash
# ============================================
# Auditoría de Seguridad CI/CD & Server
# Autor: Pablo Dengra
# Fecha: $(date +"%Y-%m-%d")
# ============================================

#!/usr/bin/env bash
set -euo pipefail

# =====================================================
# CONFIGURACIÓN (override por variables de entorno)
# =====================================================
AUDIT_MODE="${AUDIT_MODE:-ci}"                # ci | server
AUDIT_OUTPUT="${AUDIT_OUTPUT:-audit.json}"
FAIL_ON_CRITICAL="${FAIL_ON_CRITICAL:-true}"

EMAIL="${EMAIL:-}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

HOSTNAME="$(hostname)"
TIMESTAMP="$(date -Iseconds)"

CRITICAL_FOUND=false

# =====================================================
# FUNCIONES BASE
# =====================================================
log() {
    local level="$1"
    local msg="$2"

    printf '{"timestamp":"%s","host":"%s","level":"%s","message":"%s"}\n' \
        "$TIMESTAMP" "$HOSTNAME" "$level" "${msg//\"/\\\"}" >> "$AUDIT_OUTPUT"

    [[ "$level" == "CRITICAL" ]] && CRITICAL_FOUND=true
}

require_cmd() {
    command -v "$1" &>/dev/null
}

header() {
    : > "$AUDIT_OUTPUT"
    log "INFO" "Inicio de auditoría de seguridad (modo=$AUDIT_MODE)"
}

finalize() {
    if [[ "$CRITICAL_FOUND" == "true" && "$FAIL_ON_CRITICAL" == "true" ]]; then
        log "CRITICAL" "Auditoría finalizada con hallazgos críticos"
        notify "❌ Auditoría FALLIDA en $HOSTNAME"
        exit 1
    else
        log "INFO" "Auditoría finalizada sin riesgos críticos"
        notify "✅ Auditoría completada en $HOSTNAME"
        exit 0
    fi
}

# =====================================================
# NOTIFICACIONES
# =====================================================
notify() {
    local message="$1"

    # Email
    if [[ -n "$EMAIL" ]] && require_cmd msmtp; then
        {
            echo "Subject: Auditoría de Seguridad - $HOSTNAME"
            echo "To: $EMAIL"
            echo "Content-Type: application/json"
            echo
            cat "$AUDIT_OUTPUT"
        } | msmtp "$EMAIL"
    fi

    # Telegram
    if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="$message" >/dev/null
    fi
}

# =====================================================
# CHECKS CI / SERVER
# =====================================================
check_integrity_bins() {
    for bin in /bin/ls /bin/bash /usr/bin/sudo /usr/bin/passwd; do
        if [[ -f "$bin" ]]; then
            hash=$(sha256sum "$bin" | awk '{print $1}')
            log "INFO" "Checksum $bin = $hash"
        fi
    done
}

check_network() {
    if require_cmd ss; then
        ss -atunp | while read -r line; do
            log "INFO" "NET $line"
        done
    fi
}

check_env_vars() {
    env | grep -E "LD_PRELOAD|LD_LIBRARY_PATH" | while read -r var; do
        log "WARN" "Variable de entorno sensible detectada: $var"
    done
}

check_kernel_hardening() {
    sysctl -a 2>/dev/null | grep -E "randomize_va_space|kptr_restrict|dmesg_restrict" \
    | while read -r line; do
        log "INFO" "Kernel: $line"
    done
}

# =====================================================
# CHECKS SOLO SERVER
# =====================================================
check_shadow_users() {
    awk -F: '($2==""){print $1}' /etc/shadow 2>/dev/null | while read -r user; do
        log "CRITICAL" "Usuario sin contraseña: $user"
    done
}

check_uid_zero() {
    awk -F: '($3==0){print $1}' /etc/passwd | while read -r user; do
        [[ "$user" != "root" ]] && log "CRITICAL" "Usuario UID 0 no esperado: $user"
    done
}

check_rootkits() {
    if require_cmd rkhunter; then
        rkhunter --check --sk --rwo | while read -r line; do
            log "WARN" "rkhunter: $line"
        done
    else
        log "INFO" "rkhunter no instalado"
    fi
}

check_services() {
    if require_cmd systemctl; then
        systemctl list-units --type=service --state=running \
        | grep -Ei "telnet|ftp|rpcbind|nc" \
        | while read -r svc; do
            log "WARN" "Servicio potencialmente inseguro: $svc"
        done
    fi
}

check_logs() {
    grep -Ei "failed|invalid|authentication failure" \
        /var/log/auth.log /var/log/secure 2>/dev/null | tail -n 20 \
        | while read -r line; do
            log "WARN" "LOG: $line"
        done
}

# =====================================================
# MAIN
# =====================================================
header

log "INFO" "Checks comunes (CI + Server)"
check_integrity_bins
check_network
check_env_vars
check_kernel_hardening

if [[ "$AUDIT_MODE" == "server" ]]; then
    log "INFO" "Checks avanzados de servidor"
    check_shadow_users
    check_uid_zero
    check_rootkits
    check_services
    check_logs
else
    log "INFO" "Modo CI: checks de sistema omitidos"
fi

finalize
