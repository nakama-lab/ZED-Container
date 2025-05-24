###########################################
# Dockerfile: General ZED ROS2 Container
###########################################

# ---------- Build Arguments ----------
ARG UBUNTU_MAJOR=22
ARG UBUNTU_MINOR=04
ARG CUDA_MAJOR=12
ARG CUDA_MINOR=6
ARG CUDA_PATCH=3
ARG ZED_SDK_MAJOR=4
ARG ZED_SDK_MINOR=2
ARG ZED_SDK_PATCH=5
ARG ROS2_DIST=humble
ARG IMAGE_NAME=nvcr.io/nvidia/cuda:${CUDA_MAJOR}.${CUDA_MINOR}.${CUDA_PATCH}-devel-ubuntu${UBUNTU_MAJOR}.${UBUNTU_MINOR}

FROM ${IMAGE_NAME}

# ---------- Re-declare for scope ----------
ARG ZED_SDK_MAJOR
ARG ZED_SDK_MINOR
ARG ZED_SDK_PATCH
ARG CUDA_MAJOR
ARG ROS2_DIST
ARG UBUNTU_MAJOR

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Paris
ENV LANG=en_US.UTF-8
ENV ROS_DISTRO=${ROS2_DIST}

# Optional custom SDK URL
ARG CUSTOM_ZED_SDK_URL=""
ENV ZED_SDK_URL=${CUSTOM_ZED_SDK_URL:-"https://download.stereolabs.com/zedsdk/${ZED_SDK_MAJOR}.${ZED_SDK_MINOR}.${ZED_SDK_PATCH}/cu${CUDA_MAJOR}/ubuntu${UBUNTU_MAJOR}"}

# ---------- Base Dependencies ----------
RUN apt-get update && apt-get install -y --no-install-recommends \
    tzdata curl wget sudo gnupg2 software-properties-common \
    lsb-release build-essential cmake git \
    python3 python3-dev python3-pip python3-wheel \
    libopencv-dev libpq-dev libusb-1.0-0-dev usbutils udev \
    bash-completion zstd jq locales \
 && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
 && echo $TZ > /etc/timezone \
 && locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8 \
 && rm -rf /var/lib/apt/lists/*

# ---------- ROS2 Installation ----------
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" > /etc/apt/sources.list.d/ros2.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
    ros-${ROS2_DIST}-ros-base \
    python3-flake8-docstrings python3-pytest-cov ros-dev-tools \
 && pip3 install -U argcomplete numpy empy lark \
 && rm -rf /var/lib/apt/lists/*

#-------- Install RQT ---------
RUN apt update && apt install -y \
    ros-humble-rqt \
    ros-humble-rqt-common-plugins \
 && rm -rf /var/lib/apt/lists/*

# ---------- ROS Dependency Init ----------
RUN rosdep init || true && rosdep update

# ---------- Install ZED SDK ----------
RUN echo "Installing ZED SDK from $ZED_SDK_URL" \
 && wget -q -O ZED_SDK_Linux_Ubuntu.run "${ZED_SDK_URL}" \
 && chmod +x ZED_SDK_Linux_Ubuntu.run \
 && ./ZED_SDK_Linux_Ubuntu.run -- silent skip_tools skip_cuda \
 && ln -sf /lib/x86_64-linux-gnu/libusb-1.0.so.0 /usr/lib/x86_64-linux-gnu/libusb-1.0.so \
 && rm ZED_SDK_Linux_Ubuntu.run

# ---------- ROS2 Workspace Setup ----------
ENV WORKSPACE=/root/ros2_ws
RUN mkdir -p ${WORKSPACE}/src

WORKDIR ${WORKSPACE}/src
# Clone the ZED ROS2 wrapper repository and checkout the release tag for SDK 4.2.5
RUN git clone https://github.com/stereolabs/zed-ros2-wrapper.git && \
    cd zed-ros2-wrapper && \
    git checkout humble-v4.2.5

# Go back to workspace root
WORKDIR ${WORKSPACE}

# Update and install ROS dependencies
RUN apt update && \
    rosdep update && \
    rosdep install --from-paths src --ignore-src -r -y

# Build the workspace with Release flags and max cores
RUN bash -c "source /opt/ros/$ROS_DISTRO/setup.bash && \
    colcon build --symlink-install \
    --cmake-args=-DCMAKE_BUILD_TYPE=Release \
    --parallel-workers $(nproc)"

# automatically source the environment in every new shell
RUN echo "source ${WORKSPACE}/install/local_setup.bash" >> ~/.bashrc


# Users can mount or copy code to /root/ros2_ws/src during build or runtime

# ---------- Bash Entrypoint ----------
RUN echo '#!/bin/bash\n\
source /opt/ros/$ROS_DISTRO/setup.bash\n\
if [ -f "${WORKSPACE}/install/setup.bash" ]; then\n\
  source "${WORKSPACE}/install/setup.bash"\n\
fi\n\
exec "$@"' > /sbin/ros_entrypoint.sh \
 && chmod +x /sbin/ros_entrypoint.sh

ENTRYPOINT ["/sbin/ros_entrypoint.sh"]
CMD ["bash"]
