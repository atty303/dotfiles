FROM ghcr.io/ublue-os/bazzite:stable@sha256:fbd9a04cf9fa5166b4b4fffa1efbd87433c8bc94027182a338f0b7c0b8acde82

RUN install -d -m 0755 \
        /var/home \
        /var/lib/systemd/linger \
        /var/spool/mail \
        /var/usrlocal/secrets \
    && useradd --create-home e2e \
    && touch /var/lib/systemd/linger/e2e \
    && printf 'e2e ALL=(ALL) NOPASSWD: ALL\n' >/etc/sudoers.d/e2e \
    && chmod 0440 /etc/sudoers.d/e2e \
    && ln -s /dev/null /etc/systemd/system/NetworkManager.service \
    && ln -s /dev/null /etc/systemd/system/systemd-resolved.service \
    && rm /etc/resolv.conf \
    && touch /etc/resolv.conf

COPY tests/e2e/containers/bazzite-podman /usr/local/bin/podman
COPY tests/e2e/containers/bazzite-crun /usr/local/bin/crun-e2e
RUN chmod 0755 /usr/local/bin/podman /usr/local/bin/crun-e2e

ENV HOME=/home/e2e
ENV PATH=/home/e2e/.local/bin:/usr/local/bin:/usr/bin:/bin
ENV XDG_RUNTIME_DIR=/run/user/1000
ENV DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus

CMD ["/sbin/init"]
