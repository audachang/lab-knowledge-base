# Fix: FSLeyes "Unable to initialise OpenGL" on NoMachine/NX Sessions

**Applies to:** Ubuntu 24.04, FSLeyes 0.31.2, FSL Python 3.7 conda env, NoMachine NX remote desktop, NVIDIA GPU
**Fixed on:** braina-aclexp (89.167.10.76) — 2026-03-23

---

## Symptom

Running `fsleyes` fails immediately:

```
ERROR  main.py: initialise - Unable to initialise OpenGL!
wx._core.wxAssertionError: C++ assertion "m_widget" failed
  at gtk/window.cpp in DoSetSize(): invalid window
```

## Root Cause

NoMachine NX virtual displays (e.g. `:1002`) advertise the GLX extension but expose **no GLX visuals** — `glXChooseVisual` returns `None`. wxGLCanvas cannot create its GTK widget without a valid GL visual, so FSLeyes crashes at startup.

Secondary issue: the FSL conda environment ships an old `libstdc++.so.6` (GLIBCXX_3.4.26) which is too old for system Mesa libraries (which need GLIBCXX_3.4.29+), preventing Mesa software rendering from loading as a fallback.

## Fix

All steps require `sudo`.

### 1. Add user to GPU device groups

```bash
sudo usermod -aG video,render <username>
```

Takes effect after next login. Grants access to `/dev/dri/card1` and `/dev/dri/renderD128`.

### 2. Install VirtualGL

VirtualGL is not in Ubuntu repos; download from GitHub releases:

```bash
wget -O /tmp/virtualgl.deb \
  "https://github.com/VirtualGL/virtualgl/releases/download/3.1.1/virtualgl_3.1.1_amd64.deb"
sudo dpkg -i /tmp/virtualgl.deb
```

### 3. Enable VirtualGL support in NoMachine config

```bash
sudo sed -i 's/#EnableVirtualGLSupport 0/EnableVirtualGLSupport 1/' /usr/NX/etc/node.cfg
```

### 4. Fix FSL conda env libstdc++ (too old for system Mesa)

```bash
# Find the system version filename first
ls /lib/x86_64-linux-gnu/libstdc++.so.6.0.*
# e.g. libstdc++.so.6.0.33 on Ubuntu 24.04

sudo cp /usr/local/fsl/fslpython/envs/fslpython/lib/libstdc++.so.6 \
    /usr/local/fsl/fslpython/envs/fslpython/lib/libstdc++.so.6.bak

sudo ln -sf /lib/x86_64-linux-gnu/libstdc++.so.6.0.33 \
    /usr/local/fsl/fslpython/envs/fslpython/lib/libstdc++.so.6
```

### 5. Create fsleyes wrapper script

```bash
mkdir -p ~/bin
cat > ~/bin/fsleyes << 'EOF'
#!/bin/bash
exec vglrun -d :0 /usr/local/fsl/bin/fsleyes "$@"
EOF
chmod +x ~/bin/fsleyes
```

`~/bin` is prepended to PATH in `~/.tcshrc` on these servers, so this wrapper takes precedence automatically.

### 6. Verify

```bash
fsleyes &
# Wait ~8 seconds — should show the GUI without any OpenGL errors
```

---

## How It Works

**VirtualGL** (`vglrun`) intercepts OpenGL calls from FSLeyes, renders them on the physical NVIDIA GPU (display `:0`), and streams the rendered frames back to the NX virtual display. This transparently bridges the gap between the app (which needs real GL) and the NX session (which has no GL visuals).

## Diagnosing the Same Issue on a New Server

Run this to confirm the NX display has no GLX visuals:

```bash
python3 - << 'EOF'
import ctypes
libX11 = ctypes.CDLL('libX11.so.6')
libX11.XOpenDisplay.restype = ctypes.c_void_p
libGLX = ctypes.CDLL('libGLX.so.0')
libGLX.glXChooseVisual.restype = ctypes.c_void_p
libGLX.glXChooseVisual.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_int)]
dpy = libX11.XOpenDisplay(None)
attrs = (ctypes.c_int * 3)(4, 5, 0)  # GLX_RGBA, GLX_DOUBLEBUFFER
vis = libGLX.glXChooseVisual(dpy, 0, attrs)
print("GLX visual:", vis)  # None = this fix is needed
EOF
```
