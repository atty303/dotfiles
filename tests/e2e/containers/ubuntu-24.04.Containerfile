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
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        desktop-file-utils \
        xdg-utils \
    && rm -rf /var/lib/apt/lists/*

USER vscode
CMD ["sleep", "infinity"]
