<p align="center">
  <img src="https://img.shields.io/badge/Plasma-6.6-blue?style=for-the-badge&logo=kde&logoColor=white" alt="Plasma 6.6">
  <img src="https://img.shields.io/badge/Qt-6-green?style=for-the-badge&logo=qt&logoColor=white" alt="Qt6">
  <img src="https://img.shields.io/badge/Platform-Linux-yellow?style=for-the-badge&logo=linux&logoColor=white" alt="Linux">
  <img src="https://img.shields.io/badge/License-GPL--3.0-purple?style=for-the-badge" alt="GPL-3.0">
</p>

<h1 align="center">🐳 OpsDash</h1>

<p align="center">
  <strong>A KDE Plasma 6 panel widget for monitoring active Docker containers in real-time.</strong>
</p>

<p align="center">
  Displays a live container count in your top panel with a popup that lists all running containers and lets you open their logs in Konsole with a single click.
</p>

---

## ✨ Features

- **Live container count** displayed directly in the Plasma panel next to a server icon
- **Dynamic container list** — popup shows all currently running containers, refreshed automatically
- **One-click logs** — click the terminal icon next to any container to open `docker logs --tail 50 -f` in Konsole
- **Green status indicator** — visual "Local Engine: Running" status with live container count
- **Configurable refresh interval** — change how often the widget polls Docker (default: 10 seconds)
- **Right-click Configure** — standard Plasma configuration dialog for all settings
- **Wayland compatible** — works correctly on Plasma 6 Wayland sessions
- **Zero dependencies beyond Docker** — uses only Plasma 6 built-in QML components

## 📸 Preview

```
┌─────────────────────────────────────────────┐
│  Panel:   [🐳 whale]  2                    │
├─────────────────────────────────────────────┤
│                                             │
│  OpsDash Control Center                     │
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │ ✅ Local Engine: Running   Containers: 2│ │
│  └───────────────────────────────────────┘  │
│                                             │
│  ─────────────────────────────────────────  │
│                                             │
│  Running Containers                         │
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │ ⚙ test-node                    [🐳]  │  │
│  └───────────────────────────────────────┘  │
│  ┌───────────────────────────────────────┐  │
│  │ ⚙ sentinel-agent               [🐳]  │  │
│  └───────────────────────────────────────┘  │
│                                             │
└─────────────────────────────────────────────┘
```

## 📋 Requirements

| Requirement | Version |
|---|---|
| KDE Plasma | **6.0+** (tested on 6.6.5) |
| Qt | **6.x** |
| Docker | Any version with `docker ps` CLI |
| Konsole | For the "Open Logs" feature |
| Linux | Any distro running Plasma 6 |

Tested on:
- **EndeavourOS (Arch Linux)** — Plasma 6.6.5, Wayland
- Should work on any Plasma 6 distribution (KDE Neon, Fedora Kinoite, openSUSE Tumbleweed, NixOS, etc.)

## 🚀 Installation

### Option 1: Manual Install (Recommended)

```bash
# Clone the repository
git clone https://github.com/harunkrl/opsdash-plasmoid.git

# Copy to Plasma's local plasmoid directory
cp -r opsdash-plasmoid ~/.local/share/plasma/plasmoids/com.ops.dash

# Rebuild Plasma's service cache
kbuildsycoca6

# Restart Plasma shell
# On Wayland:
systemctl --user restart plasma-plasmashell.service
# On X11:
# qdbus org.kde.Plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript 'Engine.restart()'
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

That's it — the container count should appear immediately.

## ⚙️ Configuration

Right-click the widget in the panel → **Configure OpsDash…**

| Setting | Type | Default | Description |
|---|---|---|---|
| **Refresh Interval** | SpinBox | `10000` ms (10s) | How often to poll `docker ps` for updates. Minimum: 1000 ms |
| **Target Container Name** | TextField | `test-node` | *(Reserved for future use)* Default container for quick-log actions |

Changes take effect immediately — no restart required.

## 🛠️ How It Works

### Architecture

```
Timer (configurable interval)
  │
  ├─► docker ps -q | wc -l
  │     └─► Container count → Panel label + Status card + Tooltip
  │
  └─► docker ps --format '{{.Names}}'
        └─► Container names → ListView in popup
              └─► Click [🖥️] → bash -c "konsole -e bash -c 'docker logs ...'"
```

### Technical Stack

| Component | Technology |
|---|---|
| Root element | `PlasmoidItem` (Plasma 6 applet) |
| Command execution | `Plasma5Support.DataSource` (engine: `"executable"`) |
| UI framework | `Kirigami` + `PlasmaComponents3` + `PlasmaExtras` |
| Configuration | KConfig XML + `org.kde.plasma.configuration` |
| Icon rendering | `Kirigami.Icon` with freedesktop standard icon names |

### File Structure

```
com.ops.dash/
├── metadata.json                      # Plasma 6 package metadata
└── contents/
    ├── config/
    │   ├── main.xml                   # KConfig schema (settings definitions)
    │   └── config.qml                 # Config tab registration
    └── ui/
        ├── main.qml                   # Main widget (panel view + popup)
        └── config/
            └── ConfigGeneral.qml      # Settings dialog UI
```

## 🔧 Troubleshooting

### Widget shows "Unsupported widget" when adding

Make sure you have Plasma **6.0 or newer**. This widget does NOT work on Plasma 5.

```bash
plasmashell --version
```

### Container count stays at 0

Ensure your user can run Docker commands without sudo:

```bash
docker ps -q | wc -l
```

If this fails, add your user to the `docker` group:

```bash
sudo usermod -aG docker $USER
# Log out and back in for changes to take effect
```

### Widget doesn't appear after installation

```bash
# Rebuild the service cache
kbuildsycoca6 --noincremental

# Restart Plasma
systemctl --user restart plasma-plasmashell.service
```

### Konsole opens but is blank

This was a known issue with nested command quoting under Wayland. It is fixed in the current version. If you experience it, make sure you have the latest `main.qml` from this repository.

### Changes not reflected after editing files

Always restart Plasma after modifying widget files:

```bash
systemctl --user restart plasma-plasmashell.service
```

## 🗑️ Uninstallation

```bash
# Remove the widget
rm -rf ~/.local/share/plasma/plasmoids/com.ops.dash

# Rebuild cache and restart
kbuildsycoca6 && systemctl --user restart plasma-plasmashell.service
```

## 🤝 Contributing

Contributions are welcome! To contribute:

1. Fork this repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit your changes: `git commit -m "Add my feature"`
4. Push to the branch: `git push origin feature/my-feature`
5. Open a Pull Request

### Development Setup

```bash
# Clone directly into the plasmoids directory for live editing
git clone https://github.com/harunkrl/opsdash-plasmoid.git \
  ~/.local/share/plasma/plasmoids/com.ops.dash

# Test with plasmoidviewer (shows QML errors in terminal)
plasmoidviewer -a ~/.local/share/plasma/plasmoids/com.ops.dash

# After each edit, restart Plasma
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
