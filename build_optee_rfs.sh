#!/bin/bash
TOP=$(pwd)
export CC_DIR=$TOP/toolchains/gcc-linaro-4.9-2014.11-x86_64_aarch64-linux-gnu
export PATH=${CC_DIR}/bin:$PATH
KERNEL_VERSION=`cd linux ; make --no-print-directory -s kernelversion`
BASE_RFS="ramdisk.gz"
OPTEE_RFS="optee_rfs"
OPTEE_RFSGZ="${OPTEE_RFS}.gz"
BUILD_DIR="${TOP}/optee_build"
MOUNT_DIR="optee_mount"


cd ${BUILD_DIR}

#if [ -f ./${OPTEE_RFS} ] ; then
#	echo "Already exist file : ${OPTEE_RFS}"
#	exit 0
#fi

#if [ -d ${MOUNT_DIR} ] ; then
#	sudo umount -f ${BUILD_DIR}/${MOUNT_DIR}
#	yes | sudo rm -rf ${BUILD_DIR}/${MOUNT_DIR} ${OPTEE_RFS}
#fi

mkdir -p ${MOUNT_DIR}
cp ${BASE_RFS} ${OPTEE_RFSGZ}
gzip -d ${OPTEE_RFSGZ}
sudo mount -o loop,rw,sync ./${OPTEE_RFS} ./${MOUNT_DIR}
sudo chmod -R 755 ./${MOUNT_DIR}

cd ${MOUNT_DIR}

# rc.d entry for OP-TEE (start on boot)
sudo cp ${BUILD_DIR}/init.d.optee ./etc/init.d/optee
if [ ! -L ./etc/init.d/S09_optee ] ; then
	pushd . > /dev/null
	cd ./etc/init.d
	sudo ln -s ./optee ./S09_optee
	popd > /dev/null
fi

# OP-TEE device
if [ ! -d ./lib/modules ] ; then
	sudo mkdir ./lib/modules
	sudo chmod 755 ./lib/modules
fi
if [ ! -d ./lib/modules/${KERNEL_VERSION} ] ; then
	sudo mkdir ./lib/modules/${KERNEL_VERSION}
	sudo chmod 755 ./lib/modules/${KERNEL_VERSION}
fi
sudo cp ${TOP}/optee_linuxdriver/core/optee.ko ./lib/modules/${KERNEL_VERSION}/optee.ko
sudo cp ${TOP}/optee_linuxdriver/armtz/optee_armtz.ko ./lib/modules/${KERNEL_VERSION}/optee_armtz.ko
 
# OP-TEE client
sudo cp ${TOP}/optee_client/out/export/bin/tee-supplicant ./bin/tee-supplicant
if [ ! -d ./lib/aarch64-linux-gnu ] ; then
	sudo mkdir ./lib/aarch64-linux-gnu
	sudo chmod 755 ./lib/aarch64-linux-gnu
fi
 
sudo cp ${TOP}/optee_client/out/export/lib/libteec.so.1.0 ./lib/libteec.so.1.0
sudo cp ${TOP}/optee_client/out/export/lib/libteec.so.1.0 ./lib/libteec.so.1
sudo cp ${TOP}/optee_client/out/export/lib/libteec.so.1.0 ./lib/libteec.so
 
# OP-TEE tests
sudo cp ${TOP}/optee_test/out/xtest/xtest ./bin/xtest

if [ ! -d ./lib/optee_armtz ] ; then
	sudo mkdir ./lib/optee_armtz
	sudo chmod 755 ./lib/optee_armtz
fi
sudo cp ${TOP}/optee_test/out/ta/rpc_test/d17f73a0-36ef-11e1-984a0002a5d5c51b.ta ./lib/optee_armtz/d17f73a0-36ef-11e1-984a0002a5d5c51b.ta
sudo cp ${TOP}/optee_test/out/ta/crypt/cb3e5ba0-adf1-11e0-998b0002a5d5c51b.ta ./lib/optee_armtz/cb3e5ba0-adf1-11e0-998b0002a5d5c51b.ta
sudo cp ${TOP}/optee_test/out/ta/storage/b689f2a7-8adf-477a-9f9932e90c0ad0a2.ta ./lib/optee_armtz/b689f2a7-8adf-477a-9f9932e90c0ad0a2.ta
sudo cp ${TOP}/optee_test/out/ta/os_test/5b9e0e40-2636-11e1-ad9e0002a5d5c51b.ta ./lib/optee_armtz/5b9e0e40-2636-11e1-ad9e0002a5d5c51b.ta
sudo cp ${TOP}/optee_test/out/ta/create_fail_test/c3f6e2c0-3548-11e1-b86c0800200c9a66.ta ./lib/optee_armtz/c3f6e2c0-3548-11e1-b86c0800200c9a66.ta
sudo cp ${TOP}/optee_test/out/ta/sims/e6a33ed4-562b-463a-bb7eff5e15a493c8.ta ./lib/optee_armtz/e6a33ed4-562b-463a-bb7eff5e15a493c8.ta
 
# AES benchmark application
#sudo cp ${TOP}/aes-perf/out/aes-perf/aes-perf ./bin/aes-perf
#sudo chmod 755 ./bin/aes-perf
#sudo cp ${TOP}/aes-perf/out/ta/e626662e-c0e2-485c-b8c809fbce6edf3d.ta ./lib/optee_armtz/e626662e-c0e2-485c-b8c809fbce6edf3d.ta
 
# Hello world test application
#sudo cp ${TOP}/helloworld/out/helloworld/helloworld ./bin/helloworld
#sudo chmod 755 ./bin/helloworld
#sudo cp ${TOP}/helloworld/out/ta/968c7511-9ace-43fe-8a78faf988096de5.ta ./lib/optee_armtz/968c7511-9ace-43fe-8a78faf988096de5.ta

sudo chmod 444 ./lib/optee_armtz/*.ta

# Make kernel with initramfs. FIXME
cd ${TOP}
make -f optee_build/Makefile build-linux -j9

cd ${BUILD_DIR}
sudo umount -f ${MOUNT_DIR}
#sudo gzip -9 -f ${OPTEE_RFS}
sudo rm -rf ${OPTEE_RFS} ${MOUNT_DIR}
