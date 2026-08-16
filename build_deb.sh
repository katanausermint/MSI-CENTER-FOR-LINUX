#!/bin/bash
# ============================================
# MSI Center Ultimate - Установка
# ============================================

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   MSI Center Ultimate Installer${NC}"
echo -e "${BLUE}========================================${NC}"

# Проверка, запущен ли скрипт от root
if [ "$EUID" -eq 0 ]; then
    # === УСТАНОВКА ===
    
    echo -e "${YELLOW}→ Удаление старой версии...${NC}"
    if dpkg -l | grep -q msi-center-ultimate 2>/dev/null; then
        dpkg -r msi-center-ultimate 2>/dev/null || true
    fi
    
    rm -rf /usr/share/msi-center-ultimate 2>/dev/null || true
    rm -f /usr/bin/msi-center-ultimate 2>/dev/null || true
    rm -f /usr/share/applications/msi-center-ultimate.desktop 2>/dev/null || true
    rm -f /usr/share/applications/msi-keyboard-controller.desktop 2>/dev/null || true
    
    echo -e "${GREEN}✅ Старая версия удалена${NC}"
    
    echo -e "${BLUE}→ Установка MSI Center Ultimate...${NC}"
    
    mkdir -p /usr/share/msi-center-ultimate
    mkdir -p /usr/share/applications
    mkdir -p /usr/share/icons/hicolor/scalable/apps
    mkdir -p /usr/share/icons/hicolor/256x256/apps
    
    # Копируем main.py
    if [ -f "/tmp/msi-installer/main.py" ]; then
        cp /tmp/msi-installer/main.py /usr/share/msi-center-ultimate/
        chmod 644 /usr/share/msi-center-ultimate/main.py
        echo -e "${GREEN}✅ main.py скопирован${NC}"
    else
        echo -e "${RED}❌ Ошибка: main.py не найден!${NC}"
        exit 1
    fi
    
    # === СКРИПТ ЗАПУСКА ДЛЯ MSI CENTER ULTIMATE ===
    cat > /usr/bin/msi-center-ultimate << 'EOF'
#!/usr/bin/env python3
import os
import sys
import subprocess

def main():
    if os.geteuid() == 0:
        if not os.environ.get('DISPLAY'):
            os.environ['DISPLAY'] = ':0'
        
        if not os.environ.get('XAUTHORITY'):
            import pwd
            import glob
            try:
                username = pwd.getpwuid(os.getuid())[0]
                xauth_paths = [
                    f'/home/{username}/.Xauthority',
                    f'/run/user/{os.getuid()}/gdm/Xauthority',
                    f'/tmp/.Xauthority',
                ]
                for path in xauth_paths:
                    if os.path.exists(path):
                        os.environ['XAUTHORITY'] = path
                        break
            except:
                pass
        
        path = "/usr/share/msi-center-ultimate/main.py"
        if os.path.exists(path):
            os.execv("/usr/bin/python3", ["python3", path] + sys.argv[1:])
        else:
            print(f"Ошибка: {path} не найден")
            sys.exit(1)
        return
    
    try:
        display = os.environ.get('DISPLAY', ':0')
        xauth = os.environ.get('XAUTHORITY', os.path.expanduser('~/.Xauthority'))
        
        subprocess.run([
            'sudo', 
            '--preserve-env=DISPLAY,XAUTHORITY,HOME,USER',
            'python3', __file__
        ] + sys.argv[1:])
        sys.exit(0)
    except Exception as e:
        print(f"Ошибка: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF
    chmod +x /usr/bin/msi-center-ultimate
    echo -e "${GREEN}✅ Скрипт запуска создан${NC}"
    
    # === DESKTOP ФАЙЛ ДЛЯ MSI CENTER ULTIMATE ===
    cat > /usr/share/applications/msi-center-ultimate.desktop << 'EOF'
[Desktop Entry]
Name=MSI Center Ultimate
Comment=Управление RGB, кулерами и системой
Exec=/usr/bin/msi-center-ultimate
Icon=msi-center-ultimate
Terminal=false
Type=Application
Categories=System;Utility;
Keywords=msi;center;control;rgb;fans
StartupNotify=true
EOF
    echo -e "${GREEN}✅ Desktop файл MSI Center Ultimate создан${NC}"
    
    # === DESKTOP ФАЙЛ ДЛЯ MSI KEYBOARD CONTROLLER (С ИКОНКОЙ msi-rgb) ===
    cat > /usr/share/applications/msi-keyboard-controller.desktop << 'EOF'
[Desktop Entry]
Name=MSI Keyboard Controller
Comment=Управление RGB подсветкой клавиатуры MSI
Exec=/usr/bin/msi-center-ultimate
Icon=msi-rgb
Terminal=false
Type=Application
Categories=System;Utility;
Keywords=msi;keyboard;rgb;controller
StartupNotify=true
EOF
    echo -e "${GREEN}✅ Desktop файл MSI Keyboard Controller создан${NC}"
    
    # === ИКОНКА MSI CENTER ULTIMATE ===
    cat > /usr/share/icons/hicolor/scalable/apps/msi-center-ultimate.svg << 'SVG_EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <rect width="256" height="256" rx="40" fill="#1a1a1a"/>
  <rect x="40" y="50" width="176" height="130" rx="15" fill="#0a0a0a" stroke="#ff4444" stroke-width="2"/>
  <g fill="#ff2222">
    <rect x="55" y="65" width="14" height="45" rx="3"/>
    <rect x="69" y="65" width="14" height="30" rx="3"/>
    <rect x="83" y="65" width="14" height="45" rx="3"/>
    <rect x="69" y="95" width="14" height="15" rx="3"/>
    <rect x="115" y="65" width="14" height="45" rx="3"/>
    <rect x="129" y="65" width="14" height="20" rx="3"/>
    <rect x="129" y="90" width="14" height="20" rx="3"/>
    <rect x="115" y="105" width="28" height="5" rx="2"/>
    <rect x="165" y="65" width="14" height="45" rx="3"/>
    <rect x="165" y="60" width="14" height="5" rx="2"/>
  </g>
  <text x="128" y="212" text-anchor="middle" fill="#ff4444" font-size="18" font-weight="bold">MSI CENTER</text>
</svg>
SVG_EOF
    echo -e "${GREEN}✅ Иконка MSI Center создана${NC}"
    
    # === ИКОНКА MSI RGB (ТВОЯ ОРИГИНАЛЬНАЯ) ===
    echo -e "${BLUE}→ Установка иконки MSI RGB...${NC}"
    
    cat > /usr/share/icons/hicolor/256x256/apps/msi-rgb.svg << 'ICON_EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">
  <defs>
    <linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#ff0000"/>
      <stop offset="33%" style="stop-color:#00ff00"/>
      <stop offset="66%" style="stop-color:#0000ff"/>
      <stop offset="100%" style="stop-color:#ff00ff"/>
    </linearGradient>
  </defs>
  <rect width="256" height="256" rx="45" fill="#1a1a2e"/>
  <rect x="30" y="70" width="196" height="120" rx="15" fill="#2d2d44" stroke="#444" stroke-width="2"/>
  <rect x="40" y="80" width="176" height="30" rx="5" fill="url(#grad)" opacity="0.3"/>
  <g fill="url(#grad)" opacity="0.9">
    <rect x="45" y="85" width="20" height="20" rx="4"/>
    <rect x="70" y="85" width="20" height="20" rx="4"/>
    <rect x="95" y="85" width="20" height="20" rx="4"/>
    <rect x="120" y="85" width="20" height="20" rx="4"/>
    <rect x="145" y="85" width="20" height="20" rx="4"/>
    <rect x="170" y="85" width="20" height="20" rx="4"/>
    <rect x="195" y="85" width="20" height="20" rx="4"/>
    <rect x="55" y="110" width="20" height="20" rx="4"/>
    <rect x="80" y="110" width="20" height="20" rx="4"/>
    <rect x="105" y="110" width="20" height="20" rx="4"/>
    <rect x="130" y="110" width="20" height="20" rx="4"/>
    <rect x="155" y="110" width="20" height="20" rx="4"/>
    <rect x="180" y="110" width="20" height="20" rx="4"/>
    <rect x="65" y="135" width="20" height="20" rx="4"/>
    <rect x="90" y="135" width="20" height="20" rx="4"/>
    <rect x="115" y="135" width="20" height="20" rx="4"/>
    <rect x="140" y="135" width="20" height="20" rx="4"/>
    <rect x="165" y="135" width="20" height="20" rx="4"/>
  </g>
  <text x="128" y="225" text-anchor="middle" fill="#e0e0e0" 
        font-family="Arial, sans-serif" font-weight="bold" font-size="28">
    MSI RGB
  </text>
</svg>
ICON_EOF
    
    # Копируем иконку в scalable
    cp /usr/share/icons/hicolor/256x256/apps/msi-rgb.svg /usr/share/icons/hicolor/scalable/apps/msi-rgb.svg 2>/dev/null || true
    
    # Копируем иконку в local
    mkdir -p ~/.local/share/icons/hicolor/256x256/apps 2>/dev/null || true
    cp /usr/share/icons/hicolor/256x256/apps/msi-rgb.svg ~/.local/share/icons/hicolor/256x256/apps/ 2>/dev/null || true
    cp /usr/share/icons/hicolor/256x256/apps/msi-rgb.svg ~/.local/share/icons/hicolor/scalable/apps/ 2>/dev/null || true
    
    echo -e "${GREEN}✅ Иконка MSI RGB установлена${NC}"
    
    # Обновляем кеш иконок
    update-icon-caches /usr/share/icons/hicolor 2>/dev/null || true
    update-icon-caches ~/.local/share/icons/hicolor 2>/dev/null || true
    gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true
    
    echo -e "${GREEN}✅ MSI Center Ultimate установлен!${NC}"
    echo -e "${BLUE}🚀 Запуск: msi-center-ultimate${NC}"
    echo -e "${BLUE}   или через меню: MSI Center Ultimate${NC}"
    echo -e "${BLUE}   или через меню: MSI Keyboard Controller${NC}"
    exit 0
fi

# === ЗАПУСК С ГРАФИЧЕСКИМ ПАРОЛЕМ (НЕ ROOT) ===

# Создаём временную папку
TEMP_DIR="/tmp/msi-installer"
mkdir -p "$TEMP_DIR"

# Копируем main.py из текущей папки
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/main.py" ]; then
    cp "$SCRIPT_DIR/main.py" "$TEMP_DIR/"
    echo -e "${GREEN}✅ main.py найден${NC}"
else
    echo -e "${RED}❌ Ошибка: main.py не найден в $SCRIPT_DIR${NC}"
    echo -e "${RED}Убедитесь, что файл main.py находится в одной папке со скриптом${NC}"
    exit 1
fi

# Копируем сам скрипт во временную папку
cp "$0" "$TEMP_DIR/install.sh"
chmod +x "$TEMP_DIR/install.sh"

# Запуск с графическим запросом пароля
echo -e "${YELLOW}🔐 Запрос пароля...${NC}"
sudo -E DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" "$TEMP_DIR/install.sh"

# Очистка
rm -rf "$TEMP_DIR"

echo -e "${GREEN}✅ Установка завершена!${NC}"
echo -e "${BLUE}🚀 Запуск: msi-center-ultimate${NC}"    