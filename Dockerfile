FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    asterisk \
    ca-certificates \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

RUN rm -rf /etc/asterisk/*

RUN printf '[options]\nrunuser = asterisk\nrungroup = asterisk\n' \
    > /etc/asterisk/asterisk.conf

RUN printf '[general]\nrtpstart=10000\nrtpend=10100\nexternaddr=${EXTERNAL_IP}\n' \
    > /etc/asterisk/rtp.conf.tmpl

RUN printf '[general]\n[logfiles]\nconsole => notice,warning,error\n' \
    > /etc/asterisk/logger.conf

COPY config/ /opt/config/
COPY scripts/ /usr/local/bin/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /usr/local/bin/*.sh

EXPOSE 5060/udp 5060/tcp 10000-10100/udp

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD ["/usr/local/bin/healthcheck.sh"]

ENTRYPOINT ["/entrypoint.sh"]
