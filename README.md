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
  Per-container actions • Search & sort • Remote Hosts • Wayland compatible
</p>

---

## ✨ Features

### Panel

- **Live container count** — shows `X/Y` (running/total) with Docker whale icon
- **Status-aware colors** — green (all running), orange (partial), red (none running)
- **Warning badge** — ⚠️ icon appears when some containers are stopped
- **Rich tooltip** — hover to see aggregate stats: `3/5 up · CPU 12.4% · Mem 1.2 GiB`

### Popup

- **Two-Tab Layout** — Switch seamlessly between **Containers** and **Images**.
- **Images Tab** — View all Docker images with tags, IDs, and sizes. Quick delete button included.
- **Status card** — Docker engine status, aggregate CPU/memory bars, image count.
- **Global Actions** — System Prune (remove unused data) and Restart All containers.
- **Docker Compose Grouping** — Containers are neatly grouped by their Compose projects.
- **Compose Batch Actions** — Start, Stop, or Restart all containers within a Compose project with a single click.
- **Container cards** with:
  - Status dot + Docker icon + container name + uptime
  - CPU usage bar + sparkline history chart
  - Memory usage (used/total) + Network I/O + Port mappings
  - **Inline Action Buttons**: ▶ Start, ⏹ Stop, 🔄 Restart, 💻 Exec Shell (Konsole), 📟 Inline Logs, 🗑 Remove
  - **Expandable Logs** — View the last 20 lines of container logs right inside the widget, automatically refreshed!
- **State differentiation** — running (green), stopped (red), paused (orange), restarting (yellow)
- **Search & Sort** — filter containers by name in real-time. Sort by Name, State, CPU, or Memory.

### Configuration (Tabbed KCM Layout)

- **General**:
  - **Docker Host**: Manage a remote VPS or server seamlessly via `ssh://user@ip`. Leave empty for localhost.
  - Refresh interval (1–60 seconds).
- **Behavior**:
  - Desktop notifications for state changes (start/stop/remove).
  - **Resource Usage Alerts**: Get notified via desktop notifications when a container exceeds customized CPU or Memory thresholds!
  - Show all containers or running only.
- **Appearance**:
  - Panel icon size, font size, custom color overrides.
  - Popup dimensions (width/height), font colors, and card border thicknesses.

---

## 📸 Preview

<p align="center">
  <img src="preview.png" alt="OpsDash Popup Preview" width="500">
</p>

<details>
<summary>📐 ASCII Layout Diagram</summary>

```
┌─ Panel ──────────────────────────────────────┐
│  [🐳]  3/5  ⚠️                               │
└───────────────────────────────────────────────┘

┌─ Popup ──────────────────────────────────────┐
│  OpsDash Control Center                       │
│  [ Containers ] [ Images ]                    │
│                                               │
│  ┌─ Status ─────────────────────────────────┐ │
│  │ ✅ Engine: Running   3/5 up  │ 12 images │ │
│  │ CPU [████░░░░░░] 12.4%                  │ │
│  │ Mem [██████░░░░] 1.2 GiB                │ │
│  │ [System Prune]  [Restart All]           │ │
│  └──────────────────────────────────────────┘ │
│                                               │
│  📁 my-compose-project  [▶] [⏹] [🔄]         │
│  ┌─ nginx-proxy ──────────────────────────┐  │
│  │ 🟢 🐳 nginx-proxy  Up 3d 2h           │  │
│  │    [▶][⏹][🔄][💻][📟][🗑]               │  │
│  │ CPU [███░░░░] 4.2%  ╱╲╱╲  Mem: 128 MiB │  │
│  │ Net: ↑12 MB ↓45 MB  Ports: 80, 443    │  │
│  │ -------------------------------------- │  │
│  │ > 2026-05-30 nginx start worker        │  │
│  └────────────────────────────────────────┘  │
└───────────────────────────────────────────────┘
```

</details>

## 📋 Requirements

| Requirement | Version |
|---|---|
| KDE Plasma | **6.0+** (tested on 6.6.5) |
| Qt | **6.x** |
| Docker | Any version with `docker ps` / `docker stats` CLI |
| Konsole | For the "Exec Shell" feature |
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

### Add to Panel

1. **Right-click** on your Plasma panel
2. Select **"Add Widgets…"**
3. Search for **"OpsDash"**
4. **Drag** it to your panel

## ⚙️ Configuration

Right-click the widget → **Configure OpsDash…**

The settings are properly split into 3 intuitive tabs: **General**, **Behavior**, and **Appearance**. Scroll bars are fully supported!

## 🛠️ How It Works

### Architecture

```
Timer (configurable interval)
  │
  ├─► docker -H <host> ps -a --format '{{.Names}}|{{.State}}|{{.Status}}|{{.Ports}}|{{.Labels}}'
  │     └─► Container list with Compose projects, states, uptime
  │
  ├─► docker -H <host> stats --no-stream --format '{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}|...'
  │     └─► Resource usage, thresholds evaluation for alerts
  │
  ├─► echo "$(docker -H <host> images -q | wc -l)|..."
  │     └─► System overview
  │
  └─► docker -H <host> images --format '{{.ID}}|{{.Repository}}|{{.Tag}}|{{.Size}}'
        └─► Populates the Images Tab
```

### Technical Stack

| Component | Technology |
|---|---|
| Root element | `PlasmoidItem` (Plasma 6 applet) |
| Command execution | `Plasma5Support.DataSource` (engine: `"executable"`) |
| UI framework | `Kirigami` + `PlasmaComponents3` + `QQC2.ScrollView` |
| Configuration | Multi-tab UI via `config.qml` + `main.xml` |

## 🔧 Troubleshooting

### Widget shows "Unsupported widget"

This widget requires Plasma **6.0+**. It does NOT work on Plasma 5.

### Container count stays at 0

Ensure your user can run Docker without sudo: `docker ps -q | wc -l`.
If it fails, add your user to the `docker` group: `sudo usermod -aG docker $USER`.

### Changes not reflected after editing files

Always restart Plasma after modifying widget files:
`systemctl --user restart plasma-plasmashell.service`

## 🗺️ Roadmap

- [x] Docker Compose project grouping
- [x] Log preview (inline logs inside popup)
- [x] Multiple Docker host support (remote SSH)
- [ ] Custom color themes / presets
- [ ] Health check status (healthy/unhealthy)

## 🤝 Contributing

Contributions are welcome! Fork, branch, commit, and open a PR.

## 📝 License

This project is licensed under the **GNU General Public License v3.0** — see the [LICENSE](LICENSE) file for details.
