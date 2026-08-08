FROM registry.fedoraproject.org/fedora:44

RUN dnf install -y \
        bash \
        ca-certificates \
        curl \
        findutils \
        fontconfig \
        git \
        gzip \
        ncurses \
        shadow-utils \
        tar \
        unzip \
    && dnf clean all

RUN useradd --create-home e2e

USER e2e
ENV HOME=/home/e2e
ENV PATH=/home/e2e/.local/bin:/usr/local/bin:/usr/bin:/bin
WORKDIR /home/e2e

CMD ["sleep", "infinity"]
