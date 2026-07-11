FROM ubuntu:24.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    STEAMCMD_DIR=/opt/steamcmd \
    AVORION_DIR=/opt/avorion \
    AVORION_DATA_DIR=/var/lib/avorion/galaxies \
    HOME=/home/avorion \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        lib32gcc-s1 \
        lib32stdc++6 \
        libc6-i386 \
        passwd \
        procps \
        tini \
        util-linux \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system avorion \
    && useradd \
        --system \
        --gid avorion \
        --create-home \
        --home-dir /home/avorion \
        --shell /bin/bash \
        avorion \
    && mkdir -p "${STEAMCMD_DIR}" "${AVORION_DIR}" "${AVORION_DATA_DIR}" \
    && curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
       | tar -xz -C "${STEAMCMD_DIR}" \
    && chown -R avorion:avorion \
        "${STEAMCMD_DIR}" \
        "${AVORION_DIR}" \
        "${AVORION_DATA_DIR}" \
        /home/avorion

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

WORKDIR /opt/avorion

EXPOSE 27000/tcp 27000/udp 27003/udp 27020/udp 27021/udp

STOPSIGNAL SIGTERM

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
