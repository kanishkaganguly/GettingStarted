FROM osrf/ros:melodic-desktop-full-bionic

# Set default shell
SHELL ["/bin/bash", "-c"]

# System installations
RUN apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654 && \
    apt-get update && \
    apt-get install -y --no-install-recommends --allow-unauthenticated \
    software-properties-common \
    bash-completion \
    build-essential \
    git \
    apt-transport-https \
    ca-certificates \
    make \
    automake \
    autoconf \
    libtool \
    pkg-config \
    python \
    libxau-dev \
    libxdmcp-dev \
    libxext-dev \
    libx11-dev \
    x11proto-gl-dev \
    doxygen \
    tmux \
    sudo \
    locales \
    htop \
    wget  && \
    locale-gen en_US.UTF-8 && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*

# nvidia-docker2 OpenGL
COPY --from=nvidia/opengl:1.0-glvnd-runtime-ubuntu16.04 \
    /usr/local/lib/x86_64-linux-gnu \
    /usr/local/lib/x86_64-linux-gnu
COPY --from=nvidia/opengl:1.0-glvnd-runtime-ubuntu16.04 \
    /usr/local/share/glvnd/egl_vendor.d/10_nvidia.json \
    /usr/local/share/glvnd/egl_vendor.d/10_nvidia.json
RUN echo '/usr/local/lib/x86_64-linux-gnu' >> /etc/ld.so.conf.d/glvnd.conf && \
    ldconfig && \
    echo '/usr/local/$LIB/libGL.so.1' >> /etc/ld.so.preload && \
    echo '/usr/local/$LIB/libEGL.so.1' >> /etc/ld.so.preload
ENV NVIDIA_VISIBLE_DEVICES \
    ${NVIDIA_VISIBLE_DEVICES:-all}
ENV NVIDIA_DRIVER_CAPABILITIES \
    ${NVIDIA_DRIVER_CAPABILITIES:+$NVIDIA_DRIVER_CAPABILITIES,}graphics

# Add new user
RUN useradd --system --create-home --home-dir /home/user --shell /bin/bash --gid root --groups sudo --uid 1000 --password user@123 user && \ 
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Environment variables
ENV LANG=en_US.UTF-8 \
    USER=user \
    UID=1000 \
    HOME=/home/user \
    QT_X11_NO_MITSHM=1
USER $USER
WORKDIR $HOME
# custom Bash prompt
RUN { echo && echo "PS1='\[\e]0;\u \w\a\]\[\033[01;32m\]\u\[\033[00m\] \[\033[01;34m\]\w\[\033[00m\] \\\$ '" ; } >> .bashrc

# tmux config
ADD --chown=user:1000 https://raw.githubusercontent.com/kanishkaganguly/dotfiles/master/tmux/.tmux.bash.conf $HOME/.tmux.conf

# ROS setup
RUN sudo apt-get update && \
    sudo apt-get install -y \
    python-catkin-tools \
    ros-melodic-moveit-*

# Setup ROS workspace directory and fetch BioTac ROS packages
RUN mkdir -p $HOME/workspace/src && \
    catkin init --workspace $HOME/workspace/ && \
    cd $HOME/workspace/src

# Python3 for ROS and shadowevents
# rosbag/rospkg in biotac_export depends on python2 libraries
RUN sudo apt-get update && \
    sudo apt-get install -y python-pip python3-pip python3-yaml && \
    sudo -H python3 -m pip install --upgrade pip && \
    sudo -H python3 -m pip install scikit-build rospkg catkin_pkg matplotlib scipy numpy tqdm pytest pycryptodomex gnupg open3d-python opencv-python opencv-python opencv-contrib-python && \
    sudo -H python2 -m pip install pycryptodomex gnupg tqdm && \
    sudo apt-get install -y python3.6-tk

# cmake 3.9
WORKDIR /opt
ADD --chown=user:1000 https://cmake.org/files/v3.9/cmake-3.9.6-Linux-x86_64.sh /opt/cmake-3.9.6-Linux-x86_64.sh
RUN sudo chmod +x /opt/cmake-3.9.6-Linux-x86_64.sh; \
    yes Y | sudo /opt/cmake-3.9.6-Linux-x86_64.sh; \
    sudo ln -s /opt/cmake-3.9.6-Linux-x86_64/bin/* /usr/local/bin

# Eigen
RUN cd $HOME/apps && \
    git clone https://gitlab.com/libeigen/eigen.git && \
    mkdir -p $HOME/apps/eigen/build && \
    cd $HOME/apps/eigen/build && \
    cmake ../ && \
    make -j && \
    sudo make install

# Set up ROS
RUN source /opt/ros/melodic/setup.bash && \
    cd ${HOME}/workspace && \
    catkin build && \
    source $HOME/workspace/devel/setup.bash

# Set up working directory and bashrc
WORKDIR ${HOME}/workspace/
RUN echo 'source /opt/ros/melodic/setup.bash' >> $HOME/.bashrc && \
    echo 'source $HOME/workspace/devel/setup.bash' >> $HOME/.bashrc
