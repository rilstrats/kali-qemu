#!/bin/env bash
DIR="/var/lib/libvirt/images/"

validate_version() {
	if [[ ! $1 =~ 20[0-9]{2}\.[1-4] ]]; then
		echo "Invalid VERSION: \"$VERSION\""
		exit 1
	fi
	IMAGE="kali-linux-$VERSION-qemu-amd64.qcow2"
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
	echo "Attempting to download Kali $VERSION"
	ZIP="kali-linux-$VERSION-qemu-amd64.7z"
	if [[ -f $ZIP ]]; then
		return
	fi

	URL="https://mirrors.ocf.berkeley.edu/kali-images/kali-$VERSION"
	cd "$HOME/Downloads"
	wget -q --show-progress "$URL/$ZIP"
	cd $OLDPWD
	return $?
}

extract_zip() {
	if [[ -f $IMAGE ]]; then
		return
	fi
	7z x $ZIP
}

check_image_in_dir() {
	if [[ -f "$DIR/$IMAGE" ]]; then
		echo "$IMAGE is already in $DIR"
		return
	fi

	return 1
}

copy_image_to_dir() {
	sudo rsync -az --progress $IMAGE $DIR
}

fetch_image() {
	for i in {0..1}; do
		check_image_in_dir && break
		fetch_zip || {
			downgrade_version
			continue
		}
		extract_zip
		copy_image_to_dir
	done
}

cache_sudo() {
	echo "sudo will be needed to modify $DIR"
	sudo -v
}

# edit_image() {}

# create_vm() {}

main() {
	get_version
	fetch_image
	# edit_image
	# create_vm
}

main "$@"
