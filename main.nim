# MSI Center Ultimate - Nim GTK версия с улучшенным UI
# Компиляция: nim c -d:release --passC:"$(pkg-config --cflags gtk+-3.0)" --passL:"$(pkg-config --libs gtk+-3.0)" -o:msi_center main.nim

import std/[strutils, os, osproc, sequtils, times, options, tables, strformat, re, algorithm, math]
import std/posix

# Импортируем GTK через FFI
{.passL: "-lgtk-3 -lgdk-3 -lgio-2.0 -lgobject-2.0 -lglib-2.0 -lcairo -lpango-1.0".}

type
  # Базовые типы для GTK
  GObject* = object
  GtkWidget* = object
  GtkWindow* = object
  GtkBox* = object
  GtkButton* = object
  GtkLabel* = object
  GtkNotebook* = object
  GtkFrame* = object
  GtkScrolledWindow* = object
  GtkDrawingArea* = object
  GList* = object
  GtkAdjustment* = object
  GtkAllocation* = object
    x*, y*, width*, height*: int
  GdkEvent* = object

  PgWidget* = ptr GtkWidget
  PgWindow* = ptr GtkWindow
  PgBox* = ptr GtkBox
  PgButton* = ptr GtkButton
  PgLabel* = ptr GtkLabel
  PgNotebook* = ptr GtkNotebook
  PgFrame* = ptr GtkFrame
  PgScrolledWindow* = ptr GtkScrolledWindow
  PgDrawingArea* = ptr GtkDrawingArea
  PgList* = ptr GList
  PgAdjustment* = ptr GtkAdjustment
  PgEvent* = ptr GdkEvent
  
  GCallback* = proc(widget: PgWidget, data: pointer) {.cdecl.}
  GtkDrawCallback* = proc(widget: PgWidget, cr: pointer, data: pointer): int {.cdecl.}

# Импорт функций GTK
proc gtk_init(argc: ptr int, argv: ptr cstring) {.importc, header: "<gtk/gtk.h>".}
proc gtk_window_new(typ: int32): PgWindow {.importc, header: "<gtk/gtk.h>".}
proc gtk_window_set_title(window: PgWindow, title: cstring) {.importc, header: "<gtk/gtk.h>".}
proc gtk_widget_show_all(widget: PgWidget) {.importc, header: "<gtk/gtk.h>".}
proc gtk_widget_set_size_request(widget: PgWidget, width: int, height: int) {.importc, header: "<gtk/gtk.h>".}
proc gtk_widget_set_margin_start(widget: PgWidget, margin: int) {.importc, header: "<gtk/gtk.h>".}
proc gtk_widget_set_margin_end(widget: PgWidget, margin: int) {.importc, header: "<gtk/gtk.h>".}
proc gtk_widget_set_margin_top(widget: PgWidget, margin: int) {.importc, header: "<gtk/gtk.h>".}
proc gtk_widget_set_margin_bottom(widget: PgWidget, margin: int) {.importc, header: "<gtk/gtk.h>".}
proc gtk_widget_destroy(widget: PgWidget) {.importc, header: "<gtk/gtk.h>".}
proc gtk_main() {.importc, header: "<gtk/gtk.h>".}
proc gtk_main_quit() {.importc, header: "<gtk/gtk.h>".}
proc gtk_widget_get_allocation(widget: PgWidget, allocation: ptr GtkAllocation) {.importc, header: "<gtk/gtk.h>".}

# Контейнеры
proc gtk_box_new(orientation: int, spacing: int): PgBox {.importc, header: "<gtk/gtk.h>".}
proc gtk_button_new_with_label(label: cstring): PgButton {.importc, header: "<gtk/gtk.h>".}
proc gtk_button_set_label(button: PgButton, label: cstring) {.importc, header: "<gtk/gtk.h>".}
proc gtk_label_new(label: cstring): PgLabel {.importc, header: "<gtk/gtk.h>".}
proc gtk_label_set_markup(label: PgLabel, markup: cstring) {.importc, header: "<gtk/gtk.h>".}
proc gtk_label_set_text(label: PgLabel, text: cstring) {.importc, header: "<gtk/gtk.h>".}
proc gtk_notebook_new(): PgNotebook {.importc, header: "<gtk/gtk.h>".}
proc gtk_notebook_append_page(notebook: PgNotebook, child: PgWidget, tab_label: PgWidget) {.importc, header: "<gtk/gtk.h>".}
proc gtk_frame_new(label: cstring): PgFrame {.importc, header: "<gtk/gtk.h>".}
proc gtk_scrolled_window_new(hadj: PgAdjustment, vadj: PgAdjustment): PgScrolledWindow {.importc, header: "<gtk/gtk.h>".}
proc gtk_scrolled_window_set_policy(scrolled: PgScrolledWindow, hpolicy: int, vpolicy: int) {.importc, header: "<gtk/gtk.h>".}
proc gtk_container_get_children(container: PgWidget): PgList {.importc, header: "<gtk/gtk.h>".}
proc gtk_drawing_area_new(): PgDrawingArea {.importc, header: "<gtk/gtk.h>".}
proc gtk_widget_queue_draw(widget: PgWidget) {.importc, header: "<gtk/gtk.h>".}

# Cairo для рисования
proc cairo_create(surface: pointer): pointer {.importc, header: "<cairo.h>".}
proc cairo_arc(cr: pointer, x: cdouble, y: cdouble, radius: cdouble, angle1: cdouble, angle2: cdouble) {.importc, header: "<cairo.h>".}
proc cairo_set_source_rgb(cr: pointer, red: cdouble, green: cdouble, blue: cdouble) {.importc, header: "<cairo.h>".}
proc cairo_set_line_width(cr: pointer, width: cdouble) {.importc, header: "<cairo.h>".}
proc cairo_stroke(cr: pointer) {.importc, header: "<cairo.h>".}
proc cairo_fill(cr: pointer) {.importc, header: "<cairo.h>".}
proc cairo_set_source_rgba(cr: pointer, red: cdouble, green: cdouble, blue: cdouble, alpha: cdouble) {.importc, header: "<cairo.h>".}
proc cairo_rectangle(cr: pointer, x: cdouble, y: cdouble, width: cdouble, height: cdouble) {.importc, header: "<cairo.h>".}
proc cairo_show_text(cr: pointer, text: cstring) {.importc, header: "<cairo.h>".}
proc cairo_select_font_face(cr: pointer, family: cstring, slant: int, weight: int) {.importc, header: "<cairo.h>".}
proc cairo_set_font_size(cr: pointer, size: cdouble) {.importc, header: "<cairo.h>".}
proc cairo_text_extents(cr: pointer, text: cstring, extents: pointer) {.importc, header: "<cairo.h>".}
proc cairo_move_to(cr: pointer, x: cdouble, y: cdouble) {.importc, header: "<cairo.h>".}

# GList функции
proc g_list_length(list: PgList): int {.importc, header: "<glib.h>".}
proc g_list_nth_data(list: PgList, n: int): pointer {.importc, header: "<glib.h>".}
proc g_list_free(list: PgList) {.importc, header: "<glib.h>".}

# Упаковка
proc gtk_container_add(container: PgWidget, widget: PgWidget) {.importc, header: "<gtk/gtk.h>".}
proc gtk_box_pack_start(box: PgBox, child: PgWidget, expand: int, fill: int, padding: int) {.importc, header: "<gtk/gtk.h>".}
proc gtk_box_pack_end(box: PgBox, child: PgWidget, expand: int, fill: int, padding: int) {.importc, header: "<gtk/gtk.h>".}

# Сигналы
proc g_signal_connect(widget: PgWidget, name: cstring, callback: GCallback, data: pointer) {.importc, header: "<glib-object.h>".}
proc g_signal_connect_after(widget: PgWidget, name: cstring, callback: pointer, data: pointer) {.importc, header: "<glib-object.h>".}

# Константы
const
  GTK_WINDOW_TOPLEVEL = 0
  GTK_ORIENTATION_HORIZONTAL = 0
  GTK_ORIENTATION_VERTICAL = 1
  GTK_POLICY_AUTOMATIC = 1
  CAIRO_FONT_SLANT_NORMAL = 0
  CAIRO_FONT_WEIGHT_BOLD = 1

# ============== Типы данных ==============
type
  Zone* = enum znAll = 0, zn1, zn2, zn3, zn4
  AnimationType* = enum anStatic = 0, anBreathing, anWave, anReactive, anRainbow, anGradient
  Speed* = enum spVerySlow = 0, spSlow, spMedium, spFast, spVeryFast
  Brightness* = enum brOff = 0, brLow, brMedium, brHigh, brMaximum
  FanMode* = enum fmAuto = 0, fmMax, fmBalanced, fmQuiet

  RGBColor* = object
    r*, g*, b*: uint8

  ProcessInfo* = object
    pid*: int
    name*: string
    cpuTime*: int
    memory*: int
    status*: char
    cpuPercent*: float

  AppState* = ref object
    # USB
    isConnected*: bool
    # RGB
    currentColor*: RGBColor
    currentZone*: Zone
    currentAnimation*: AnimationType
    currentSpeed*: Speed
    currentBrightness*: Brightness
    # Fans
    fanMode*: FanMode
    fanSpeeds*: Table[string, string]
    # Stats
    cpuPercent*: float
    memoryPercent*: float
    processes*: seq[ProcessInfo]
    prevCpuTimes*: tuple[total: int64, idle: int64]
    # Widgets
    statusLabel*: PgLabel
    colorButton*: PgButton
    processBox*: PgBox
    notebook*: PgNotebook
    cpuCanvas*: PgDrawingArea
    ramCanvas*: PgDrawingArea
    cpuLabel*: PgLabel
    ramLabel*: PgLabel

# ============== Константы ==============
const
  ZONE_NAMES: array[Zone, string] = ["Вся клавиатура", "Зона 1", "Зона 2", "Зона 3", "Зона 4"]
  ANIM_NAMES: array[AnimationType, string] = ["Статичный", "Дыхание", "Волна", "Реактивный", "Радуга", "Градиент"]
  SPEED_NAMES: array[Speed, string] = ["Очень медленно", "Медленно", "Средне", "Быстро", "Очень быстро"]
  BRIGHT_NAMES: array[Brightness, string] = ["Выкл", "Низкая", "Средняя", "Высокая", "Максимальная"]
  FAN_MODE_NAMES: array[FanMode, string] = ["🌿 Авто", "🔥 Максимум", "⚖️ Сбалансированный", "🔇 Тихий"]

# ============== Утилиты ==============
proc hexToRgb(hex: string): RGBColor =
  var clean = hex.strip()
  if clean.len > 0 and clean[0] == '#':
    clean = clean[1..^1]
  if clean.len == 6:
    result.r = parseHexInt(clean[0..1]).uint8
    result.g = parseHexInt(clean[2..3]).uint8
    result.b = parseHexInt(clean[4..5]).uint8

proc rgbToHex(c: RGBColor): string =
  "#" & toHex(c.r.int, 2) & toHex(c.g.int, 2) & toHex(c.b.int, 2)

proc isDarkColor(c: RGBColor): bool =
  let brightness = (c.r.float * 299 + c.g.float * 587 + c.b.float * 114) / 1000
  return brightness <= 180

# ============== Системные функции ==============
proc getCpuTimes(): tuple[total: int64, idle: int64] =
  try:
    let stat = readFile("/proc/stat").splitLines()[0]
    let parts = stat.splitWhitespace()
    if parts.len >= 5 and parts[0] == "cpu":
      var total: int64 = 0
      for i in 1..<parts.len:
        total += parseInt(parts[i]).int64
      let idle = (parseInt(parts[4]) + parseInt(parts[5])).int64
      result = (total, idle)
  except:
    result = (0'i64, 0'i64)

proc getMemInfo(): tuple[total: int64, used: int64] =
  try:
    let content = readFile("/proc/meminfo")
    var memTotal, memAvailable: int64 = 0
    for line in content.splitLines():
      if line.startsWith("MemTotal:"):
        memTotal = parseInt(line.splitWhitespace()[1]).int64
      elif line.startsWith("MemAvailable:"):
        memAvailable = parseInt(line.splitWhitespace()[1]).int64
    result.total = memTotal
    result.used = memTotal - memAvailable
  except:
    result = (0'i64, 0'i64)

proc updateProcesses(): seq[ProcessInfo] =
  var procs: seq[ProcessInfo] = @[]
  for pidDir in walkPattern("/proc/[0-9]*"):
    let pid = parseInt(pidDir.split('/')[^1])
    try:
      let comm = readFile(pidDir / "comm").strip()
      let stat = readFile(pidDir / "stat")
      let parts = stat.splitWhitespace()
      if parts.len >= 24:
        let utime = parseInt(parts[13])
        let stime = parseInt(parts[14])
        let rss = parseInt(parts[23]) * 4 div 1024
        let status = parts[2][0]
        procs.add(ProcessInfo(
          pid: pid,
          name: if comm.len > 30: comm[0..29] else: comm,
          cpuTime: utime + stime,
          memory: rss,
          status: status,
          cpuPercent: 0.0
        ))
    except:
      discard
  
  procs.sort(proc(a, b: ProcessInfo): int = cmp(b.cpuTime, a.cpuTime))
  let totalCpu = procs.mapIt(it.cpuTime).foldl(a + b, 0)
  for p in procs.mitems():
    if totalCpu > 0:
      p.cpuPercent = (p.cpuTime.float / totalCpu.float) * 100
      p.cpuPercent = min(99.9, p.cpuPercent)
  return procs

proc updateStats(app: AppState) =
  let cpuTimes = getCpuTimes()
  let memInfo = getMemInfo()
  
  var cpuPercent = 0.0
  if app.prevCpuTimes.total > 0:
    let totalDiff = cpuTimes.total - app.prevCpuTimes.total
    let idleDiff = cpuTimes.idle - app.prevCpuTimes.idle
    if totalDiff > 0:
      cpuPercent = ((totalDiff - idleDiff).float / totalDiff.float) * 100
      cpuPercent = max(0.0, min(100.0, cpuPercent))
  
  app.prevCpuTimes = cpuTimes
  app.cpuPercent = cpuPercent
  app.memoryPercent = if memInfo.total > 0: (memInfo.used.float / memInfo.total.float) * 100 else: 0.0
  app.processes = updateProcesses()

proc detectFans(): seq[string] =
  var names: seq[string] = @[]
  try:
    for hwmonPath in walkPattern("/sys/class/hwmon/hwmon*/"):
      let namePath = hwmonPath / "name"
      if fileExists(namePath):
        let deviceName = readFile(namePath).strip()
        for fanFile in walkPattern(hwmonPath / "fan*_input"):
          let matches = fanFile.findAll(re"fan(\d+)_input")
          if matches.len > 0:
            let fanNum = matches[0].replace(re"fan(\d+)_input", "$1")
            names.add(deviceName & " Fan " & fanNum)
  except:
    discard
  if names.len == 0:
    names = @["CPU Fan", "System Fan"]
  return names

proc updateFanSpeeds(): Table[string, string] =
  var speeds = initTable[string, string]()
  try:
    for hwmonPath in walkPattern("/sys/class/hwmon/hwmon*/"):
      for fanFile in walkPattern(hwmonPath / "fan*_input"):
        try:
          let speed = readFile(fanFile).strip()
          let matches = fanFile.findAll(re"fan(\d+)_input")
          if matches.len > 0:
            let fanNum = matches[0].replace(re"fan(\d+)_input", "$1")
            speeds["Fan " & fanNum] = speed
        except:
          discard
  except:
    discard
  return speeds

# ============== Рисование колец ==============
proc drawRing(cr: pointer, size: int, percent: float, color: string, label: string) =
  let cx = size.float / 2
  let cy = size.float / 2
  let radius = (size.float / 2) - 15
  let startAngle = -90.float * (PI / 180)
  let endAngle = startAngle + (percent / 100) * 360 * (PI / 180)
  
  # Фон
  cairo_set_source_rgb(cr, 0.2, 0.2, 0.2)
  cairo_arc(cr, cx, cy, radius, 0, 2 * PI)
  cairo_set_line_width(cr, 8)
  cairo_stroke(cr)
  
  # Заполнение
  if percent > 0:
    var r, g, b: cdouble
    case color
    of "green":
      r = 0.267; g = 1.0; b = 0.267
    of "blue":
      r = 0.267; g = 0.267; b = 1.0
    of "red":
      r = 1.0; g = 0.267; b = 0.267
    of "gold":
      r = 1.0; g = 0.843; b = 0.0
    else:
      r = 0.267; g = 0.267; b = 0.267
    
    cairo_set_source_rgb(cr, r, g, b)
    cairo_arc(cr, cx, cy, radius, startAngle, endAngle)
    cairo_set_line_width(cr, 8)
    cairo_stroke(cr)
  
  # Текст процента
  cairo_set_source_rgb(cr, 1.0, 1.0, 1.0)
  cairo_select_font_face(cr, "Segoe UI", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
  cairo_set_font_size(cr, 18)
  let text = fmt"{percent:.0f}%"
  cairo_move_to(cr, cx - 25, cy + 7)
  cairo_show_text(cr, text.cstring)

# ============== Callbacks ==============
proc onConnect(widget: PgWidget, data: pointer) {.cdecl.} =
  let app = cast[AppState](data)
  app.isConnected = not app.isConnected
  let label = if app.isConnected: "✅ USB подключен" else: "❌ USB отключен"
  gtk_label_set_markup(app.statusLabel, label.cstring)

proc onColorClick(widget: PgWidget, data: pointer) {.cdecl.} =
  let app = cast[AppState](data)
  let c = app.currentColor
  if c.r == 255 and c.g == 0 and c.b == 0:
    app.currentColor = RGBColor(r: 0, g: 255, b: 0)
  elif c.r == 0 and c.g == 255 and c.b == 0:
    app.currentColor = RGBColor(r: 0, g: 0, b: 255)
  elif c.r == 0 and c.g == 0 and c.b == 255:
    app.currentColor = RGBColor(r: 255, g: 255, b: 0)
  elif c.r == 255 and c.g == 255 and c.b == 0:
    app.currentColor = RGBColor(r: 255, g: 0, b: 255)
  elif c.r == 255 and c.g == 0 and c.b == 255:
    app.currentColor = RGBColor(r: 0, g: 255, b: 255)
  else:
    app.currentColor = RGBColor(r: 255, g: 0, b: 0)
  
  let hex = rgbToHex(app.currentColor)
  gtk_button_set_label(app.colorButton, ("Цвет " & hex).cstring)

proc onRefresh(widget: PgWidget, data: pointer) {.cdecl.} =
  let app = cast[AppState](data)
  updateStats(app)
  
  # Обновляем список процессов
  let children = gtk_container_get_children(cast[PgWidget](app.processBox))
  if children != nil:
    let len = g_list_length(children)
    for i in 0..<len:
      let child = cast[PgWidget](g_list_nth_data(children, i))
      if child != nil:
        gtk_widget_destroy(child)
    g_list_free(children)
  
  for p in app.processes[0..<min(15, app.processes.len)]:
    let row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5)
    let pidLabel = gtk_label_new(cstring($p.pid))
    let nameLabel = gtk_label_new(cstring(p.name))
    let cpuLabel = gtk_label_new(cstring(formatFloat(p.cpuPercent, ffDefault, 1) & "%"))
    let memLabel = gtk_label_new(cstring($p.memory & " МБ"))
    let statusStr = case p.status
      of 'R': "▶️"
      of 'S': "💤"
      of 'D': "⏳"
      of 'Z': "🧟"
      of 'T': "⏸️"
      else: "  "
    let statusLabel = gtk_label_new(cstring(statusStr))
    
    gtk_box_pack_start(row, cast[PgWidget](pidLabel), 0, 0, 2)
    gtk_box_pack_start(row, cast[PgWidget](nameLabel), 1, 1, 2)
    gtk_box_pack_start(row, cast[PgWidget](cpuLabel), 0, 0, 2)
    gtk_box_pack_start(row, cast[PgWidget](memLabel), 0, 0, 2)
    gtk_box_pack_start(row, cast[PgWidget](statusLabel), 0, 0, 2)
    gtk_box_pack_start(app.processBox, cast[PgWidget](row), 0, 0, 2)
  
  gtk_widget_show_all(cast[PgWidget](app.processBox))
  
  # Обновляем кольца
  gtk_widget_queue_draw(cast[PgWidget](app.cpuCanvas))
  gtk_widget_queue_draw(cast[PgWidget](app.ramCanvas))
  
  # Обновляем метки
  let cpuText = fmt"{app.cpuPercent:.0f}%"
  gtk_label_set_text(app.cpuLabel, cpuText.cstring)
  let ramText = fmt"{app.memoryPercent:.0f}%"
  gtk_label_set_text(app.ramLabel, ramText.cstring)

proc onDrawRing(widget: PgWidget, cr: pointer, data: pointer): int {.cdecl.} =
  let app = cast[AppState](data)
  var allocation: GtkAllocation
  gtk_widget_get_allocation(widget, addr(allocation))
  let size = min(allocation.width, allocation.height)
  
  let isCpu = widget == cast[PgWidget](app.cpuCanvas)
  
  if isCpu:
    drawRing(cr, size, app.cpuPercent, "green", "CPU")
  else:
    drawRing(cr, size, app.memoryPercent, "blue", "RAM")
  
  return 0

# ============== Создание GUI ==============
proc createGUI(): AppState =
  new(result)
  result.isConnected = false
  result.currentColor = RGBColor(r: 255, g: 0, b: 0)
  result.currentZone = znAll
  result.currentAnimation = anStatic
  result.currentSpeed = spMedium
  result.currentBrightness = brMaximum
  result.fanMode = fmAuto
  result.fanSpeeds = updateFanSpeeds()
  result.prevCpuTimes = (0'i64, 0'i64)
  
  let window = gtk_window_new(GTK_WINDOW_TOPLEVEL)
  gtk_window_set_title(window, "MSI Center Ultimate")
  gtk_widget_set_size_request(cast[PgWidget](window), 1200, 800)
  
  let mainBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 5)
  gtk_container_add(cast[PgWidget](window), cast[PgWidget](mainBox))
  
  # Статус бар
  let statusBox = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5)
  gtk_box_pack_start(mainBox, cast[PgWidget](statusBox), 0, 0, 5)
  gtk_widget_set_margin_start(cast[PgWidget](statusBox), 10)
  gtk_widget_set_margin_end(cast[PgWidget](statusBox), 10)
  
  result.statusLabel = gtk_label_new("❌ USB отключен")
  gtk_box_pack_start(statusBox, cast[PgWidget](result.statusLabel), 0, 0, 5)
  
  let connectBtn = gtk_button_new_with_label("Подключить")
  g_signal_connect(cast[PgWidget](connectBtn), "clicked", onConnect, cast[pointer](result))
  gtk_box_pack_end(statusBox, cast[PgWidget](connectBtn), 0, 0, 5)
  
  let notebook = gtk_notebook_new()
  result.notebook = notebook
  gtk_box_pack_start(mainBox, cast[PgWidget](notebook), 1, 1, 5)
  
  # === Вкладка RGB ===
  let rgbBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10)
  gtk_widget_set_margin_start(cast[PgWidget](rgbBox), 10)
  gtk_widget_set_margin_end(cast[PgWidget](rgbBox), 10)
  gtk_widget_set_margin_top(cast[PgWidget](rgbBox), 10)
  gtk_widget_set_margin_bottom(cast[PgWidget](rgbBox), 10)
  
  let rgbContent = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10)
  gtk_box_pack_start(rgbBox, cast[PgWidget](rgbContent), 1, 1, 0)
  
  # Левая панель - Режимы
  let leftBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 5)
  
  let modeFrame = gtk_frame_new("Режим")
  let modeBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2)
  gtk_container_add(cast[PgWidget](modeFrame), cast[PgWidget](modeBox))
  gtk_box_pack_start(leftBox, cast[PgWidget](modeFrame), 0, 0, 5)
  
  for name in ANIM_NAMES:
    let btn = gtk_button_new_with_label(cstring(name))
    gtk_box_pack_start(modeBox, cast[PgWidget](btn), 0, 0, 2)
  
  let zoneFrame = gtk_frame_new("Зона")
  let zoneBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2)
  gtk_container_add(cast[PgWidget](zoneFrame), cast[PgWidget](zoneBox))
  gtk_box_pack_start(leftBox, cast[PgWidget](zoneFrame), 0, 0, 5)
  
  for name in ZONE_NAMES:
    let btn = gtk_button_new_with_label(cstring(name))
    gtk_box_pack_start(zoneBox, cast[PgWidget](btn), 0, 0, 2)
  
  gtk_box_pack_start(rgbContent, cast[PgWidget](leftBox), 0, 0, 5)
  
  # Центральная панель - Цвет
  let centerBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 5)
  
  let colorFrame = gtk_frame_new("Цвет")
  let colorBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10)
  gtk_container_add(cast[PgWidget](colorFrame), cast[PgWidget](colorBox))
  gtk_box_pack_start(centerBox, cast[PgWidget](colorFrame), 1, 1, 5)
  
  result.colorButton = gtk_button_new_with_label("Цвет #ff0000")
  g_signal_connect(cast[PgWidget](result.colorButton), "clicked", onColorClick, cast[pointer](result))
  gtk_box_pack_start(colorBox, cast[PgWidget](result.colorButton), 0, 0, 5)
  
  gtk_box_pack_start(rgbContent, cast[PgWidget](centerBox), 1, 1, 5)
  
  # Правая панель - настройки
  let rightBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 5)
  
  let brightFrame = gtk_frame_new("Яркость")
  let brightBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2)
  gtk_container_add(cast[PgWidget](brightFrame), cast[PgWidget](brightBox))
  gtk_box_pack_start(rightBox, cast[PgWidget](brightFrame), 0, 0, 5)
  
  for name in BRIGHT_NAMES:
    let btn = gtk_button_new_with_label(cstring(name))
    gtk_box_pack_start(brightBox, cast[PgWidget](btn), 0, 0, 2)
  
  let speedFrame = gtk_frame_new("Скорость")
  let speedBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2)
  gtk_container_add(cast[PgWidget](speedFrame), cast[PgWidget](speedBox))
  gtk_box_pack_start(rightBox, cast[PgWidget](speedFrame), 0, 0, 5)
  
  for name in SPEED_NAMES:
    let btn = gtk_button_new_with_label(cstring(name))
    gtk_box_pack_start(speedBox, cast[PgWidget](btn), 0, 0, 2)
  
  let applyBtn = gtk_button_new_with_label("✅ Применить")
  gtk_box_pack_start(rightBox, cast[PgWidget](applyBtn), 0, 0, 5)
  
  let saveBtn = gtk_button_new_with_label("💾 Сохранить в Flash")
  gtk_box_pack_start(rightBox, cast[PgWidget](saveBtn), 0, 0, 5)
  
  let loadBtn = gtk_button_new_with_label("📂 Загрузить из Flash")
  gtk_box_pack_start(rightBox, cast[PgWidget](loadBtn), 0, 0, 5)
  
  gtk_box_pack_start(rgbContent, cast[PgWidget](rightBox), 0, 0, 5)
  
  let rgbTabLabel = gtk_label_new("🎨 RGB")
  gtk_notebook_append_page(notebook, cast[PgWidget](rgbBox), cast[PgWidget](rgbTabLabel))
  
  # === Вкладка Кулеры ===
  let fanBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10)
  gtk_widget_set_margin_start(cast[PgWidget](fanBox), 10)
  gtk_widget_set_margin_end(cast[PgWidget](fanBox), 10)
  gtk_widget_set_margin_top(cast[PgWidget](fanBox), 10)
  gtk_widget_set_margin_bottom(cast[PgWidget](fanBox), 10)
  
  let fanContent = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10)
  gtk_box_pack_start(fanBox, cast[PgWidget](fanContent), 1, 1, 0)
  
  let fanListFrame = gtk_frame_new("Кулеры")
  let fanListBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2)
  gtk_container_add(cast[PgWidget](fanListFrame), cast[PgWidget](fanListBox))
  gtk_box_pack_start(fanContent, cast[PgWidget](fanListFrame), 1, 1, 5)
  
  let fanNames = detectFans()
  for name in fanNames:
    let speed = result.fanSpeeds.getOrDefault(name, "0")
    let label = gtk_label_new(cstring(name & ": " & speed & " RPM"))
    gtk_box_pack_start(fanListBox, cast[PgWidget](label), 0, 0, 2)
  
  let controlFrame = gtk_frame_new("Управление")
  let controlBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2)
  gtk_container_add(cast[PgWidget](controlFrame), cast[PgWidget](controlBox))
  gtk_box_pack_start(fanContent, cast[PgWidget](controlFrame), 0, 0, 5)
  
  for name in FAN_MODE_NAMES:
    let btn = gtk_button_new_with_label(cstring(name))
    gtk_box_pack_start(controlBox, cast[PgWidget](btn), 0, 0, 2)
  
  let fanApply = gtk_button_new_with_label("🔥 Применить")
  gtk_box_pack_start(controlBox, cast[PgWidget](fanApply), 0, 0, 5)
  
  let fanTabLabel = gtk_label_new("🌀 Кулеры")
  gtk_notebook_append_page(notebook, cast[PgWidget](fanBox), cast[PgWidget](fanTabLabel))
  
  # === Вкладка Процессы ===
  let taskBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10)
  gtk_widget_set_margin_start(cast[PgWidget](taskBox), 10)
  gtk_widget_set_margin_end(cast[PgWidget](taskBox), 10)
  gtk_widget_set_margin_top(cast[PgWidget](taskBox), 10)
  gtk_widget_set_margin_bottom(cast[PgWidget](taskBox), 10)
  
  let taskHeader = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5)
  gtk_box_pack_start(taskBox, cast[PgWidget](taskHeader), 0, 0, 5)
  
  let taskTitle = gtk_label_new("⚙️ ДИСПЕТЧЕР ЗАДАЧ")
  gtk_label_set_markup(taskTitle, "<b><big>⚙️ ДИСПЕТЧЕР ЗАДАЧ</big></b>")
  gtk_box_pack_start(taskHeader, cast[PgWidget](taskTitle), 0, 0, 5)
  
  let refreshBtn = gtk_button_new_with_label("🔄 Обновить")
  g_signal_connect(cast[PgWidget](refreshBtn), "clicked", onRefresh, cast[pointer](result))
  gtk_box_pack_end(taskHeader, cast[PgWidget](refreshBtn), 0, 0, 5)
  
  let taskContent = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10)
  gtk_box_pack_start(taskBox, cast[PgWidget](taskContent), 1, 1, 5)
  
  # Список процессов
  let scroll = gtk_scrolled_window_new(nil, nil)
  gtk_scrolled_window_set_policy(scroll, GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC)
  let processBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2)
  result.processBox = processBox
  gtk_container_add(cast[PgWidget](scroll), cast[PgWidget](processBox))
  gtk_box_pack_start(taskContent, cast[PgWidget](scroll), 1, 1, 5)
  
  # Заголовки
  let headerRow = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5)
  let pidH = gtk_label_new("<b>PID</b>")
  gtk_label_set_markup(pidH, "<b>PID</b>")
  let nameH = gtk_label_new("<b>Имя</b>")
  gtk_label_set_markup(nameH, "<b>Имя</b>")
  let cpuH = gtk_label_new("<b>CPU%</b>")
  gtk_label_set_markup(cpuH, "<b>CPU%</b>")
  let memH = gtk_label_new("<b>Память</b>")
  gtk_label_set_markup(memH, "<b>Память</b>")
  let statusH = gtk_label_new("<b>Статус</b>")
  gtk_label_set_markup(statusH, "<b>Статус</b>")
  
  gtk_box_pack_start(headerRow, cast[PgWidget](pidH), 0, 0, 5)
  gtk_box_pack_start(headerRow, cast[PgWidget](nameH), 1, 1, 5)
  gtk_box_pack_start(headerRow, cast[PgWidget](cpuH), 0, 0, 5)
  gtk_box_pack_start(headerRow, cast[PgWidget](memH), 0, 0, 5)
  gtk_box_pack_start(headerRow, cast[PgWidget](statusH), 0, 0, 5)
  gtk_box_pack_start(processBox, cast[PgWidget](headerRow), 0, 0, 2)
  
  # Правая панель - кольца нагрузки
  let ringPanel = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10)
  gtk_box_pack_start(taskContent, cast[PgWidget](ringPanel), 0, 0, 5)
  
  let ringLabel = gtk_label_new("СИСТЕМНАЯ НАГРУЗКА")
  gtk_label_set_markup(ringLabel, "<b>СИСТЕМНАЯ НАГРУЗКА</b>")
  gtk_box_pack_start(ringPanel, cast[PgWidget](ringLabel), 0, 0, 5)
  
  # CPU кольцо
  let cpuRingBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2)
  gtk_box_pack_start(ringPanel, cast[PgWidget](cpuRingBox), 1, 1, 5)
  
  let cpuCanvas = gtk_drawing_area_new()
  result.cpuCanvas = cpuCanvas
  gtk_widget_set_size_request(cast[PgWidget](cpuCanvas), 130, 130)
  g_signal_connect_after(cast[PgWidget](cpuCanvas), "draw", cast[pointer](onDrawRing), cast[pointer](result))
  gtk_box_pack_start(cpuRingBox, cast[PgWidget](cpuCanvas), 0, 0, 5)
  
  let cpuLabel = gtk_label_new("CPU: 0%")
  result.cpuLabel = cpuLabel
  gtk_box_pack_start(cpuRingBox, cast[PgWidget](cpuLabel), 0, 0, 2)
  
  # RAM кольцо
  let ramRingBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2)
  gtk_box_pack_start(ringPanel, cast[PgWidget](ramRingBox), 1, 1, 5)
  
  let ramCanvas = gtk_drawing_area_new()
  result.ramCanvas = ramCanvas
  gtk_widget_set_size_request(cast[PgWidget](ramCanvas), 130, 130)
  g_signal_connect_after(cast[PgWidget](ramCanvas), "draw", cast[pointer](onDrawRing), cast[pointer](result))
  gtk_box_pack_start(ramRingBox, cast[PgWidget](ramCanvas), 0, 0, 5)
  
  let ramLabel = gtk_label_new("RAM: 0%")
  result.ramLabel = ramLabel
  gtk_box_pack_start(ramRingBox, cast[PgWidget](ramLabel), 0, 0, 2)
  
  let taskTabLabel = gtk_label_new("⚙️ Процессы")
  gtk_notebook_append_page(notebook, cast[PgWidget](taskBox), cast[PgWidget](taskTabLabel))
  
  # === Вкладка Очистка ===
  let cleanBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10)
  gtk_widget_set_margin_start(cast[PgWidget](cleanBox), 10)
  gtk_widget_set_margin_end(cast[PgWidget](cleanBox), 10)
  gtk_widget_set_margin_top(cast[PgWidget](cleanBox), 10)
  gtk_widget_set_margin_bottom(cast[PgWidget](cleanBox), 10)
  
  let cleanTitle = gtk_label_new("🧹 ОЧИСТИТЕЛЬ СИСТЕМЫ")
  gtk_label_set_markup(cleanTitle, "<b><big>🧹 ОЧИСТИТЕЛЬ СИСТЕМЫ</big></b>")
  gtk_box_pack_start(cleanBox, cast[PgWidget](cleanTitle), 0, 0, 5)
  
  let cleanItems = gtk_box_new(GTK_ORIENTATION_VERTICAL, 5)
  gtk_box_pack_start(cleanBox, cast[PgWidget](cleanItems), 0, 0, 5)
  
  let check1 = gtk_button_new_with_label("🌐 Кэш браузеров")
  gtk_box_pack_start(cleanItems, cast[PgWidget](check1), 0, 0, 2)
  
  let check2 = gtk_button_new_with_label("📁 Временные файлы /tmp")
  gtk_box_pack_start(cleanItems, cast[PgWidget](check2), 0, 0, 2)
  
  let check3 = gtk_button_new_with_label("🗑️ Корзина")
  gtk_box_pack_start(cleanItems, cast[PgWidget](check3), 0, 0, 2)
  
  let cleanBtns = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5)
  gtk_box_pack_start(cleanBox, cast[PgWidget](cleanBtns), 0, 0, 5)
  
  let scanBtn = gtk_button_new_with_label("🔍 Найти мусор")
  gtk_box_pack_start(cleanBtns, cast[PgWidget](scanBtn), 0, 0, 5)
  
  let deleteBtn = gtk_button_new_with_label("🗑️ Удалить выбранное")
  gtk_box_pack_start(cleanBtns, cast[PgWidget](deleteBtn), 0, 0, 5)
  
  let cleanTabLabel = gtk_label_new("🧹 Очистка")
  gtk_notebook_append_page(notebook, cast[PgWidget](cleanBox), cast[PgWidget](cleanTabLabel))
  
  # === Вкладка О программе ===
  let aboutBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10)
  gtk_widget_set_margin_start(cast[PgWidget](aboutBox), 20)
  gtk_widget_set_margin_end(cast[PgWidget](aboutBox), 20)
  gtk_widget_set_margin_top(cast[PgWidget](aboutBox), 20)
  gtk_widget_set_margin_bottom(cast[PgWidget](aboutBox), 20)
  
  let aboutTitle = gtk_label_new("MSI CENTER ULTIMATE v2.0")
  gtk_label_set_markup(aboutTitle, "<b><span size=\"x-large\">MSI CENTER ULTIMATE v2.0</span></b>")
  gtk_box_pack_start(aboutBox, cast[PgWidget](aboutTitle), 0, 0, 5)
  
  let aboutDesc = gtk_label_new("Всё в одном: RGB + Кулеры + Диспетчер + Очиститель")
  gtk_box_pack_start(aboutBox, cast[PgWidget](aboutDesc), 0, 0, 5)
  
  let aboutFeatures = gtk_label_new("""
Возможности:
  🎨 RGB управление клавиатурой
  🌀 Управление кулерами
  ⚙️ Диспетчер задач с кольцами нагрузки
  🧹 Очиститель системы
  🔧 Работает с правами ROOT
""")
  gtk_box_pack_start(aboutBox, cast[PgWidget](aboutFeatures), 0, 0, 5)
  
  let aboutTabLabel = gtk_label_new("ℹ️ О программе")
  gtk_notebook_append_page(notebook, cast[PgWidget](aboutBox), cast[PgWidget](aboutTabLabel))
  
  # Первое обновление
  updateStats(result)
  for p in result.processes[0..<min(15, result.processes.len)]:
    let row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5)
    let pidLabel = gtk_label_new(cstring($p.pid))
    let nameLabel = gtk_label_new(cstring(p.name))
    let cpuLabel = gtk_label_new(cstring(formatFloat(p.cpuPercent, ffDefault, 1) & "%"))
    let memLabel = gtk_label_new(cstring($p.memory & " МБ"))
    let statusStr = case p.status
      of 'R': "▶️"
      of 'S': "💤"
      of 'D': "⏳"
      of 'Z': "🧟"
      of 'T': "⏸️"
      else: "  "
    let statusLabel = gtk_label_new(cstring(statusStr))
    
    gtk_box_pack_start(row, cast[PgWidget](pidLabel), 0, 0, 2)
    gtk_box_pack_start(row, cast[PgWidget](nameLabel), 1, 1, 2)
    gtk_box_pack_start(row, cast[PgWidget](cpuLabel), 0, 0, 2)
    gtk_box_pack_start(row, cast[PgWidget](memLabel), 0, 0, 2)
    gtk_box_pack_start(row, cast[PgWidget](statusLabel), 0, 0, 2)
    gtk_box_pack_start(processBox, cast[PgWidget](row), 0, 0, 2)
  
  gtk_widget_show_all(cast[PgWidget](window))
  gtk_main()

# ============== Точка входа ==============
proc main() =
  if geteuid() != 0:
    echo "⚠️ Требуются права root!"
    echo "   sudo ./msi_center"
    quit(1)
  
  var argc: int = 0
  var argv: cstring = nil
  gtk_init(addr(argc), addr(argv))
  discard createGUI()

when isMainModule:
  main()
