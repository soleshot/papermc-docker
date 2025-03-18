# We're no longer using openjdk:17-slim as a base due to several unpatched vulnerabilities.
# The results from basing off of alpine are a smaller (by 47%) and faster (by 17%) image.
# Even with bash installed.     -Corbe
FROM alpine:latest

# Install essential development tools
RUN apk update \
    && apk add openjdk21 \
    bash \
    curl \
    wget \
    jq \
    dcron \
    rsync \
    sudo

# Environment variables
ENV MC_VERSION="latest" \
    PAPER_BUILD="latest" \
    EULA="true" \
    MC_RAM="" \
    JAVA_OPTS=""

# Create a non-root user for development
ARG USERNAME=minecraft

RUN addgroup -S $USERNAME && \
    adduser -S -G $USERNAME $USERNAME && \
    echo "$USERNAME ALL=(ALL) NOPASSWD: /usr/sbin/crond, /usr/bin/crontab, /papermc/eula.txt" > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME

# Create required directories and access
RUN mkdir /papermc \
    && mkdir /backups \
    && mkdir /logs \
    && chmod -R 777 /papermc
COPY papermc.sh .
COPY start-backup.sh /scripts/
RUN chmod +x /scripts/*.sh

# Set the default user
USER $USERNAME

# Start script
CMD ["bash", "./papermc.sh"]

# Container setup
EXPOSE 25565/tcp
EXPOSE 25565/udp
VOLUME /papermc
VOLUME /logs
VOLUME /backups
