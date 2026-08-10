FROM ubuntu:24.04

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        desktop-file-utils \
        findutils \
        fontconfig \
        git \
        gzip \
        ncurses-bin \
        tar \
        unzip \
        xdg-utils \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home e2e

USER e2e
ENV HOME=/home/e2e
ENV PATH=/home/e2e/.local/bin:/usr/local/bin:/usr/bin:/bin
WORKDIR /home/e2e

CMD ["sleep", "infinity"]
