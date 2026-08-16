#!/usr/bin/env python3
"""
MSI Center Ultimate - Всё в одном
RGB + Кулеры + Диспетчер + Очиститель
"""

import os
import sys
import subprocess
import tkinter as tk
from tkinter import ttk, colorchooser, messagebox, scrolledtext
import time
import glob
import re
from datetime import datetime
import math

# ============== ПРОВЕРКА ПРАВ ==============
def check_and_request_permissions():
    if os.geteuid() != 0:
        print("Требуются права root. Перезапуск с sudo...")
        try:
            env = os.environ.copy()
            subprocess.run(['sudo', '-E', 'python3', __file__], env=env)
            sys.exit(0)
        except Exception as e:
            print(f"Ошибка: {e}")
            sys.exit(1)

# ============== ТЕМА ==============
THEME = {
    'bg_dark': '#1a1a1a',
    'bg_medium': '#2d2d2d',
    'bg_light': '#3d3d3d',
    'accent': '#ff4444',
    'accent_blue': '#4444ff',
    'accent_green': '#44ff44',
    'accent_gold': '#ffd700',
    'accent_orange': '#ff8800',
    'accent_purple': '#aa44ff',
    'accent_cyan': '#00ddff',
    'text': '#ffffff',
    'text_secondary': '#b0b0b0',
    'button': '#4a4a4a',
    'button_hover': '#5a5a5a',
}

# ============== RGB КОНФИГ ==============
try:
    import usb.core
    import usb.util
    USB_AVAILABLE = True
except:
    USB_AVAILABLE = False
    print("⚠️ pyusb не установлен. RGB функция будет отключена.")

VENDOR_ID = 0x1462
PRODUCT_ID = 0x1601
INTERFACE = 0
REPORT_ID_SEND = 2
REPORT_ID_RECV = 1
TIMEOUT = 1000

ZONES = {
    'Вся клавиатура': 0x0F,
    'Зона 1': 0x01,
    'Зона 2': 0x02,
    'Зона 3': 0x04,
    'Зона 4': 0x08,
}

ANIMATION_TYPES = {
    'Статичный': 0x01,
    'Дыхание': 0x02,
    'Волна': 0x03,
    'Реактивный': 0x04,
    'Радуга': 0x05,
    'Градиент': 0x06,
}

SPEEDS = {
    'Очень медленно': 0x0100,
    'Медленно': 0x0200,
    'Средне': 0x0300,
    'Быстро': 0x0400,
    'Очень быстро': 0x0500,
}

BRIGHTNESS_LEVELS = {
    'Выкл': 0x00,
    'Низкая': 0x33,
    'Средняя': 0x66,
    'Высокая': 0x99,
    'Максимальная': 0xFF,
}

FAN_MODES = {
    '🌿 Авто': 'auto',
    '🔥 Максимум': 'max',
    '⚖️ Сбалансированный': 'balanced',
    '🔇 Тихий': 'quiet'
}

# ============== USB КОНТРОЛЛЕР ==============
class USBController:
    def __init__(self):
        self.device = None
        self.connected = False
        self.usb_available = USB_AVAILABLE
    
    def connect(self) -> bool:
        if not self.usb_available:
            return False
        try:
            self.device = usb.core.find(idVendor=VENDOR_ID, idProduct=PRODUCT_ID)
            if self.device is None:
                return False
            
            if self.device.is_kernel_driver_active(INTERFACE):
                try:
                    self.device.detach_kernel_driver(INTERFACE)
                except:
                    pass
            
            try:
                self.device.set_configuration()
            except:
                pass
            
            self.connected = True
            return True
        except:
            return False
    
    def disconnect(self):
        if self.device:
            try:
                usb.util.release_interface(self.device, INTERFACE)
                try:
                    self.device.attach_kernel_driver(INTERFACE)
                except:
                    pass
                self.connected = False
                self.device = None
            except:
                pass
    
    def _send_feature_report(self, data: bytes) -> bool:
        if not self.connected or not self.usb_available:
            return False
        try:
            report = bytearray([REPORT_ID_SEND] + list(data))
            report += b'\x00' * (64 - len(report))
            
            self.device.ctrl_transfer(
                bmRequestType=0x21,
                bRequest=0x09,
                wValue=0x0300 | REPORT_ID_SEND,
                wIndex=0,
                data_or_wLength=report,
                timeout=TIMEOUT
            )
            time.sleep(0.1)
            return True
        except:
            return False
    
    def set_static_color(self, zone_mask: int, red: int, green: int, blue: int, brightness: int = 0xFF) -> bool:
        if red == 0 and green == 0 and blue == 0:
            brightness = 0x00
        
        data = bytes([
            0x02, 0x01, 0x00, 0x00, 0x00, 0x00, 0x0F, 0x01,
            0x00, 0x00, red, green, blue, brightness
        ])
        return self._send_feature_report(bytes([0x01, zone_mask])) and self._send_feature_report(data)
    
    def set_animation(self, zone_mask: int, anim_type: int, speed: int, red: int, green: int, blue: int, brightness: int = 0xFF) -> bool:
        data = bytes([
            0x02, anim_type, speed & 0xFF, (speed >> 8) & 0xFF,
            0x00, 0x00, 0x0F, 0x01, 0x00, 0x00,
            red, green, blue, brightness
        ])
        return self._send_feature_report(bytes([0x01, zone_mask])) and self._send_feature_report(data)
    
    def save_to_flash(self) -> bool:
        return self._send_feature_report(bytes([0xA0]))
    
    def load_from_flash(self) -> bool:
        return self._send_feature_report(bytes([0xB0]))

# ============== КОНТРОЛЛЕР КУЛЕРОВ ==============
class FanController:
    def __init__(self):
        self.fan_names = []
        self.fan_files = []
        self.fan_speeds = {}
        self.current_mode = 'auto'
        self.detect_fans()
    
    def detect_fans(self):
        self.fan_names = []
        self.fan_files = []
        self.fan_speeds = {}
        
        try:
            for hwmon in glob.glob('/sys/class/hwmon/hwmon*/'):
                name_file = os.path.join(hwmon, 'name')
                if os.path.exists(name_file):
                    with open(name_file, 'r') as f:
                        device_name = f.read().strip()
                else:
                    continue
                
                fan_inputs = sorted(glob.glob(hwmon + 'fan*_input'))
                for fan_file in fan_inputs:
                    fan_num = re.search(r'fan(\d+)_input', fan_file)
                    if fan_num:
                        num = fan_num.group(1)
                        self.fan_files.append(fan_file)
                        self.fan_names.append(f"{device_name} Fan {num}")
        except:
            pass
        
        if not self.fan_names:
            self.fan_names = ["CPU Fan", "System Fan"]
            self.fan_files = ["", ""]
        
        self.update_speeds()
    
    def update_speeds(self):
        for fan_file in self.fan_files:
            if fan_file and os.path.exists(fan_file):
                try:
                    with open(fan_file, 'r') as f:
                        rpm = f.read().strip()
                    fan_name = self.fan_names[self.fan_files.index(fan_file)]
                    self.fan_speeds[fan_name] = rpm
                except:
                    pass
    
    def get_speed(self, fan_name: str) -> str:
        return self.fan_speeds.get(fan_name, "0")
    
    def set_mode(self, mode: str) -> bool:
        self.current_mode = mode
        try:
            perf_file = '/sys/devices/platform/msi-perf-driver/perf_mode'
            if os.path.exists(perf_file):
                mode_map = {'quiet': 0, 'balanced': 1, 'auto': 1, 'max': 3}
                with open(perf_file, 'w') as f:
                    f.write(str(mode_map.get(mode, 1)))
                return True
            
            ec_perf = '/sys/devices/platform/msi-ec/perf_mode'
            if os.path.exists(ec_perf):
                mode_map = {'quiet': 0, 'balanced': 1, 'auto': 1, 'max': 3}
                with open(ec_perf, 'w') as f:
                    f.write(str(mode_map.get(mode, 1)))
                return True
            
            return True
        except:
            return False
    
    def get_current_mode(self) -> str:
        try:
            perf_file = '/sys/devices/platform/msi-perf-driver/perf_mode'
            if os.path.exists(perf_file):
                with open(perf_file, 'r') as f:
                    mode = f.read().strip()
                mode_map = {'0': 'quiet', '1': 'balanced', '2': 'performance', '3': 'max'}
                return mode_map.get(mode, 'auto')
            
            ec_perf = '/sys/devices/platform/msi-ec/perf_mode'
            if os.path.exists(ec_perf):
                with open(ec_perf, 'r') as f:
                    mode = f.read().strip()
                mode_map = {'0': 'quiet', '1': 'balanced', '2': 'performance', '3': 'max'}
                return mode_map.get(mode, 'auto')
        except:
            pass
        return 'auto'

# ============== ДИСПЕТЧЕР ЗАДАЧ ==============
class ProcessManager:
    def __init__(self):
        self.processes = []
        self.total_memory = 0
        self.cpu_count = 0
        self.memory_percent = 0
        self.cpu_percent = 0
        self.prev_cpu_times = {}
        self.update()
    
    def _get_cpu_times(self):
        """Получение времени CPU из /proc/stat"""
        try:
            with open('/proc/stat', 'r') as f:
                line = f.readline()
                parts = line.split()
                if parts[0] == 'cpu':
                    # user, nice, system, idle, iowait, irq, softirq, steal, guest, guest_nice
                    values = [int(x) for x in parts[1:]]
                    total = sum(values)
                    idle = values[3] + values[4]  # idle + iowait
                    return {'total': total, 'idle': idle}
        except:
            return None
        return None
    
    def update(self):
        self.processes = []
        self.total_memory = 0
        self.cpu_count = os.cpu_count() or 1
        
        # ====== РАСЧЁТ CPU ======
        current_times = self._get_cpu_times()
        cpu_percent = 0
        
        if current_times and hasattr(self, 'prev_cpu_times') and self.prev_cpu_times:
            prev = self.prev_cpu_times
            curr = current_times
            
            total_diff = curr['total'] - prev['total']
            idle_diff = curr['idle'] - prev['idle']
            
            if total_diff > 0:
                cpu_percent = ((total_diff - idle_diff) / total_diff) * 100
                cpu_percent = max(0, min(100, cpu_percent))
        
        self.cpu_percent = cpu_percent
        self.prev_cpu_times = current_times
        
        # ====== СБОР ПРОЦЕССОВ ======
        try:
            with open('/proc/meminfo', 'r') as f:
                meminfo = f.read()
                mem_match = re.search(r'MemTotal:\s+(\d+)', meminfo)
                if mem_match:
                    self.total_memory = int(mem_match.group(1)) // 1024
            
            total_ram_used = 0
            
            for pid_dir in glob.glob('/proc/[0-9]*'):
                pid = os.path.basename(pid_dir)
                try:
                    with open(f'/proc/{pid}/comm', 'r') as f:
                        name = f.read().strip()[:30]
                    
                    with open(f'/proc/{pid}/stat', 'r') as f:
                        stat = f.read().split()
                        if len(stat) > 22:
                            utime = int(stat[13])
                            stime = int(stat[14])
                            total_time = utime + stime
                            rss = int(stat[23]) * 4 // 1024
                            status = stat[2]
                            
                            status_map = {'R': '▶️ Выполняется', 'S': '💤 Спит', 
                                         'D': '⏳ Ожидает', 'Z': '🧟 Зомби', 
                                         'T': '⏸️ Остановлен'}
                            status_str = status_map.get(status, status)
                            
                            total_ram_used += rss
                            
                            self.processes.append({
                                'pid': pid,
                                'name': name,
                                'cpu': total_time,
                                'memory': rss,
                                'status': status_str,
                                'raw_status': status
                            })
                except:
                    pass
            
            self.processes.sort(key=lambda x: x['cpu'], reverse=True)
            
            total_cpu_all = sum(p['cpu'] for p in self.processes)
            for p in self.processes:
                p['cpu_percent'] = min(99.9, (p['cpu'] / max(1, total_cpu_all)) * 100)
            
            self.memory_percent = min(100, (total_ram_used / max(1, self.total_memory)) * 100)
                
        except Exception as e:
            print(f"Ошибка обновления процессов: {e}")
    
    def get_top_cpu(self, n=5):
        sorted_proc = sorted(self.processes, key=lambda x: x['cpu'], reverse=True)
        return sorted_proc[:n]
    
    def get_top_memory(self, n=5):
        sorted_proc = sorted(self.processes, key=lambda x: x['memory'], reverse=True)
        return sorted_proc[:n]
    
    def kill_process(self, pid):
        try:
            os.kill(int(pid), 15)
            return True
        except:
            return False
    
    def suspend_process(self, pid):
        try:
            os.kill(int(pid), 19)
            return True
        except:
            return False
    
    def resume_process(self, pid):
        try:
            os.kill(int(pid), 18)
            return True
        except:
            return False

# ============== ОСНОВНОЙ GUI ==============
class MSICenterUltimate:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.usb = USBController()
        self.fan = FanController()
        self.process_manager = ProcessManager()
        
        # RGB переменные
        self.current_color = "#ff0000"
        self.current_mode = tk.StringVar(value="Статичный")
        self.current_zone = tk.StringVar(value="Вся клавиатура")
        self.current_brightness = tk.StringVar(value="Максимальная")
        self.current_speed = tk.StringVar(value="Средне")
        
        # Fan переменные
        self.fan_mode = tk.StringVar(value="🌿 Авто")
        
        self.setup_window()
        self.create_notebook()
        self.create_rgb_tab()
        self.create_fan_tab()
        self.create_task_tab()
        self.create_cleaner_tab()
        self.create_about_tab()
        
        self.update_status_dot()
        self.update_fan_speeds()
        self.update_task_manager()
    
    def setup_window(self):
        self.root.title("MSI Center Ultimate")
        self.root.geometry("1300x800")
        self.root.minsize(1200, 700)
        self.root.configure(bg=THEME['bg_dark'])
        
        style = ttk.Style()
        style.theme_use('clam')
        style.configure('TNotebook', background=THEME['bg_dark'])
        style.configure('TNotebook.Tab', background=THEME['bg_medium'], foreground=THEME['text'], padding=[10, 5])
        style.map('TNotebook.Tab', background=[('selected', THEME['accent'])])
        style.configure('TFrame', background=THEME['bg_dark'])
        style.configure('TLabel', background=THEME['bg_dark'], foreground=THEME['text'])
        
        style.configure('Treeview', background=THEME['bg_light'], foreground=THEME['text'],
                       fieldbackground=THEME['bg_light'], font=('Segoe UI', 10))
        style.map('Treeview', background=[('selected', THEME['accent'])])
        style.configure('Treeview.Heading', background=THEME['bg_medium'], foreground=THEME['text'],
                       font=('Segoe UI', 10, 'bold'))
    
    def create_notebook(self):
        self.notebook = ttk.Notebook(self.root)
        self.notebook.pack(fill="both", expand=True, padx=10, pady=10)
    
    # ========== ФУНКЦИЯ ДЛЯ ЦВЕТА ТЕКСТА ==========
    def _is_dark_color(self, hex_color: str) -> bool:
        """Проверяет, является ли цвет тёмным или средним (для белого текста)"""
        r, g, b = self._hex_to_rgb(hex_color)
        brightness = (r * 299 + g * 587 + b * 114) / 1000
        # Тёмные и средние цвета → белый текст
        # Светлые цвета (яркость > 180) → чёрный текст
        return brightness <= 180
    
    def _get_text_color(self, hex_color: str) -> str:
        """Возвращает цвет текста для контраста с фоном"""
        return "white" if self._is_dark_color(hex_color) else "black"
    
    def _hex_to_rgb(self, hex_color: str):
        hex_color = hex_color.lstrip('#')
        return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))
    
    # ========== RGB ТАБ ==========
    def create_rgb_tab(self):
        tab = ttk.Frame(self.notebook)
        self.notebook.add(tab, text="🎨 RGB")
        
        status_frame = tk.Frame(tab, bg=THEME['bg_dark'])
        status_frame.pack(fill="x", padx=20, pady=10)
        
        self.status_dot = tk.Canvas(status_frame, width=15, height=15, bg=THEME['bg_dark'], highlightthickness=0)
        self.status_dot.pack(side="left", padx=(0, 10))
        
        tk.Label(status_frame, text="RGB контроллер", font=("Segoe UI", 12), bg=THEME['bg_dark'], fg=THEME['text_secondary']).pack(side="left")
        
        self.rgb_btn = tk.Button(status_frame, text="Подключить", command=self.toggle_rgb,
                 font=("Segoe UI", 10), bg=THEME['button'], fg=THEME['text'], 
                 relief="flat", padx=15, pady=5, cursor="hand2")
        self.rgb_btn.pack(side="right")
        
        content = tk.Frame(tab, bg=THEME['bg_dark'])
        content.pack(fill="both", expand=True, padx=20, pady=10)
        
        left = tk.Frame(content, bg=THEME['bg_medium'])
        left.pack(side="left", fill="both", expand=True, padx=(0, 10))
        
        mode_frame = tk.LabelFrame(left, text="Режим", font=("Segoe UI", 12, "bold"), bg=THEME['bg_medium'], fg=THEME['accent'], padx=15, pady=10)
        mode_frame.pack(fill="x", padx=10, pady=10)
        for mode in ANIMATION_TYPES.keys():
            tk.Radiobutton(mode_frame, text=mode, variable=self.current_mode, value=mode,
                          font=("Segoe UI", 11), bg=THEME['bg_medium'], fg=THEME['text'],
                          selectcolor=THEME['bg_light'], anchor="w", cursor="hand2").pack(fill="x", pady=2)
        
        zone_frame = tk.LabelFrame(left, text="Зона", font=("Segoe UI", 12, "bold"), bg=THEME['bg_medium'], fg=THEME['accent'], padx=15, pady=10)
        zone_frame.pack(fill="x", padx=10, pady=10)
        ttk.Combobox(zone_frame, textvariable=self.current_zone, values=list(ZONES.keys()), state="readonly").pack(fill="x", pady=5)
        
        center = tk.Frame(content, bg=THEME['bg_medium'])
        center.pack(side="left", fill="both", expand=True, padx=10)
        
        color_frame = tk.LabelFrame(center, text="Цвет", font=("Segoe UI", 12, "bold"), bg=THEME['bg_medium'], fg=THEME['accent'], padx=15, pady=10)
        color_frame.pack(fill="both", expand=True, padx=10, pady=10)
        
        self.color_button = tk.Button(color_frame, text="Выбрать цвет", command=self.choose_color,
                                     font=("Segoe UI", 12), bg=self.current_color, 
                                     fg=self._get_text_color(self.current_color),
                                     relief="flat", padx=20, pady=15, cursor="hand2")
        self.color_button.pack(pady=10)
        
        rgb_frame = tk.Frame(color_frame, bg=THEME['bg_medium'])
        rgb_frame.pack(fill="x", pady=10)
        
        tk.Label(rgb_frame, text="R:", font=("Segoe UI", 11), bg=THEME['bg_medium'], fg="#ff4444").grid(row=0, column=0, sticky="w")
        self.red_scale = tk.Scale(rgb_frame, from_=0, to=255, orient="horizontal", command=self.on_rgb_change,
                                 bg=THEME['bg_medium'], fg="#ff4444", troughcolor="#ff4444", highlightthickness=0)
        self.red_scale.set(255)
        self.red_scale.grid(row=0, column=1, sticky="ew", pady=2)
        
        tk.Label(rgb_frame, text="G:", font=("Segoe UI", 11), bg=THEME['bg_medium'], fg="#44ff44").grid(row=1, column=0, sticky="w")
        self.green_scale = tk.Scale(rgb_frame, from_=0, to=255, orient="horizontal", command=self.on_rgb_change,
                                   bg=THEME['bg_medium'], fg="#44ff44", troughcolor="#44ff44", highlightthickness=0)
        self.green_scale.set(0)
        self.green_scale.grid(row=1, column=1, sticky="ew", pady=2)
        
        tk.Label(rgb_frame, text="B:", font=("Segoe UI", 11), bg=THEME['bg_medium'], fg="#4444ff").grid(row=2, column=0, sticky="w")
        self.blue_scale = tk.Scale(rgb_frame, from_=0, to=255, orient="horizontal", command=self.on_rgb_change,
                                  bg=THEME['bg_medium'], fg="#4444ff", troughcolor="#4444ff", highlightthickness=0)
        self.blue_scale.set(0)
        self.blue_scale.grid(row=2, column=1, sticky="ew", pady=2)
        
        rgb_frame.grid_columnconfigure(1, weight=1)
        
        right = tk.Frame(content, bg=THEME['bg_medium'])
        right.pack(side="right", fill="both", padx=(10, 0))
        
        bright_frame = tk.LabelFrame(right, text="Яркость", font=("Segoe UI", 12, "bold"), bg=THEME['bg_medium'], fg=THEME['accent'], padx=15, pady=10)
        bright_frame.pack(fill="x", padx=10, pady=10)
        ttk.Combobox(bright_frame, textvariable=self.current_brightness, values=list(BRIGHTNESS_LEVELS.keys()), state="readonly").pack(fill="x", pady=5)
        
        speed_frame = tk.LabelFrame(right, text="Скорость", font=("Segoe UI", 12, "bold"), bg=THEME['bg_medium'], fg=THEME['accent'], padx=15, pady=10)
        speed_frame.pack(fill="x", padx=10, pady=10)
        ttk.Combobox(speed_frame, textvariable=self.current_speed, values=list(SPEEDS.keys()), state="readonly").pack(fill="x", pady=5)
        
        btn_frame = tk.Frame(right, bg=THEME['bg_medium'])
        btn_frame.pack(fill="x", padx=10, pady=10)
        tk.Button(btn_frame, text="💾 Сохранить в Flash", command=self.save_flash, 
                 font=("Segoe UI", 11), bg=THEME['button'], fg=THEME['text'], relief="flat", padx=15, pady=5, cursor="hand2").pack(fill="x", pady=2)
        tk.Button(btn_frame, text="📂 Загрузить из Flash", command=self.load_flash,
                 font=("Segoe UI", 11), bg=THEME['button'], fg=THEME['text'], relief="flat", padx=15, pady=5, cursor="hand2").pack(fill="x", pady=2)
        tk.Button(btn_frame, text="✅ Применить", command=self.apply_rgb,
                 font=("Segoe UI", 12, "bold"), bg=THEME['accent'], fg="white", relief="flat", padx=20, pady=8, cursor="hand2").pack(fill="x", pady=5)
    
    # ========== RGB ФУНКЦИИ ==========
    def toggle_rgb(self):
        if self.usb.connected:
            self.usb.disconnect()
            self.rgb_btn.config(text="Подключить")
        else:
            if self.usb.connect():
                self.rgb_btn.config(text="Отключить")
            else:
                messagebox.showerror("Ошибка", "Не удалось подключиться")
        self.update_status_dot()
    
    def update_status_dot(self):
        self.status_dot.delete("all")
        color = "#00ff00" if self.usb.connected else "#ff0000"
        self.status_dot.create_oval(2, 2, 13, 13, fill=color, outline="")
        if self.usb.connected:
            self.rgb_btn.config(text="Отключить")
        else:
            self.rgb_btn.config(text="Подключить")
    
    def choose_color(self):
        color = colorchooser.askcolor(color=self.current_color, title="Выберите цвет")
        if color[1]:
            self.current_color = color[1]
            self.color_button.config(bg=self.current_color, fg=self._get_text_color(self.current_color))
            r, g, b = self._hex_to_rgb(color[1])
            self.red_scale.set(r)
            self.green_scale.set(g)
            self.blue_scale.set(b)
    
    def on_rgb_change(self, event=None):
        r = self.red_scale.get()
        g = self.green_scale.get()
        b = self.blue_scale.get()
        self.current_color = f"#{r:02x}{g:02x}{b:02x}"
        self.color_button.config(bg=self.current_color, fg=self._get_text_color(self.current_color))
    
    def apply_rgb(self):
        if not self.usb.connected:
            messagebox.showwarning("Предупреждение", "Устройство не подключено")
            return
        try:
            zone_mask = ZONES[self.current_zone.get()]
            r, g, b = self._hex_to_rgb(self.current_color)
            mode = self.current_mode.get()
            speed = SPEEDS[self.current_speed.get()]
            brightness = BRIGHTNESS_LEVELS[self.current_brightness.get()]
            
            if mode == "Статичный":
                success = self.usb.set_static_color(zone_mask, r, g, b, brightness)
            else:
                anim_type = ANIMATION_TYPES[mode]
                success = self.usb.set_animation(zone_mask, anim_type, speed, r, g, b, brightness)
            
            if success:
                messagebox.showinfo("Успех", "Настройки применены")
            else:
                messagebox.showerror("Ошибка", "Не удалось применить настройки")
        except Exception as e:
            messagebox.showerror("Ошибка", f"{e}")
    
    def save_flash(self):
        if self.usb.connected and self.usb.save_to_flash():
            messagebox.showinfo("Успех", "Сохранено в flash")
    
    def load_flash(self):
        if self.usb.connected and self.usb.load_from_flash():
            messagebox.showinfo("Успех", "Загружено из flash")
    
    # ========== FAN ТАБ ==========
    def create_fan_tab(self):
        tab = ttk.Frame(self.notebook)
        self.notebook.add(tab, text="🌀 Кулеры")
        
        content = tk.Frame(tab, bg=THEME['bg_dark'])
        content.pack(fill="both", expand=True, padx=20, pady=20)
        
        left = tk.Frame(content, bg=THEME['bg_medium'])
        left.pack(side="left", fill="both", expand=True, padx=(0, 10))
        
        tk.Label(left, text="КУЛЕРЫ", font=("Segoe UI", 14, "bold"), bg=THEME['bg_medium'], fg=THEME['accent']).pack(pady=10)
        
        self.fan_listbox = tk.Listbox(left, font=("Segoe UI", 12), bg=THEME['bg_light'], fg=THEME['text'],
                                      selectbackground=THEME['accent'], relief="flat", height=10)
        self.fan_listbox.pack(fill="both", expand=True, padx=15, pady=10)
        self.update_fan_list()
        
        right = tk.Frame(content, bg=THEME['bg_medium'])
        right.pack(side="right", fill="both", expand=True, padx=(10, 0))
        
        tk.Label(right, text="УПРАВЛЕНИЕ", font=("Segoe UI", 14, "bold"), bg=THEME['bg_medium'], fg=THEME['accent']).pack(pady=10)
        
        mode_frame = tk.LabelFrame(right, text="Режим работы", font=("Segoe UI", 12, "bold"), bg=THEME['bg_medium'], fg=THEME['accent'], padx=15, pady=10)
        mode_frame.pack(fill="x", padx=15, pady=10)
        
        for mode in FAN_MODES.keys():
            tk.Radiobutton(mode_frame, text=mode, variable=self.fan_mode, value=mode,
                          font=("Segoe UI", 12), bg=THEME['bg_medium'], fg=THEME['text'],
                          selectcolor=THEME['bg_light'], anchor="w", cursor="hand2").pack(fill="x", pady=3)
        
        tk.Button(right, text="🔥 Применить", command=self.apply_fan_mode,
                 font=("Segoe UI", 14, "bold"), bg=THEME['accent'], fg="white",
                 relief="flat", padx=20, pady=10, cursor="hand2").pack(fill="x", padx=15, pady=10)
        
        info_frame = tk.LabelFrame(right, text="Информация", font=("Segoe UI", 12, "bold"), bg=THEME['bg_medium'], fg=THEME['accent'], padx=15, pady=10)
        info_frame.pack(fill="x", padx=15, pady=10)
        
        self.fan_info = tk.Text(info_frame, height=5, font=("Segoe UI", 11), bg=THEME['bg_light'], fg=THEME['text'], relief="flat", wrap="word")
        self.fan_info.pack(fill="both", expand=True)
        
        tk.Label(right, text="Fn + ↑ = Максимум  |  Fn + ↓ = Авто", 
                font=("Segoe UI", 11), bg=THEME['bg_medium'], fg=THEME['text_secondary']).pack(pady=5)
    
    # ========== FAN ФУНКЦИИ ==========
    def update_fan_list(self):
        self.fan_listbox.delete(0, tk.END)
        for fan in self.fan.fan_names:
            rpm = self.fan.get_speed(fan)
            self.fan_listbox.insert(tk.END, f"{fan}: {rpm} RPM" if rpm else fan)
    
    def update_fan_speeds(self):
        self.fan.update_speeds()
        self.update_fan_list()
        self.update_fan_info()
        self.root.after(2000, self.update_fan_speeds)
    
    def update_fan_info(self):
        self.fan_info.delete(1.0, tk.END)
        mode = self.fan.get_current_mode()
        mode_names = {'auto': '🌿 Авто', 'max': '🔥 Максимум', 'balanced': '⚖️ Сбалансированный', 'quiet': '🔇 Тихий'}
        self.fan_info.insert(tk.END, f"Режим: {mode_names.get(mode, mode)}\n")
        self.fan_info.insert(tk.END, f"Кулеров: {len(self.fan.fan_names)}\n")
        for fan, rpm in self.fan.fan_speeds.items():
            self.fan_info.insert(tk.END, f"{fan}: {rpm} RPM\n")
    
    def apply_fan_mode(self):
        mode_name = self.fan_mode.get()
        mode_value = FAN_MODES[mode_name]
        if self.fan.set_mode(mode_value):
            messagebox.showinfo("Успех", f"Режим {mode_name} установлен!")
        else:
            messagebox.showerror("Ошибка", "Не удалось применить режим")
    
    # ========== ДИСПЕТЧЕР ЗАДАЧ ==========
    def create_task_tab(self):
        tab = ttk.Frame(self.notebook)
        self.notebook.add(tab, text="⚙️ Процессы")
        
        main_panel = tk.Frame(tab, bg=THEME['bg_dark'])
        main_panel.pack(fill="both", expand=True, padx=10, pady=10)
        
        top_panel = tk.Frame(main_panel, bg=THEME['bg_dark'])
        top_panel.pack(fill="x", pady=(0, 10))
        
        tk.Label(top_panel, text="ДИСПЕТЧЕР ЗАДАЧ", font=("Segoe UI", 16, "bold"), 
                bg=THEME['bg_dark'], fg=THEME['accent']).pack(side="left")
        
        btn_frame = tk.Frame(top_panel, bg=THEME['bg_dark'])
        btn_frame.pack(side="right")
        
        tk.Button(btn_frame, text="🔄 Обновить", command=self.update_task_manager,
                 font=("Segoe UI", 10), bg=THEME['button'], fg=THEME['text'], 
                 relief="flat", padx=15, pady=5, cursor="hand2").pack(side="left", padx=2)
        
        tk.Button(btn_frame, text="❌ Завершить", command=self.kill_selected,
                 font=("Segoe UI", 10), bg=THEME['accent'], fg="white", 
                 relief="flat", padx=15, pady=5, cursor="hand2").pack(side="left", padx=2)
        
        content = tk.Frame(main_panel, bg=THEME['bg_dark'])
        content.pack(fill="both", expand=True)
        
        # ЛЕВАЯ ЧАСТЬ: Таблица
        left_frame = tk.Frame(content, bg=THEME['bg_medium'])
        left_frame.pack(side="left", fill="both", expand=True)
        
        columns = ('PID', 'Имя', 'CPU %', 'Память МБ', 'Статус')
        self.process_tree = ttk.Treeview(left_frame, columns=columns, show='headings', height=22)
        
        col_widths = {'PID': 80, 'Имя': 200, 'CPU %': 100, 'Память МБ': 120, 'Статус': 120}
        for col in columns:
            self.process_tree.heading(col, text=col)
            self.process_tree.column(col, width=col_widths.get(col, 100), anchor="w" if col == 'Имя' else "center")
        
        self.process_tree.pack(fill="both", expand=True, padx=5, pady=5)
        
        # Контекстное меню
        self.context_menu = tk.Menu(self.root, tearoff=0, bg=THEME['bg_medium'], fg=THEME['text'])
        self.context_menu.add_command(label="▶️ Завершить", command=self.kill_selected)
        self.context_menu.add_command(label="⏸️ Приостановить", command=self.suspend_selected)
        self.context_menu.add_command(label="▶️ Возобновить", command=self.resume_selected)
        self.context_menu.add_separator()
        self.context_menu.add_command(label="🔄 Обновить", command=self.update_task_manager)
        
        self.process_tree.bind("<Button-3>", self.show_context_menu)
        
        # ПРАВАЯ ЧАСТЬ: Диаграммы
        right_frame = tk.Frame(content, bg=THEME['bg_medium'], width=350)
        right_frame.pack(side="right", fill="both", padx=(10, 0))
        right_frame.pack_propagate(False)
        
        tk.Label(right_frame, text="СИСТЕМНАЯ НАГРУЗКА", font=("Segoe UI", 12, "bold"),
                bg=THEME['bg_medium'], fg=THEME['accent']).pack(pady=5)
        
        # Кольцевые диаграммы
        ring_frame = tk.Frame(right_frame, bg=THEME['bg_medium'])
        ring_frame.pack(fill="x", pady=5)
        
        # CPU кольцо
        cpu_frame = tk.Frame(ring_frame, bg=THEME['bg_medium'])
        cpu_frame.pack(side="left", expand=True, fill="both")
        
        self.cpu_canvas = tk.Canvas(cpu_frame, width=130, height=130, bg=THEME['bg_medium'], highlightthickness=0)
        self.cpu_canvas.pack()
        tk.Label(cpu_frame, text="CPU", font=("Segoe UI", 10), bg=THEME['bg_medium'], fg=THEME['text_secondary']).pack()
        self.cpu_label = tk.Label(cpu_frame, text="0%", font=("Segoe UI", 14, "bold"), bg=THEME['bg_medium'], fg=THEME['accent_green'])
        self.cpu_label.pack()
        
        # RAM кольцо
        ram_frame = tk.Frame(ring_frame, bg=THEME['bg_medium'])
        ram_frame.pack(side="right", expand=True, fill="both")
        
        self.ram_canvas = tk.Canvas(ram_frame, width=130, height=130, bg=THEME['bg_medium'], highlightthickness=0)
        self.ram_canvas.pack()
        tk.Label(ram_frame, text="RAM", font=("Segoe UI", 10), bg=THEME['bg_medium'], fg=THEME['text_secondary']).pack()
        self.ram_label = tk.Label(ram_frame, text="0%", font=("Segoe UI", 14, "bold"), bg=THEME['bg_medium'], fg=THEME['accent_blue'])
        self.ram_label.pack()
        
        # Топ процессов
        top_frame = tk.LabelFrame(right_frame, text="ТОП ПРОЦЕССОВ", font=("Segoe UI", 10, "bold"),
                                 bg=THEME['bg_medium'], fg=THEME['accent_gold'], padx=10, pady=5)
        top_frame.pack(fill="both", expand=True, pady=5)
        
        self.top_listbox = tk.Listbox(top_frame, height=8, font=("Segoe UI", 10),
                                     bg=THEME['bg_light'], fg=THEME['text'], relief="flat")
        self.top_listbox.pack(fill="both", expand=True)
    
    def show_context_menu(self, event):
        item = self.process_tree.identify_row(event.y)
        if item:
            self.process_tree.selection_set(item)
            self.context_menu.post(event.x_root, event.y_root)
    
    def kill_selected(self):
        selected = self.process_tree.selection()
        if not selected:
            messagebox.showwarning("Предупреждение", "Выберите процесс")
            return
        pid = self.process_tree.item(selected[0])['values'][0]
        if messagebox.askyesno("Подтверждение", f"Завершить процесс {pid}?"):
            if self.process_manager.kill_process(pid):
                self.update_task_manager()
                messagebox.showinfo("Успех", f"Процесс {pid} завершён")
            else:
                messagebox.showerror("Ошибка", "Не удалось завершить процесс")
    
    def suspend_selected(self):
        selected = self.process_tree.selection()
        if not selected:
            messagebox.showwarning("Предупреждение", "Выберите процесс")
            return
        pid = self.process_tree.item(selected[0])['values'][0]
        if self.process_manager.suspend_process(pid):
            self.update_task_manager()
            messagebox.showinfo("Успех", f"Процесс {pid} приостановлен")
        else:
            messagebox.showerror("Ошибка", "Не удалось приостановить процесс")
    
    def resume_selected(self):
        selected = self.process_tree.selection()
        if not selected:
            messagebox.showwarning("Предупреждение", "Выберите процесс")
            return
        pid = self.process_tree.item(selected[0])['values'][0]
        if self.process_manager.resume_process(pid):
            self.update_task_manager()
            messagebox.showinfo("Успех", f"Процесс {pid} возобновлён")
        else:
            messagebox.showerror("Ошибка", "Не удалось возобновить процесс")
    
    def update_task_manager(self):
        self.process_manager.update()
        
        # Обновляем таблицу
        for item in self.process_tree.get_children():
            self.process_tree.delete(item)
        
        for p in self.process_manager.processes[:50]:
            self.process_tree.insert('', tk.END, values=(
                p['pid'],
                p['name'],
                f"{p['cpu_percent']:.1f}",
                p['memory'],
                p['status']
            ))
        
        # Обновляем кольцевые диаграммы
        cpu_percent = self.process_manager.cpu_percent
        ram_percent = self.process_manager.memory_percent
        
        self.cpu_label.config(text=f"{cpu_percent:.0f}%")
        self.ram_label.config(text=f"{ram_percent:.0f}%")
        
        self.draw_ring(self.cpu_canvas, 130, cpu_percent, THEME['accent_green'])
        self.draw_ring(self.ram_canvas, 130, ram_percent, THEME['accent_blue'])
        
        # Обновляем топ процессов
        self.top_listbox.delete(0, tk.END)
        top_proc = self.process_manager.get_top_cpu(8)
        for p in top_proc:
            self.top_listbox.insert(tk.END, f"{p['name'][:20]:<20} CPU: {p['cpu_percent']:.1f}%")
        
        self.root.after(3000, self.update_task_manager)
    
    def draw_ring(self, canvas, size, percent, color):
        canvas.delete("all")
        cx, cy = size//2, size//2
        radius = size//2 - 15
        start_angle = 90
        extent = -(percent / 100) * 360
        
        canvas.create_oval(cx-radius, cy-radius, cx+radius, cy+radius, 
                          outline=THEME['bg_light'], width=8)
        
        if percent > 0:
            canvas.create_arc(cx-radius, cy-radius, cx+radius, cy+radius,
                             start=start_angle, extent=extent,
                             outline=color, width=8, style=tk.ARC)
        
        canvas.create_text(cx, cy, text=f"{percent:.0f}%", 
                          font=("Segoe UI", 12, "bold"), fill=color)
    
    # ========== ОЧИСТИТЕЛЬ ==========
    def create_cleaner_tab(self):
        tab = ttk.Frame(self.notebook)
        self.notebook.add(tab, text="🧹 Очистка")
        
        main = tk.Frame(tab, bg=THEME['bg_dark'])
        main.pack(fill="both", expand=True, padx=30, pady=20)
        
        tk.Label(main, text="ОЧИСТИТЕЛЬ СИСТЕМЫ", font=("Segoe UI", 18, "bold"), 
                bg=THEME['bg_dark'], fg=THEME['accent']).pack(pady=10)
        
        self.clean_items = {}
        items = [
            ("🌐 Кэш браузеров", "browser_cache"),
            ("📁 Временные файлы /tmp", "tmp_files"),
            ("📦 Кэш пакетов", "package_cache"),
            ("📋 Старые логи", "old_logs"),
            ("🖼️ Миниатюры", "thumbnails"),
            ("🗑️ Корзина", "trash")
        ]
        
        for text, var_name in items:
            var = tk.BooleanVar(value=True)
            self.clean_items[var_name] = var
            tk.Checkbutton(main, text=text, variable=var, bg=THEME['bg_dark'], fg=THEME['text'],
                          selectcolor=THEME['bg_light'], font=("Segoe UI", 12), anchor="w",
                          activebackground=THEME['bg_dark'], activeforeground=THEME['accent']).pack(anchor="w", pady=3)
        
        btn_frame = tk.Frame(main, bg=THEME['bg_dark'])
        btn_frame.pack(pady=15)
        
        tk.Button(btn_frame, text="🔍 Найти мусор", command=self.scan_junk,
                 font=("Segoe UI", 12), bg=THEME['accent_blue'], fg="white", 
                 relief="flat", padx=20, pady=5, cursor="hand2").pack(side="left", padx=5)
        tk.Button(btn_frame, text="🗑️ Удалить выбранное", command=self.clean_selected,
                 font=("Segoe UI", 12), bg=THEME['accent'], fg="white", 
                 relief="flat", padx=20, pady=5, cursor="hand2").pack(side="left", padx=5)
        
        self.clean_output = scrolledtext.ScrolledText(main, height=8, font=("Segoe UI", 11),
                                                      bg=THEME['bg_light'], fg=THEME['text'], relief="flat")
        self.clean_output.pack(fill="both", expand=True, pady=10)
        self.clean_output.insert(tk.END, "Нажмите 'Найти мусор' для сканирования...\n")
    
    def scan_junk(self):
        self.clean_output.delete(1.0, tk.END)
        self.clean_output.insert(tk.END, "🔍 Сканирование...\n")
        junk_size = 0
        
        if self.clean_items['browser_cache'].get():
            dirs = [os.path.expanduser("~/.cache/google-chrome"), os.path.expanduser("~/.cache/mozilla/firefox")]
            total = 0
            for d in dirs:
                if os.path.exists(d):
                    for root, _, files in os.walk(d):
                        for f in files:
                            try:
                                total += os.path.getsize(os.path.join(root, f))
                            except:
                                pass
            if total > 0:
                junk_size += total // (1024*1024)
                self.clean_output.insert(tk.END, f"  🌐 Кэш браузеров: {total//(1024*1024)} МБ\n")
        
        if self.clean_items['tmp_files'].get():
            total = 0
            for f in os.listdir('/tmp'):
                path = os.path.join('/tmp', f)
                if os.path.isfile(path):
                    try:
                        total += os.path.getsize(path)
                    except:
                        pass
            if total > 0:
                junk_size += total // (1024*1024)
                self.clean_output.insert(tk.END, f"  📁 Временные файлы: {total//(1024*1024)} МБ\n")
        
        if self.clean_items['trash'].get():
            trash = os.path.expanduser("~/.local/share/Trash/files")
            if os.path.exists(trash):
                total = 0
                for f in os.listdir(trash):
                    path = os.path.join(trash, f)
                    try:
                        total += os.path.getsize(path)
                    except:
                        pass
                if total > 0:
                    junk_size += total // (1024*1024)
                    self.clean_output.insert(tk.END, f"  🗑️ Корзина: {total//(1024*1024)} МБ\n")
        
        self.clean_output.insert(tk.END, f"\n✅ Найдено мусора: {junk_size} МБ\n")
    
    def clean_selected(self):
        if not messagebox.askyesno("Подтверждение", "Удалить выбранное?"):
            return
        self.clean_output.insert(tk.END, "\n🧹 Очистка...\n")
        
        if self.clean_items['browser_cache'].get():
            for d in [os.path.expanduser("~/.cache/google-chrome"), os.path.expanduser("~/.cache/mozilla/firefox")]:
                if os.path.exists(d):
                    try:
                        subprocess.run(['rm', '-rf', d], capture_output=True)
                        self.clean_output.insert(tk.END, f"  ✅ Удалён: {d}\n")
                    except:
                        pass
        
        if self.clean_items['tmp_files'].get():
            for f in os.listdir('/tmp'):
                path = os.path.join('/tmp', f)
                if os.path.isfile(path):
                    try:
                        os.remove(path)
                        self.clean_output.insert(tk.END, f"  ✅ Удалён: {path}\n")
                    except:
                        pass
        
        if self.clean_items['trash'].get():
            trash = os.path.expanduser("~/.local/share/Trash/files")
            if os.path.exists(trash):
                try:
                    subprocess.run(['rm', '-rf', trash + '/*'], capture_output=True)
                    self.clean_output.insert(tk.END, "  ✅ Корзина очищена\n")
                except:
                    pass
        
        self.clean_output.insert(tk.END, "\n🎉 Очистка завершена!\n")
    
    # ========== О ПРОГРАММЕ ==========
    def create_about_tab(self):
        tab = ttk.Frame(self.notebook)
        self.notebook.add(tab, text="О программе")
        
        main = tk.Frame(tab, bg=THEME['bg_dark'])
        main.pack(fill="both", expand=True, padx=40, pady=40)
        
        logo = """
        ███╗   ███╗███████╗██╗
        ████╗ ████║██╔════╝██║
        ██╔████╔██║███████╗██║
        ██║╚██╔╝██║╚════██║██║
        ██║ ╚═╝ ██║███████║██║
        ╚═╝     ╚═╝╚══════╝╚═╝
        """
        
        tk.Label(main, text=logo, font=("Courier", 14, "bold"), bg=THEME['bg_dark'], 
                fg=THEME['accent'], justify="center").pack(pady=10)
        
        tk.Label(main, text="MSI CENTER ULTIMATE v2.0", font=("Segoe UI", 24, "bold"), 
                bg=THEME['bg_dark'], fg=THEME['text']).pack(pady=5)
        tk.Label(main, text="Всё в одном: RGB + Кулеры + Диспетчер + Очиститель", 
                font=("Segoe UI", 14), bg=THEME['bg_dark'], fg=THEME['text_secondary']).pack(pady=5)
        
        tk.Frame(main, height=2, bg=THEME['bg_light']).pack(fill="x", pady=15)
        
        features = [
            "🎨 RGB управление клавиатурой",
            "🌀 Управление кулерами (Fn+Стрелки)",
            "⚙️ Диспетчер задач с диаграммами",
            "🧹 Очиститель системы",
            "🔧 Работает только с правами ROOT"
        ]
        
        for f in features:
            tk.Label(main, text=f, font=("Segoe UI", 12), bg=THEME['bg_dark'], 
                    fg=THEME['text']).pack(anchor="w", pady=3)
        
        tk.Frame(main, height=2, bg=THEME['bg_light']).pack(fill="x", pady=15)
        
        info = f"Python: {os.sys.version.split()[0]}  |  ОС: {os.uname().sysname}  |  Лицензия: MIT"
        tk.Label(main, text=info, font=("Segoe UI", 11), bg=THEME['bg_dark'], 
                fg=THEME['text_secondary']).pack(pady=5)

# ========== ГЛАВНАЯ ==========
def main():
    check_and_request_permissions()
    root = tk.Tk()
    app = MSICenterUltimate(root)
    
    try:
        root.mainloop()
    except KeyboardInterrupt:
        print("\nПриложение остановлено")

if __name__ == "__main__":
    main()