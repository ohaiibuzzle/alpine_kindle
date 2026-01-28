#/usr/bin/env bash

# Ensure we are root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

MOUNT_POINT="/mnt/alpine"
IMAGE="./alpine.ext4"
IMAGESIZE=2048 # Megabytes
SOURCE_DOCKER="debian:stable-slim"

DOCKER_ARCH_MAP=(
  "x86_64=linux/amd64"
  "aarch64=linux/arm/v8"
  "armv7l=linux/arm/v7"
  "armhf=linux/arm/v7"
)

if [ -n "$1" ]; then
  ARCH="$1"
else
  echo "Usage: $0 <architecture>"
  echo "<architecture> is any architecture that Alpine Linux supports"
  exit 1
fi

# Grab the docker image to use as rootfs
docker save "$SOURCE_DOCKER" --platform "${DOCKER_ARCH_MAP[$ARCH]}"  | tar -xO --strip-components=5 ./layer.tar > rootfs.tar.gz

# Prepare the disk image
dd if=/dev/zero of="$IMAGE" bs=1M count="$IMAGESIZE"
mkfs.ext4 -F "$IMAGE"
tune2fs -i 0 -c 0 -O ^has_journal "$IMAGE"

# Mount the image
mkdir -p "$MOUNT_POINT"
mount -o loop "$IMAGE" "$MOUNT_POINT"

# Extract the minirootfs
tar -xzvf rootfs.tar.gz -C "$MOUNT_POINT"

# Preconfig the image
echo "kindle" > "$MOUNT_POINT/etc/hostname"
echo "nameserver 8.8.8.8" > "$MOUNT_POINT/etc/resolv.conf"
mkdir ${MOUNT_POINT}/run/dbus

# check if the env var RUN_CUSTOMIZE exists
if [ -n "$RUN_CUSTOMIZE" ]; then
  echo "Running customization script inside the image..."

  # Copy the customize script
  cp ./customize.sh "$MOUNT_POINT/root/customize.sh"
  chmod +x "$MOUNT_POINT/root/customize.sh"

  # Copy qemu-[arch] binaries
  cp $(which qemu-arm-static) "$MOUNT_POINT/usr/bin/"

  # Run the customize script
  chroot "$MOUNT_POINT" /usr/bin/qemu-arm-static /bin/sh /root/customize.sh

  rm "$MOUNT_POINT/root/customize.sh"
  rm "$MOUNT_POINT/usr/bin/qemu-arm-static"
fi

# Copy the gui script
cp ./addons/gui.sh "$MOUNT_POINT/usr/local/bin/gui"
chmod +x "$MOUNT_POINT/usr/local/bin/gui"

# Unmount the image
sync
umount "$MOUNT_POINT"
rm -rf "$MOUNT_POINT"

echo "Linux minimal image for $ARCH created at $IMAGE"
