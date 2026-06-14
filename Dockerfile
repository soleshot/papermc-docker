# Base off the official Eclipse Temurin JRE on Alpine.
# Paper 26.1+ requires Java 25, which Alpine's stable repos do not yet package
# (openjdk25 is edge-only). Pulling a maintained JRE 25 image keeps the result
# small (Alpine + JRE only) and decouples the Java version from Alpine's release
# cadence, while still giving us apk and the BusyBox user tools below.     -Corbe
#
# Pinned by digest for reproducible builds (tag: 25-jre-alpine = JRE 25.0.3+9).
# To take Java/OS security patches: re-pull the tag, read the new digest with
#   docker inspect --format '{{index .RepoDigests 0}}' eclipse-temurin:25-jre-alpine
# update the digest below, and rebuild.
FROM eclipse-temurin:25-jre-alpine@sha256:c707c0d18cb9e8556380719f80d96a7529d0746fbb42143893949b98ed2f8943

# Install runtime tools (Java is provided by the base image)
RUN apk add --no-cache \
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
    echo "$USERNAME ALL=(ALL) NOPASSWD: /usr/sbin/crond, /usr/bin/crontab" > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME

# Create required directories, owned by the runtime user (no world-writable 777).
# The backup cron runs as root and can still write /backups and /logs.
RUN mkdir /papermc /backups /logs \
    && chown -R $USERNAME:$USERNAME /papermc /backups /logs
COPY papermc.sh /papermc.sh
COPY start-backup.sh /scripts/
RUN chmod +x /scripts/*.sh

# Set the default user
USER $USERNAME

# Start script
CMD ["bash", "/papermc.sh"]

# Container setup
EXPOSE 25565/tcp
EXPOSE 25565/udp
VOLUME /papermc
VOLUME /logs
VOLUME /backups
