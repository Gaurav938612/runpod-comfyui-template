# RunPod ComfyUI + JupyterLab template

This is a **Docker image source template**, not a prebuilt/published registry image. It installs ComfyUI, its Python requirements, JupyterLab, and ComfyUI-Manager during image build. It expects the RunPod Network Volume to be attached at `/workspace` and refuses to start if that mount is missing.

## Included
- ComfyUI on port `8188`
- JupyterLab on port `8888`, protected by `JUPYTER_TOKEN`
- ComfyUI-Manager installed in the image
- ComfyUI models discovered from `/workspace/models`
- Inputs and outputs stored at `/workspace/input` and `/workspace/output`
- Notebooks and workflows stored on the persistent volume

Model weights are intentionally **not** included in the Docker image. Put them on the network volume once; future Pods using that same volume can reuse them.

## Build and publish (Windows PowerShell)

Install and start Docker Desktop. From this folder:

```powershell
docker build --platform linux/amd64 -t YOUR_DOCKERHUB_USERNAME/comfyui-jupyter:latest .
docker login
docker push YOUR_DOCKERHUB_USERNAME/comfyui-jupyter:latest
```

Replace `YOUR_DOCKERHUB_USERNAME`. The first build downloads ComfyUI and Python packages, so it may take a while. Later builds can use Docker's build cache.

## RunPod Pod configuration

1. Create a **GPU Pod** using `YOUR_DOCKERHUB_USERNAME/comfyui-jupyter:latest`.
2. Attach your Network Volume at `/workspace`.
3. Expose HTTP ports `8188` and `8888`.
4. Set environment variable `JUPYTER_TOKEN` to a long, unique secret. Do not bake it into the image.
5. Deploy. No shell-based setup should be needed after startup.

Open ComfyUI using the RunPod Connect link for port `8188`. Open JupyterLab using the Connect link for port `8888`; authenticate using the value of `JUPYTER_TOKEN`.

## Network volume directory layout

```text
/workspace/
  models/
    checkpoints/
    loras/
    vae/
    text_encoders/
    clip/
    clip_vision/
    diffusion_models/
    unet/
    controlnet/
    upscale_models/
    embeddings/
  input/
  output/
  notebooks/
  workflows/
```

## Important notes

- The `mountpoint` guard intentionally exits if `/workspace` is not a mounted volume. Verify the volume mount path in your RunPod Pod settings.
- This image installs ComfyUI-Manager. It does **not** install every third-party custom node, because their dependencies can conflict or change. Add the exact nodes required by your workflow in the Dockerfile so they are installed at build time, not interactively after deployment.
- This template uses CUDA 12.8 PyTorch wheels. Validate against your selected GPU and any custom nodes before relying on it for paid workloads.
- Do not expose ComfyUI to untrusted users without adding appropriate access controls.


## ComfyUI-Manager
The Docker build runs `python3 -m pip install -U --pre comfyui-manager`, and the startup script launches ComfyUI with `--enable-manager`. Once the Pod is ready, use the Manager/extension-management UI to install custom nodes. Some nodes may need a restart after installation.


## Automatic Manager security configuration

At startup, `start.sh` writes `/opt/ComfyUI/user/__manager/config.ini` with:

```ini
[default]
security_level = weak
allow_git_url_install = true
allow_pip_install = true
```

This avoids manual editing after deployment. **Security warning:** `weak` enables additional Manager operations, and the pip/Git URL flags permit broader package/node installation. Install only nodes you trust. Current Manager versions also apply network-listener restrictions to arbitrary Git URL/pip installation; these flags may not enable those two features when ComfyUI is exposed on `0.0.0.0`. Do not weaken network protections or expose the service publicly without access controls.
