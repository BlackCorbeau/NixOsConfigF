#!/usr/bin/env python3
"""Nix-side fixes for the pinned Lucid checkout.

The shell is rsynced from a fixed upstream revision, so these patches are
applied after every activation.  Each patch is idempotent and refuses to guess:
if the expected upstream text is gone, activation fails instead of silently
losing the fix.
"""

from pathlib import Path
import sys

target = Path(sys.argv[1])
changed = []


def replace(path: str, old: str, new: str, marker: str) -> None:
    file = target / path
    text = file.read_text(encoding="utf-8")
    if marker in text:
        return
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{file}: expected one match for {marker!r}, found {count}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")
    changed.append(str(file))


# Audio.qml: pactl's monitor sees the pactl processes it spawns as new clients.
# Every refresh would then restart the settle timer and spawn another pactl,
# keeping Quickshell busy forever.  Ignore those client events and force a
# stable locale so the parsing does not depend on the session language.
replace(
    "Audio.qml",
    '''        running: true
        command: ["pactl", "subscribe"]
        // pipewire-pulse going down takes the subscription with it; come back
        // on a delay so a machine without pactl does not spin
        onExited: respawn.restart()''',
    '''        running: true
        command: ["pactl", "subscribe"]
        // Nix: pactl itself is a PipeWire client; keep its output stable
        environment: ({
            "LC_ALL": "C"
        })
        // pipewire-pulse going down takes the subscription with it; come back
        // on a delay so a machine without pactl does not spin
        onExited: respawn.restart()''',
    "// Nix: pactl itself is a PipeWire client",
)

replace(
    "Audio.qml",
    '''                if (line.indexOf("'change' on sink #") >= 0 || line.indexOf("'change' on source #") >= 0)
                    return ;

                settle.restart();''',
    '''                if (line.indexOf("'change' on sink #") >= 0 || line.indexOf("'change' on source #") >= 0)
                    return ;
                // Nix: ignore our own pactl client events, or every refresh
                // spawns more pactl and the shell never settles
                if (line.indexOf("on client") >= 0)
                    return ;

                settle.restart();''',
    "// Nix: ignore our own pactl client events",
)

# Workspaces.qml: the preview tiles live in the expanded overview, but the
# window model and its ScreencopyViews were kept alive after the overview had
# been opened once.  A workspace switch then rebuilt/re-captured them during the
# compositor's slide.  Only touch the model while the overview is visible, and
# drop the capture source once the close animation is over.
replace(
    "lucidbar/Workspaces.qml",
    "    onWindowListChanged: root.syncWindowModel()\n",
    "    // Nix: previews are only needed while the overview is open\n"
    "    onWindowListChanged: {\n"
    "        if (root.expanded || root.reveal > 0.001)\n"
    "            root.syncWindowModel();\n"
    "    }\n",
    "// Nix: previews are only needed while the overview is open",
)

replace(
    "lucidbar/Workspaces.qml",
    '''            root.everExpanded = true;
            Hyprland.refreshToplevels();''',
    '''            root.everExpanded = true;
            Hyprland.refreshToplevels();
            root.syncWindowModel();''',
    '''root.everExpanded = true;
            Hyprland.refreshToplevels();
            root.syncWindowModel();''',
)

replace(
    "lucidbar/Workspaces.qml",
    "captureSource: root.everExpanded && thumb.toplevel ? thumb.toplevel.wayland : null",
    "captureSource: (root.expanded || root.reveal > 0.001) && thumb.toplevel ? thumb.toplevel.wayland : null",
    "captureSource: (root.expanded || root.reveal > 0.001)",
)

# Dock.qml: a workspace switch changes the active workspace, not the windows'
# geometry or workspace id.  Refreshing every toplevel here made the dock and
# its running-app model churn in the middle of the workspace animation.
replace(
    "luciddocks/Dock.qml",
    '''            case "changefloatingmode":
            case "fullscreen":
            case "workspacev2":
                if (Prefs.dockDynamicHide)
                    toplevelRefresh.restart();

                break;''',
    '''            case "changefloatingmode":
            case "fullscreen":
                if (Prefs.dockDynamicHide)
                    toplevelRefresh.restart();

                break;
            // Nix: a workspace switch does not change the windows' geometry or
            // workspace; refreshing all toplevels here just churns the dock
''',
    "// Nix: a workspace switch does not change the windows' geometry",
)

if changed:
    print("Lucid QML fixes applied:")
    for file in changed:
        print(f"  {file}")
