#!/bin/env bash
POOL="/var/lib/libvirt/images"
DL_PREFIX="$HOME/Downloads"

validate_version() {
	if [[ ! $1 =~ 20[0-9]{2}\.[1-4] ]]; then
		echo "Invalid VERSION: \"$VERSION\""
		exit 1
	fi
	DOMAIN="kali-$VERSION"
	DL_DIR="$DL_PREFIX/$DOMAIN"
	URL="https://mirrors.ocf.berkeley.edu/kali-images/kali-$VERSION"
	ZIP="kali-linux-$VERSION-qemu-amd64.7z"
	IMAGE="kali-linux-$VERSION-qemu-amd64.qcow2"
	IMAGE_MOD="$DOMAIN.qcow2"
	IMAGE_PATH="$POOL/$IMAGE_MOD"
}

get_version() {
	YEAR="$1"
	if [[ -z $YEAR ]]; then
		YEAR=$(date +%Y)
	fi
	MONTH="$2"
	if [[ -z $MONTH ]]; then
		MONTH=$(date +%m)
	fi
	QUARTER=$(( (MONTH - 1) / 3 + 1 ))
	VERSION="$YEAR.$QUARTER"
	validate_version $VERSION
}

downgrade_version() {
	QUARTER=$(( QUARTER - 1 ))
	if [[ $QUARTER -eq 0 ]]; then
		QUARTER=4
		YEAR=$(( YEAR - 1 ))
	fi
	VERSION="$YEAR.$QUARTER"
	validate_version $VERSION
}

# upgrade_kali_version() {
# 	QUARTER=$(( QUARTER + 1 ))
# 	if [[ $QUARTER -eq 5 ]]; then
# 		QUARTER=1
# 		YEAR=$(( YEAR - 1 ))
# 	fi
# 	VERSION="$YEAR.$QUARTER"
# 	validate_version $VERSION
# }

fetch_zip() {
	if [[ -f "$DL_DIR/$ZIP" ]]; then
		return
	fi

	# echo "Attempting to download Kali $VERSION"
	wget -qP $DL_DIR --force-progress "$URL/$ZIP"
	return $?
}

extract_zip() {
	if [[ -f "$DL_DIR/$IMAGE" ]]; then
		return
	fi
	7z x "-o$DL_DIR" "$DL_DIR/$ZIP"
}

check_image_in_pool() {
	if [[ -f "$IMAGE_PATH" ]]; then
		echo "Kali $VERSION already exists: $IMAGE_PATH"
		return
	fi

	return 1
}

copy_image_to_pool() {
	sudo rsync -az --progress "$DL_DIR/$IMAGE" "$IMAGE_PATH"
}

fetch_image() {
	for i in {0..1}; do
		check_image_in_pool && break
		fetch_zip || {
			downgrade_version
			continue
		}
		extract_zip
		copy_image_to_pool
	done
}

cache_sudo() {
	sudo -nv 2> /dev/null || {
		echo "sudo password required for interacting with qemu"
		sudo -v
	}
}

edit_image() {
	FSTAB_LINE="cyber /cyber virtiofs defaults,nofail 0 0"
	virt-customize -a $IMAGE_PATH \
		--mkdir /cyber \
		--chmod 1777:/cyber \
		--run-command "grep -qF \"$FSTAB_LINE\" /etc/fstab || echo \"$FSTAB_LINE\" >> /etc/fstab" \
		--copy-in resize:/usr/local/bin \
		--copy-in mountcyber:/usr/local/bin
}

create_vm() {
	sed "s/kali-20XX.X/$DOMAIN/g" kali.xml > "$DL_DIR/$DOMAIN.xml"
	sudo virsh define $DL_DIR/$DOMAIN.xml
}

snapshot_vm() {
	sudo virsh snapshot-create-as --domain $DOMAIN --name "$1"
}

main() {
	cache_sudo
	get_version
	fetch_image
	create_vm
	snapshot_vm original
	edit_image
	snapshot_vm custom
}

main "$@"
