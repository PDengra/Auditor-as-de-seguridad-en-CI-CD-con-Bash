# Security Audit Bash – CI/CD & Server

Script de **auditoría de seguridad en Bash**, diseñado para ejecutarse tanto en **servidores Linux** como en **pipelines CI/CD**, siguiendo un enfoque **DevSecOps**.

El objetivo del proyecto es integrar la seguridad como un proceso **continuo y automatizado**, en lugar de una tarea manual o puntual.

---

## 🚀 Características principales

* Ejecución en **modo CI** o **modo servidor**
* Salida estructurada en **JSON** (`audit.json`)
* Clasificación de eventos por severidad:

  * `INFO`
  * `WARN`
  * `CRITICAL`
* **Códigos de salida** para romper pipelines automáticamente ante riesgos críticos
* Configuración flexible mediante **variables de entorno**
* Notificaciones desacopladas por **Email** y **Telegram**

---

## 🔍 Controles de seguridad incluidos

### Comunes (CI + Server)

* Integridad de binarios críticos (`sha256sum`)
* Conexiones de red activas
* Variables de entorno sensibles (`LD_PRELOAD`, `LD_LIBRARY_PATH`)
* Parámetros básicos de **hardening del kernel**

### Solo modo servidor

* Usuarios sin contraseña (`/etc/shadow`)
* Usuarios con UID 0 no autorizados
* Servicios potencialmente inseguros (`telnet`, `ftp`, `rpcbind`, `nc`)
* Análisis de logs de autenticación
* Detección básica de rootkits (`rkhunter`)

---

## ⚙️ Requisitos

* Bash 4+
* Utilidades estándar de Linux (`coreutils`, `procps`, `util-linux`)
* Opcional:

  * `rkhunter`
  * `msmtp`
  * `curl`

---

## 🛠️ Uso

### Modo CI/CD

```bash
AUDIT_MODE=ci ./security_audit.sh
```

* No requiere privilegios elevados
* Compatible con GitHub Actions, GitLab CI, Jenkins, etc.
* El pipeline **fallará automáticamente** si se detectan hallazgos `CRITICAL`

---

### Modo servidor

```bash
sudo AUDIT_MODE=server FAIL_ON_CRITICAL=true ./security_audit.sh
```

* Ejecuta comprobaciones avanzadas de sistema
* Recomendado para auditorías periódicas o tareas de hardening

---

## 🔔 Notificaciones

### Email

```bash
export EMAIL="admin@tudominio.com"
```

Requiere `msmtp` correctamente configurado.

### Telegram

```bash
export TELEGRAM_BOT_TOKEN="TU_TOKEN"
export TELEGRAM_CHAT_ID="TU_CHAT_ID"
```

---

## 📦 Integración en CI/CD (ejemplo GitLab CI)

```yaml
security_audit:
  stage: security
  image: alpine:latest
  before_script:
    - apk add --no-cache bash coreutils procps util-linux
  script:
    - chmod +x security_audit.sh
    - ./security_audit.sh
  artifacts:
    when: always
    paths:
      - audit.json
```

---

## 📊 Salida

Ejemplo de entrada en `audit.json`:

```json
{
  "timestamp": "2026-01-09T12:00:00+01:00",
  "host": "server01",
  "level": "CRITICAL",
  "message": "Usuario sin contraseña: test"
}
```

---

## 🔐 Filosofía del proyecto

Este script está pensado como:

* Herramienta de **aprendizaje práctico** en seguridad y sistemas
* Base para **automatizar hardening**
* Ejemplo real de **DevSecOps aplicado**

No pretende sustituir soluciones enterprise, sino **complementarlas** y fomentar buenas prácticas.

---

## 🤝 Contribuciones

Las sugerencias, mejoras y pull requests son bienvenidos.

Ideas futuras:

* Exportación a SIEM / Elastic
* Comprobaciones CIS Benchmark
* Contenerización del script

---

## 📄 Licencia

MIT License
