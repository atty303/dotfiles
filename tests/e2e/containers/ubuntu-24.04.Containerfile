FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04 AS base

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        findutils \
        fontconfig \
        git \
        gzip \
        ncurses-bin \
        tar \
        unzip \
    && rm -rf /var/lib/apt/lists/*

ENV HOME=/home/vscode
ENV PATH=/home/vscode/.local/bin:/usr/local/bin:/usr/bin:/bin
WORKDIR /home/vscode

FROM base AS headless
USER vscode
CMD ["sleep", "infinity"]

FROM base AS desktop
USER root
RUN install -d /usr/share/wayland-sessions \
    && printf '[Desktop Entry]\nName=E2E\nExec=true\nType=Application\n' >/usr/share/wayland-sessions/e2e.desktop
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        desktop-file-utils \
        libwayland-client0 \
        xdg-utils \
    && rm -rf /var/lib/apt/lists/*

USER vscode
CMD ["sleep", "infinity"]
