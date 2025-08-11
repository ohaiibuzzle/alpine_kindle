#/usr/bin/env bash

# Ensure we are root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

REPO="http://dl-cdn.alpinelinux.org/alpine"
MOUNT_POINT="/mnt/alpine"
IMAGE="./alpine.ext4"
IMAGESIZE=2048 # Megabytes

if [ -n "$1" ]; then
  ARCH="$1"
else
  echo "Usage: $0 <architecture>"
  echo "<architecture> is any architecture that Alpine Linux supports"
  exit 1
fi

# Grab the prebuilt minirootfs
wget "$REPO/latest-stable/releases/$ARCH/latest-releases.yaml"
MINIROOTFS_FILE=$(grep "file: alpine-minirootfs-.*-$ARCH.tar.gz" latest-releases.yaml | awk '{print $2}')
wget "$REPO/latest-stable/releases/$ARCH/$MINIROOTFS_FILE" -O minirootfs.tar.gz

# Prepare the disk image
dd if=/dev/zero of="$IMAGE" bs=1M count="$IMAGESIZE"
mkfs.ext4 -F "$IMAGE"
tune2fs -i 0 -c 0 -O ^has_journal "$IMAGE"

# Mount the image
mkdir -p "$MOUNT_POINT"
mount -o loop "$IMAGE" "$MOUNT_POINT"

# Extract the minirootfs
tar -xzvf minirootfs.tar.gz -C "$MOUNT_POINT"

# Preconfig the image
echo "kindle" > "$MOUNT_POINT/etc/hostname"
echo "nameserver 8.8.8.8" > "$MOUNT_POINT/etc/resolv.conf"

# check if the env var RUN_CUSTOMIZE exists
if [ -n "$RUN_CUSTOMIZE" ]; then
  # Copy the customize script
  cp ./customize.sh "$MOUNT_POINT/root/customize.sh"
  chmod +x "$MOUNT_POINT/root/customize.sh"

  # Copy qemu-[arch] binaries
  cp $(which qemu-arm-static) "$MOUNT_POINT/usr/bin/"

  # Run the customize script
  chroot "$MOUNT_POINT" /usr/bin/qemu-arm-static /bin/sh /root/customize.sh

  rm /root/customize.sh
  rm /usr/bin/qemu-arm-static
fi

# Unmount the image
sync
umount "$MOUNT_POINT"
rm -rf "$MOUNT_POINT"
