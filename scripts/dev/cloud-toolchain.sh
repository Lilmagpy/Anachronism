#!/bin/bash
# Rebuilds the cloud session's graphics toolchain after a container restart (D-293):
# the Godot 4.5.1 binary, the shared render queue, and the Rome Reborn reference still.
# Everything lands under /tmp/claude-0, which a restart wipes. Idempotent; takes a minute.
set -e
T=/tmp/claude-0
mkdir -p $T/dl $T/ref
if [ ! -x $T/godot ]; then
  curl -sSL -o $T/dl/godot.zip https://github.com/godotengine/godot/releases/download/4.5.1-stable/Godot_v4.5.1-stable_linux.x86_64.zip
  (cd $T/dl && unzip -oq godot.zip && mv Godot_v4.5.1-stable_linux.x86_64 $T/godot && chmod +x $T/godot)
fi
cat > $T/render.sh <<'EOS'
#!/bin/bash
# Shared render queue: at most 3 Godot renders at once on this 4-core machine.
# Usage (from a checkout's client folder): /tmp/claude-0/render.sh --path . -- <game args> --screenshot=/tmp/claude-0/x.png
export UV_PROJECT_ENVIRONMENT=/home/user/anachronism/.venv
while true; do
  for slot in 1 2 3; do
    exec 9>/tmp/claude-0/render.slot$slot
    if flock -n 9; then
      timeout 900 xvfb-run -a -s "-screen 0 1600x900x24" /tmp/claude-0/godot --rendering-driver vulkan "$@"
      status=$?; flock -u 9; exit $status
    fi
  done
  sleep 5
done
EOS
chmod +x $T/render.sh
if [ ! -s $T/ref/rr_livescience.jpg ]; then
  url=$(curl -sL "https://www.livescience.com/archaeology/romans/soar-over-ancient-romes-temples-brothels-and-baths-in-epic-new-3d-reconstruction" | grep -o 'property="og:image" content="[^"]*"' | head -1 | sed 's/.*content="//;s/"$//')
  [ -n "$url" ] && curl -sL -o $T/ref/rr_livescience.jpg "$url" || true
fi
$T/godot --version
