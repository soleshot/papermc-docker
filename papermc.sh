#!/bin/bash

# Enter server directory
cd papermc

# Set nullstrings back to 'latest'
: ${MC_VERSION:='latest'}
: ${PAPER_BUILD:='latest'}

# Lowercase these to avoid 404 errors on wget
MC_VERSION="${MC_VERSION,,}"
PAPER_BUILD="${PAPER_BUILD,,}"

# Get version information and build download URL and jar name
URL='https://api.papermc.io/v2/projects/paper'
if [[ $MC_VERSION == latest ]]; then
  # Get the latest MC version
  MC_VERSION=$(curl -s ${URL} |
    jq -r '.versions[-1]')
fi
echo "Targeting minecraft version: $MC_VERSION"
if [[ $PAPER_BUILD == latest ]]; then
  # Get the latest build
  PAPER_BUILDS_JSON=$(curl -s "https://api.papermc.io/v2/projects/paper/versions/${MC_VERSION}")
  PAPER_BUILD=$(echo "$PAPER_BUILDS_JSON" | jq '.builds | max')
fi
echo "Targeting paper build version: $PAPER_BUILD"
JAR_NAME="paper-${MC_VERSION}-${PAPER_BUILD}.jar"

URL="https://api.papermc.io/v2/projects/paper/versions/${MC_VERSION}/builds/${PAPER_BUILD}/downloads/${JAR_NAME}"

# Update if necessary
if [[ ! -e $JAR_NAME ]]; then
  # Remove old server jar(s)
  rm -f *.jar
  # Download new server jar
  echo "Downloading ${URL}"
  echo "Saving to: ${JAR_NAME}"
  wget "$URL" -O "$JAR_NAME"
fi

# Update eula.txt with current setting
# sudo echo "eula=${EULA:-true}" >eula.txt

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
