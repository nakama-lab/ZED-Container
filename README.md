# 🚀 ZED ROS2 Docker Setup

This project provides a Dockerized environment to run the [ZED ROS2 Wrapper](https://github.com/stereolabs/zed-ros2-wrapper) using a ZED camera on ROS 2.

---

## 📦 What’s Included

* **ROS 2 Humble** with ZED SDK
* Full GPU access via NVIDIA runtime
* Shared memory and device access for camera performance
* Hot-swappable camera config files
* Preconfigured for **ZED2** camera

---

## ✅ Prerequisites

### 1. NVIDIA Drivers & Docker Toolkit

Ensure your system has the NVIDIA drivers and container runtime installed.

#### Install NVIDIA Container Toolkit:

```bash
# Add NVIDIA GPG key and repository
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
    sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Install toolkit and restart Docker
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo systemctl daemon-reload
sudo systemctl restart docker
```

#### Docker Daemon Configuration

Add the NVIDIA runtime to Docker’s daemon settings:

```bash
sudo nano /etc/docker/daemon.json
```

Paste:

```json
{
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  }
}
```

---

## 🛠️ Building the Docker Image

This setup uses a local `Dockerfile`. Build it using:

```bash
docker compose build
```

This builds the image:
`zed_ros2_desktop_u22.04_sdk_4.2.5_cuda_12.6.3:latest`

---

## 🔧 Configuration

### Camera Model

The setup defaults to **ZED2**. To change the camera model (e.g., ZED Mini), edit the launch command inside the container or modify your launch files.

To launch with ZED Mini:

```bash
ros2 launch zed_wrapper zed_camera.launch.py camera_model:=zedm
```

### Runtime Environment

Key container options:

* `runtime: nvidia` — enables GPU access
* `privileged: true` — required for accessing hardware devices
* `network_mode: "host"` — direct ROS2 communication
* `volumes:`

  * `/tmp/.X11-unix` — GUI tools like RViz
  * `/dev` — access to camera hardware
  * `./config` — override ZED configuration at runtime

### ✏️ Modifying the Config Files

All ZED node parameters are defined in YAML files inside the `config/` folder on your host. These are bind-mounted into the container at:

```
/root/ros2_ws/src/zed-ros2-wrapper/zed_wrapper/config/
```

1. **Locate your config folder**
   In your project root:

   ```bash
   ls config/
   # e.g. common.yaml  zed2.yaml
   ```

2. **Edit the YAML files**
   Open any file (e.g. `zed2.yaml`) and tweak settings such as resolution, frame rate, depth mode, etc.

   ```yaml
   zed2:
     zed:
       resolution: HD1080
       depth_mode: PERFORMANCE
       camera_fps: 60
   ```

3. **Apply changes**

   * **On container restart**: Simply stop and `docker compose up` again, and your edits will be loaded.

> An example with descriptions is found at the file `example.yaml`
---

## ▶️ Running the Container

Once built, start the environment with:

```bash
docker compose up
```

To interact with the container (e.g., run `ros2 launch` manually):

```bash
docker exec -it Zedcam bash
```

---

## 📚 Additional Resources

* [ZED ROS2 Wrapper Documentation](https://www.stereolabs.com/docs/ros2/overview/)
* [ZED Camera Configuration Parameters](https://www.stereolabs.com/docs/ros2/zed-node#configuration-parameters)

> If not enable you must:
> ``` bash
> xhost +local:root
> export DISPLAY=$DISPLAY
> ```

