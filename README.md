# 🐉 MSI Center Ultimate

**MSI Center Ultimate** — мощный центр управления для ноутбуков MSI на Linux.

---

## ✨ Возможности

- 🎨 **RGB управление** клавиатурой (MSI Keyboard)
- 🌀 **Управление кулерами** (Fn+Стрелки)
- ⚙️ **Диспетчер задач** с кольцевыми диаграммами CPU/RAM
- 🧹 **Очиститель системы** от мусора
- 🎯 **Тёмная тема** в стиле Msi

---

## 📦 Установка

### Способ 1 — DEB-пакет (рекомендуемый)

```bash
sudo dpkg -i msi-center-ultimate_2.0.0_all.deb
sudo apt install -f
```

Способ 2 — Запуск без установки

```bash
sudo python3 main.py
```

Способ 3 — Установка через скрипт

```bash
chmod +x build_deb.sh
./build_deb.sh
```
Способ 4 — Бинарный файл (БЕТА ТЕСТ)

```bash
sudo ./msi_center
```

---

🚀 Запуск

```bash
msi-center-ultimate
```

Или через меню: MSI Center Ultimate

---

🔧 Требования

· Python 3.8+
· pyusb
· python3-tk
· libusb-1.0-0

Установка зависимостей

```bash
sudo apt install python3 python3-tk python3-pip libusb-1.0-0
pip3 install pyusb
```

---

❓ Частые вопросы

❓ Почему программа запрашивает пароль?

Для управления кулерами и RGB-устройствами требуются права root.

❓ Кулеры не управляются?

На некоторых ноутбуках MSI управление кулерами работает только через Fn+Стрелки. Проверьте:

```bash
ls /sys/class/hwmon/hwmon*/pwm*
```

Если PWM-файлов нет — управление через BIOS/EC.

❓ Не работает RGB?

Проверьте, что устройство подключено:

```bash
lsusb | grep 1462
```

Установите pyusb:

```bash
pip3 install pyusb
```

---

🗑️ Удаление

```bash
sudo dpkg -r msi-center-ultimate
```

Или вручную:

```bash
sudo rm -rf /usr/share/msi-center-ultimate
sudo rm -f /usr/bin/msi-center-ultimate
sudo rm -f /usr/share/applications/msi-center-ultimate.desktop
```

---

📁 Структура проекта

```
msi-center-ultimate/
├── main.py                    # Исходный код
├── msi-center-ultimate_2.0.0_all.deb  # DEB-пакет
├── build_deb.sh               # Скрипт сборки
├── LICENSE                    # Лицензия
└── README.md                  # Этот файл
```

---

🤝 Участие в разработке

1. Форкните репозиторий
2. Создайте ветку (git checkout -b feature/amazing)
3. Закоммитьте изменения (git commit -m 'Add amazing feature')
4. Запушьте (git push origin feature/amazing)
5. Откройте Pull Request

---

📜 Лицензия

MIT License — подробности в файле LICENSE

---

🙏 Благодарности

· MSI за отличные ноутбуки
· Open Source сообщество
· Все тестировщики

---

🐉 MSI Center Ultimate — Управляй своим MSI на Linux!

```
This project is completely made by AI and the instability or bugs for it are ok install at your own risk
