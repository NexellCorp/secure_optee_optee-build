#!/bin/bash

TOP="${PWD}"
BUILD_DIR="${TOP}/optee_build"
MOUNT_DIR="${BUILD_DIR}/optee_mount"
CONFIG_FILE="${TOP}/linux/.config"

echo ${ROOT}

function check()
{
	if [ ! -f ${CONFIG_FILE} ]; then
		exit
	fi

	if [ -f ${MOUNT_DIR}/bin/tee-supplicant ]; then
		add_initramfs
	else
		drop_initramfs
	fi
}


function add_initramfs()
{
	local src=${MOUNT_DIR}

	echo $src
	sed -i '/CONFIG_INITRAMFS_ROOT_UID=.*/d' ${CONFIG_FILE}
	sed -i '/CONFIG_INITRAMFS_ROOT_GID=.*/d' ${CONFIG_FILE}
	sed -i 's@CONFIG_INITRAMFS_SOURCE=.*@CONFIG_INITRAMFS_SOURCE=\"'${src}'\"\nCONFIG_INITRAMFS_ROOT_UID=0\nCONFIG_INITRAMFS_ROOT_GID=0@g' ${CONFIG_FILE}
}

function drop_initramfs()
{
	sed -i 's@CONFIG_INITRAMFS_SOURCE=.*@CONFIG_INITRAMFS_SOURCE=\"\"@g' ${CONFIG_FILE}
	sed -i '/CONFIG_INITRAMFS_ROOT_UID=.*/d' ${CONFIG_FILE}
	sed -i '/ONFIG_INITRAMFS_ROOT_GID=.*/d' ${CONFIG_FILE}
}


check
