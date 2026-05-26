<p align="center">
  <img src="https://img.shields.io/badge/Plasma-6.6-blue?style=for-the-badge&logo=kde&logoColor=white" alt="Plasma 6.6">
  <img src="https://img.shields.io/badge/Qt-6-green?style=for-the-badge&logo=qt&logoColor=white" alt="Qt6">
  <img src="https://img.shields.io/badge/Docker-Monitored-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker">
  <img src="https://img.shields.io/badge/Platform-Linux-yellow?style=for-the-badge&logo=linux&logoColor=white" alt="Linux">
  <img src="https://img.shields.io/badge/License-GPL--3.0-purple?style=for-the-badge" alt="GPL-3.0">
</p>

<h1 align="center">🐳 OpsDash</h1>

<p align="center">
  <strong>KDE Plasma 6 panel widget for real-time Docker container monitoring.</strong>
</p>

<p align="center">
  Live container count in the panel • Rich popup with CPU, memory, network & uptime stats<br>
  Per-container actions • Search & sort • Configurable appearance • Wayland compatible
</p>

---

## ✨ Features

### Panel
- **Live container count** — shows `X/Y` (running/total) with Docker whale icon
- **Status-aware colors** — green (all running), orange (partial), red (none running)
- **Warning badge** — ⚠️ icon appears when some containers are stopped
- **Rich tooltip** — hover to see aggregate stats: `3/5 up · CPU 12.4% · Mem 1.2 GiB`

### Popup
- **Status card** — Docker engine status, aggregate CPU/memory bars, image count, bulk actions (Start/Stop All)
- **Container cards** with:
  - Status dot + Docker icon + container name + uptime
  - CPU usage bar + sparkline history chart
  - Memory usage (used/total)
  - Network I/O
  - Port mappings
  - **Inline action buttons**: ▶ Start, ⏹ Stop, 🔄 Restart, 📟 Logs, 🗑 Remove
- **State differentiation** — running (green), stopped (red), paused (orange), restarting (yellow)
- **Search** — filter containers by name in real-time
- **Sort** — by Name, State, CPU, or Memory (green highlight on active sort)
- **Show all / running only** toggle

### Configuration
- Refresh interval (1–60 seconds)
- Show all containers or running only
- Enable/disable notifications (container start/stop alerts via `notify-send`)
- Panel appearance: icon size, font size, font color
- Popup appearance: width, height, card font size, card font color
- Border thickness (0–5 px) — card and status card outlines
- State-based outline colors (green/orange/red depending on container health)

### Notifications
- Container started → desktop notification
- Container stopped → desktop notification (with warning icon)
- Container removed → desktop notification
- Toggleable from config

---

## 📸 Preview

```
┌─ Panel ──────────────────────────────────────┐
│  [🐳]  3/5  ⚠️                               │
└───────────────────────────────────────────────┘

┌─ Popup ──────────────────────────────────────┐
│  OpsDash Control Center                       │
│                                               │
│  ┌─ Status ─────────────────────────────────┐ │
│  │ ✅ Engine: Running   3/5 up  │ 12 images │ │
│  │ CPU [████░░░░░░] 12.4%                  │ │
│  │ Mem [██████░░░░] 1.2 GiB                │ │
│  │ [Start All]  [Stop All]                 │ │
│  └──────────────────────────────────────────┘ │
│                                               │
│  🔍 [Search containers...        ]           │
│  [Name] [State] [CPU] [Mem]                  │
│                                               │
│  ┌─ nginx-proxy ──────────────────────────┐  │
│  │ 🟢 🐳 nginx-proxy  Up 3d 2h           │  │
│  │    [▶][⏹][🔄][📟][🗑]                  │  │
│  │ CPU [███░░░] 4.2%  ╱╲╱╲  Mem: 128 MiB │  │
│  │ Net: ↑12 MB ↓45 MB  Ports: 80, 443    │  │
│  └────────────────────────────────────────┘  │
│                                               │
│  ┌─ postgres-db ──────────────────────────┐  │
│  │ 🔴 🐳 postgres-db  Exited (0) 2h ago  │  │
│  │    [▶][🗑]                              │  │
│  └────────────────────────────────────────┘  │
└───────────────────────────────────────────────┘
```

## 📋 Requirements

| Requirement | Version |
|---|---|
| KDE Plasma | **6.0+** (tested on 6.6.5) |
| Qt | **6.x** |
| Docker | Any version with `docker ps` / `docker stats` CLI |
| Konsole | For the "Open Logs" feature |
| `notify-send` | For desktop notifications (optional) |
| Linux | Any distro running Plasma 6 |

Tested on:
- **EndeavourOS (Arch Linux)** — Plasma 6.6.5, Wayland
- Should work on KDE Neon, Fedora Kinoite, openSUSE Tumbleweed, NixOS, etc.

## 🚀 Installation

### Option 1: Manual Install

```bash
# Clone the repository
git clone https://github.com/harunkrl/opsdash-plasmoid.git

# Copy to Plasma's local plasmoid directory
cp -r opsdash-plasmoid ~/.local/share/plasma/plasmoids/com.ops.dash

# Rebuild Plasma's service cache
kbuildsycoca6

# Restart Plasma shell
systemctl --user restart plasma-plasmashell.service
```

### Option 2: One-Liner

```bash
git clone https://github.com/harunkrl/opsdash-plasmoid.git \
  ~/.local/share/plasma/plasmoids/com.ops.dash \
  && kbuildsycoca6 \
  && systemctl --user restart plasma-plasmashell.service
```

### Add to Panel

1. **Right-click** on your Plasma panel
2. Select **"Add Widgets…"**
3. Search for **"OpsDash"**
4. **Drag** it to your panel

Container count appears immediately.

## ⚙️ Configuration

Right-click the widget → **Configure OpsDash…**

### Docker Settings

| Setting | Type | Default | Description |
|---|---|---|---|
| **Refresh Interval** | SpinBox | `10000` ms | How often to poll Docker (1000–60000 ms) |
| **Target Container** | TextField | — | Reserved for future quick-log feature |

### Behavior

| Setting | Type | Default | Description |
|---|---|---|---|
| **Enable Notifications** | CheckBox | On | Desktop alerts when containers start/stop |
| **Show All Containers** | CheckBox | On | Show stopped containers too (not just running) |

### Panel Appearance

| Setting | Type | Default | Description |
|---|---|---|---|
| **Icon Size** | SpinBox | `22` px | Docker whale icon size in panel |
| **Font Size** | SpinBox | `12` px | Container count text size (`0` = theme default) |
| **Font Color** | TextField | auto | Override color (hex `#ff0000` or name `red`). Empty = auto mode |

### Popup Appearance

| Setting | Type | Default | Description |
|---|---|---|---|
| **Width** | SpinBox | `38` GU | Popup width in grid units |
| **Height** | SpinBox | `28` GU | Popup height in grid units |
| **Card Font Size** | SpinBox | `11` px | Container card text size (`0` = theme default) |
| **Card Font Color** | TextField | — | Override card text color. Empty = theme default |

### Borders

| Setting | Type | Default | Description |
|---|---|---|---|
| **Thickness** | SpinBox | `1` px | Card border thickness (`0` = no border, `1–5` = increasing) |

> **Note:** Border colors are state-based and automatically match container status (green/orange/red).

Changes take effect immediately — no restart required.

## 🛠️ How It Works

### Architecture

```
Timer (configurable interval)
  │
  ├─► docker ps -a --format '{{.Names}}|{{.State}}|{{.Status}}|{{.Ports}}'
  │     └─► Container list with states, uptime, ports
  │           └─► Panel count + Status card + Container cards + Notifications
  │
  ├─► docker stats --no-stream --format '{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}|...'
  │     └─► Per-container CPU, memory, network stats
  │           └─► Usage bars + Sparkline charts + Aggregate totals
  │
  └─► echo "$(docker images -q | wc -l)|$(docker ps -a -q | wc -l)"
        └─► System overview: image count, total containers

Actions:
  ▶ Start    → docker start <name>
  ⏹ Stop     → docker stop <name>
  🔄 Restart  → docker restart <name>
  📟 Logs    → konsole -e docker logs --tail 50 -f <name>
  🗑 Remove  → docker rm <name>
```

### Technical Stack

| Component | Technology |
|---|---|
| Root element | `PlasmoidItem` (Plasma 6 applet) |
| Command execution | `Plasma5Support.DataSource` (engine: `"executable"`) |
| UI framework | `Kirigami` + `PlasmaComponents3` + `PlasmaExtras` |
| Configuration | KConfig XML (`main.xml`) + `cfg_` property aliases |
| Icon rendering | `Kirigami.Icon` with bundled SVG + freedesktop icons |
| Notifications | `notify-send` via `Plasma5Support.DataSource` |
| History charts | Inline `Sparkline` component (QML Canvas) |
| Usage bars | Inline `UsageBar` component (QML Rectangle) |

### File Structure

```
com.ops.dash/
├── metadata.json                          # Plasma 6 package metadata
├── README.md                              # This file
├── .gitignore
└── contents/
    ├── config/
    │   ├── main.xml                       # KConfig schema (all settings)
    │   └── config.qml                     # Config tab registration
    └── ui/
        ├── main.qml                       # Main widget (panel + popup + data sources)
        ├── config/
        │   └── ConfigGeneral.qml          # Settings dialog UI
        └── icons/
            └── docker.svg                 # Bundled Docker whale logo
```

## 🔧 Troubleshooting

### Widget shows "Unsupported widget"

This widget requires Plasma **6.0+**. It does NOT work on Plasma 5.

```bash
plasmashell --version
```

### Container count stays at 0

Ensure your user can run Docker without sudo:

```bash
docker ps -q | wc -l
```

If it fails, add your user to the `docker` group:

```bash
sudo usermod -aG docker $USER
# Log out and back in
```

### Stats show 0% CPU / empty memory

`docker stats` requires running containers. Stopped containers will show no stats — this is expected.

### Widget doesn't appear after installation

```bash
kbuildsycoca6 --noincremental
systemctl --user restart plasma-plasmashell.service
```

### Changes not reflected after editing files

Always restart Plasma after modifying widget files:

```bash
systemctl --user restart plasma-plasmashell.service
```

### Debug with plasmoidviewer

```bash
plasmoidviewer -a ~/.local/share/plasma/plasmoids/com.ops.dash
```

This opens the widget in a standalone window and prints QML errors to the terminal.

### Known Plasma 6 QML Gotchas

If you're developing custom Plasma 6 widgets, watch out for these:

| Issue | Fix |
|---|---|
| `metadata.desktop` | Use `metadata.json` in Plasma 6 |
| `PlasmaCore.DataSource` | Use `Plasma5Support.DataSource` |
| `Item` as root | Use `PlasmoidItem` |
| `Plasmoid.toolTipSubText` | Set tooltip properties directly on `PlasmoidItem` |
| `font.bold` + `font: Theme.smallFont` | Can't mix — use `font.weight: Font.Bold` + `font.pixelSize` |
| `icon.name` on ToolButton | Not available — use `Kirigami.Icon` instead |
| `showHoverFeedback` on cards | Does not exist in Plasma 6 Kirigami |
| `QQC2.MenuItem` without namespace | Must use dot notation: `QQC2.MenuItem` |
| `rc={}` in JS | Returns `NaN` — initialize with `rc=0` |

## 🗑️ Uninstallation

```bash
rm -rf ~/.local/share/plasma/plasmoids/com.ops.dash
kbuildsycoca6 && systemctl --user restart plasma-plasmashell.service
```

## 🗺️ Roadmap

- [ ] Health check status (healthy/unhealthy)
- [ ] Docker Compose project grouping
- [ ] Log preview (last 5 lines in popup)
- [ ] Custom color themes / presets
- [ ] Multiple Docker host support (remote SSH)

## 🤝 Contributing

Contributions are welcome!

1. Fork this repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit your changes: `git commit -m "Add my feature"`
4. Push: `git push origin feature/my-feature`
5. Open a Pull Request

### Development Setup

```bash
git clone https://github.com/harunkrl/opsdash-plasmoid.git \
  ~/.local/share/plasma/plasmoids/com.ops.dash

# Live editing — after each change:
systemctl --user restart plasma-plasmashell.service
```

## 📝 License

This project is licensed under the **GNU General Public License v3.0** — see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This project is not affiliated with KDE, Docker, or any other organization. It is an independent community widget built for personal use.

---

<p align="center">
  Made with ❤️ for the KDE Plasma community
</p>
