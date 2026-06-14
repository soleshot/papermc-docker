#!/bin/bash

# Enter server directory
cd /papermc

# Set nullstrings back to 'latest'
: ${MC_VERSION:='latest'}
: ${PAPER_BUILD:='latest'}

# Lowercase these to avoid 404 errors on wget
MC_VERSION="${MC_VERSION,,}"
PAPER_BUILD="${PAPER_BUILD,,}"

# Resolve the version + build via the PaperMC Fill (v3) API.
# The old api.papermc.io/v2 API is deprecated and no longer lists Paper
# versions >= 26.x, so "latest" there would silently stay on the 1.21 line.
API='https://fill.papermc.io/v3/projects/paper'
UA='papermc-docker (+https://github.com/Phyremaster/papermc-docker)'

if [[ $MC_VERSION == latest ]]; then
  # Newest full release (skip rc/pre/beta versions, which contain a hyphen)
  MC_VERSION=$(curl -s -A "$UA" "$API" |
    jq -r '[.versions[][] | select(test("-") | not)] | first')
fi
echo "Targeting minecraft version: $MC_VERSION"

# Fetch the build metadata. The v3 response embeds the jar name and a ready-made
# download URL (on fill-data.papermc.io), so we no longer build the URL by hand.
if [[ $PAPER_BUILD == latest ]]; then
  BUILD_JSON=$(curl -s -A "$UA" "${API}/versions/${MC_VERSION}/builds/latest")
else
  BUILD_JSON=$(curl -s -A "$UA" "${API}/versions/${MC_VERSION}/builds/${PAPER_BUILD}")
fi

PAPER_BUILD=$(echo "$BUILD_JSON" | jq -r '.id')
JAR_NAME=$(echo "$BUILD_JSON" | jq -r '.downloads."server:default".name')
JAR_URL=$(echo "$BUILD_JSON" | jq -r '.downloads."server:default".url')
JAR_SHA256=$(echo "$BUILD_JSON" | jq -r '.downloads."server:default".checksums.sha256')
echo "Targeting paper build version: $PAPER_BUILD"

if [[ -z $JAR_URL || $JAR_URL == null ]]; then
  echo "ERROR: could not resolve a Paper download for MC_VERSION='${MC_VERSION}' PAPER_BUILD='${PAPER_BUILD}'." >&2
  echo "Browse valid values at ${API} ." >&2
  exit 1
fi

# Update if necessary
if [[ ! -e $JAR_NAME ]]; then
  # Remove old server jar(s)
  rm -f ./*.jar
  # Download new server jar
  echo "Downloading ${JAR_URL}"
  echo "Saving to: ${JAR_NAME}"
  wget "$JAR_URL" -O "$JAR_NAME"

  # Verify integrity against the checksum the API gave us
  if [[ -n $JAR_SHA256 && $JAR_SHA256 != null ]]; then
    if ! echo "${JAR_SHA256}  ${JAR_NAME}" | sha256sum -c -; then
      echo "ERROR: checksum mismatch for ${JAR_NAME}; removing corrupt download." >&2
      rm -f "$JAR_NAME"
      exit 1
    fi
  fi
fi

# Accept (or decline) the Minecraft EULA per the EULA env var.
# cwd is /papermc, owned by this user, so a plain write works (the previous
# `sudo echo ... > eula.txt` failed because the shell did the redirect, not sudo).
echo "eula=${EULA:-true}" > eula.txt

# Add RAM options to Java options if necessary
if [[ -n $MC_RAM ]]; then
  JAVA_OPTS="-Xms${MC_RAM} -Xmx${MC_RAM} $JAVA_OPTS"
fi

# Optimization flags
JAVA_OPTS="-XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:+ParallelRefProcEnabled -XX:+PerfDisableSharedMem -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1HeapRegionSize=8M -XX:G1HeapWastePercent=5 -XX:G1MaxNewSizePercent=40 -XX:G1MixedGCCountTarget=4 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1NewSizePercent=30 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:G1ReservePercent=20 -XX:InitiatingHeapOccupancyPercent=15 -XX:MaxGCPauseMillis=200 -XX:MaxTenuringThreshold=1 -XX:SurvivorRatio=32 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true $JAVA_OPTS"

# Setup Backups
sudo crond

# Configuration
# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BACKUP_SCRIPT="/scripts/start-backup.sh"
CRON_SCHEDULE="0 4 * * *" # Every day at 4am

# Check if backup script is already scheduled
EXISTING_CRON=$(sudo crontab -l 2>/dev/null | grep "${BACKUP_SCRIPT}")

if [ -z "$EXISTING_CRON" ]; then
  # Add to crontab if not present
  (
    sudo crontab -l 2>/dev/null
    echo "${CRON_SCHEDULE} ${BACKUP_SCRIPT}"
  ) | sudo crontab -
  echo "Backup scheduled: ${CRON_SCHEDULE}"
else
  echo "Backup already scheduled"
fi

# Start server
exec java -server $JAVA_OPTS -jar "$JAR_NAME" nogui
