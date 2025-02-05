# We're no longer using openjdk:17-slim as a base due to several unpatched vulnerabilities.
# The results from basing off of alpine are a smaller (by 47%) and faster (by 17%) image.
# Even with bash installed.     -Corbe
FROM alpine:latest

# Environment variables
ENV MC_VERSION="latest" \
    PAPER_BUILD="latest" \
    EULA="true" \
    MC_RAM="" \
    JAVA_OPTS=""

COPY papermc.sh .
RUN apk update \
    && apk add openjdk21 \
    bash \
    curl \
    wget \
    jq \
    dcron \
    rsync

# Create required directories
RUN mkdir /papermc \
    && mkdir /backups \
    && mkdir /logs

COPY start-backup.sh /scripts/
RUN chmod +x /scripts/*.sh

# Start script
CMD ["bash", "./papermc.sh"]

# Container setup
EXPOSE 25565/tcp
EXPOSE 25565/udp
VOLUME /papermc
VOLUME /logs
VOLUME /backups
