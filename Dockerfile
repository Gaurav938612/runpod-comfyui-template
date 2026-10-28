# RunPod GPU Pod image: ComfyUI + JupyterLab
# Build for linux/amd64. Model weights remain on the attached network volume.
FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    COMFY_DIR=/opt/ComfyUI \
    VOLUME_DIR=/workspace \
    COMFYUI_PORT=8188 \
    JUPYTER_PORT=8888

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip git git-lfs curl ca-certificates \
    build-essential pkg-config ffmpeg libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN git clone --depth 1 https://github.com/Comfy-Org/ComfyUI.git "${COMFY_DIR}"

WORKDIR /opt/ComfyUI
RUN python3 -m pip install --upgrade pip setuptools wheel && \
    python3 -m pip install torch torchvision torchaudio \
      --index-url https://download.pytorch.org/whl/cu128 && \
    python3 -m pip install -r requirements.txt && \
    python3 -m pip install jupyterlab ipykernel

# Install the current pip/nightly ComfyUI-Manager package during image build.
RUN python3 -m pip install -U --pre comfyui-manager

COPY extra_model_paths.yaml /opt/ComfyUI/extra_model_paths.yaml
COPY start.sh /usr/local/bin/start-comfyui
RUN chmod +x /usr/local/bin/start-comfyui

RUN mkdir -p /workspace
EXPOSE 8188 8888
STOPSIGNAL SIGTERM
CMD ["/usr/local/bin/start-comfyui"]
