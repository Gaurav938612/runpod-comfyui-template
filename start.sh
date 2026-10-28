#!/usr/bin/env bash
set -Eeuo pipefail

COMFY_DIR="${COMFY_DIR:-/opt/ComfyUI}"
VOLUME_DIR="${VOLUME_DIR:-/workspace}"
COMFYUI_PORT="${COMFYUI_PORT:-8188}"
JUPYTER_PORT="${JUPYTER_PORT:-8888}"

# Refuse to start if RunPod did not mount the expected persistent network volume.
if ! mountpoint -q "$VOLUME_DIR"; then
  echo >&2 "FATAL: $VOLUME_DIR is not a mount point."
  echo >&2 "Attach your RunPod Network Volume at $VOLUME_DIR, then redeploy."
  exit 1
fi

# Seed ComfyUI-Manager configuration on every container start.
# Current ComfyUI (system user API) stores Manager config under user/__manager.
# This is in the container image filesystem, so the setting is applied automatically
# on each fresh Pod deployment without modifying the network volume.
MANAGER_CONFIG_DIR="$COMFY_DIR/user/__manager"
MANAGER_CONFIG="$MANAGER_CONFIG_DIR/config.ini"
mkdir -p "$MANAGER_CONFIG_DIR"
cat > "$MANAGER_CONFIG" <<'EOF'
[default]
security_level = weak
allow_git_url_install = true
allow_pip_install = true
allow_flagged_nodepack_install = true
EOF
echo "Wrote ComfyUI-Manager config: $MANAGER_CONFIG"

# Keep models, outputs, inputs, notebooks, and workflows on persistent storage.
mkdir -p \
  "$VOLUME_DIR/models/checkpoints" \
  "$VOLUME_DIR/models/loras" \
  "$VOLUME_DIR/models/vae" \
  "$VOLUME_DIR/models/text_encoders" \
  "$VOLUME_DIR/models/clip" \
  "$VOLUME_DIR/models/clip_vision" \
  "$VOLUME_DIR/models/diffusion_models" \
  "$VOLUME_DIR/models/unet" \
  "$VOLUME_DIR/models/controlnet" \
  "$VOLUME_DIR/models/upscale_models" \
  "$VOLUME_DIR/models/embeddings" \
  "$VOLUME_DIR/input" \
  "$VOLUME_DIR/output" \
  "$VOLUME_DIR/notebooks" \
  "$VOLUME_DIR/workflows"

if [[ -z "${JUPYTER_TOKEN:-}" ]]; then
  echo >&2 "FATAL: Set a strong JUPYTER_TOKEN environment variable in RunPod."
  exit 1
fi

# Start ComfyUI and write its logs to the container log stream.
cd "$COMFY_DIR"
python3 main.py \
  --listen 0.0.0.0 \
  --port "$COMFYUI_PORT" \
  --enable-manager \
  --extra-model-paths-config "$COMFY_DIR/extra_model_paths.yaml" \
  --input-directory "$VOLUME_DIR/input" \
  --output-directory "$VOLUME_DIR/output" \
  > >(sed -u 's/^/[ComfyUI] /') 2>&1 &
COMFY_PID=$!

# Start JupyterLab on persistent storage, with token authentication enabled.
jupyter lab \
  --ip=0.0.0.0 \
  --port="$JUPYTER_PORT" \
  --no-browser \
  --allow-root \
  --ServerApp.root_dir="$VOLUME_DIR" \
  --ServerApp.token="$JUPYTER_TOKEN" \
  --ServerApp.password='' \
  --ServerApp.allow_remote_access=True \
  --ServerApp.trust_xheaders=True \
  --ServerApp.allow_origin_pat='^https://[a-zA-Z0-9-]+-8888\.proxy\.runpod\.net$' \
  > >(sed -u 's/^/[JupyterLab] /') 2>&1 &
JUPYTER_PID=$!

cleanup() {
  echo "Stopping ComfyUI and JupyterLab..."
  kill "$COMFY_PID" "$JUPYTER_PID" 2>/dev/null || true
  wait "$COMFY_PID" "$JUPYTER_PID" 2>/dev/null || true
}
trap cleanup TERM INT

# Keep the container alive while both services run. If either exits, stop the other.
set +e
wait -n "$COMFY_PID" "$JUPYTER_PID"
status=$?
set -e
cleanup
exit "$status"
