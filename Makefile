# Makefile for nexell boot firmware
#
# 'make help' for details

SHELL = /bin/bash
CURL = curl -L
BL33_UEFI = 0
PLAT_UART_BASE ?= 0xC00A3000
PLAT_DRAM_SIZE ?= 1024
BL31_ON_SRAM = 1

ifeq ($(V),1)
  Q :=
  ECHO := @:
else
  Q := @
  ECHO := @echo
endif

.PHONY: _all
_all:
	$(Q)set -e ; cd .. ;
	$(Q)if [ ! -L linux ] ; then ln -s linux-artik7 linux ; fi
	$(Q)$(MAKE) -f optee_build/Makefile all $(filter-out _all,$(MAKECMDGOALS))
	$(Q)if [ ! -L u-boot ] ; then ln -s ../u-boot u-boot ; fi

ifneq (,$(USE_SECOS))
all: build-lloader build-fip build-linux build-singleimage \
	build-fip-loader build-fip-secure build-fip-nonsecure
else
all: build-lloader build-fip build-linux build-optee-rfs build-singleimage \
	build-fip-loader build-fip-secure build-fip-nonsecure
endif
pre_clean:
	$(Q)if [ ! -L linux ] ; then ln -s ../kernel linux ; fi
	$(Q)if [ ! -L u-boot ] ; then ln -s ../u-boot u-boot ; fi

post_clean:
	$(Q)if [ -L linux ] ; then rm linux ; fi
	$(Q)if [ -L u-boot ] ; then rm u-boot ; fi
	$(Q)if [ -L buildroot ] ; then rm buildroot ; fi

#clean: clean-bl1-bl2-bl31-fip clean-bl32 clean-bl33 clean-lloader

ifneq (,$(USE_SECOS))
clean: clean-bl1-bl2-bl31-fip clean-lloader
else
clean: clean-bl1-bl2-bl31-fip clean-bl32 clean-lloader

#clean: clean-linux-dtb clean-optee-rfs clean-optee-linuxdriver
clean: clean-optee-rfs
clean: clean-optee-client clean-bl32 clean-aes-perf clean-helloworld
endif
clean: clean-singleimage

cleaner: pre_clean clean post_clean

distclean: cleaner

help:
	@echo "Makefile for artik710_raptor board u-boot firmware/kernel"
	@echo
	@echo "- Run 'make' to build the following images:"
	@echo "  LLOADER = $(LLOADER) with:"
	@echo "      [BL1 = $(BL1)]"
	@echo "      [l-loader/*.S]"
	@echo "  FIP = $(FIP) with:"
	@echo "      [BL2 = $(BL2)]"
	@echo "      [BL31 = $(BL31)]"
	@echo "      [BL32 = $(BL32)]"
	@echo "      [BL33 = $(BL33)]"
	@echo "  INITRAMFS = $(INITRAMFS) with"
	@echo "      [OPTEE-LINUXDRIVER = $(optee-linuxdriver-files)]"
	@echo "      [OPTEE-CLIENT = optee_client/out/libteec.so*" \
	             "optee_client/out/tee-supplicant/tee-supplicant]"
	@echo "      [OPTEE-TEST = out/usr/local/bin/xtest" \
	             "out/lib/optee_armtz/*.ta]"
	@echo "- 'make clean' removes most files generated by make, except the"
	@echo "downloaded files/tarballs and the directories they were"
	@echo "extracted to."
	@echo "- 'make cleaner' also removes tar directories."
	@echo "- 'make distclean' removes all generated or downloaded files."
	@echo
	@echo "Image files can be built separately with e.g., 'make build-fip'"
	@echo "or 'make build-bl1', and so on. Note: In order to speed up the "
	@echo "build and reduce output when working on a single component,"
	@echo "build-<foo> will NOT invoke build-<bar>."
	@echo "Therefore, if you want to make sure that <bar> is up-to-date,"
	@echo "use 'make build-<foo> build-<bar>'."

ifneq (,$(shell which ccache))
CCACHE = ccache # do not remove this comment or the trailing space will go
endif

filename = $(lastword $(subst /, ,$(1)))

# Read stdin, expand ${VAR} environment variables, output to stdout
# http://superuser.com/a/302847
define expand-env-var
awk '{while(match($$0,"[$$]{[^}]*}")) {var=substr($$0,RSTART+2,RLENGTH -3);gsub("[$$]{"var"}",ENVIRON[var])}}1'
endef

#
# Aarch64 toolchain
#
# If you don't want to download the aarch64 toolchain, comment out
# the next line and set CROSS_COMPILE to your compiler command
CROSS_COMPILE ?= $(CCACHE)aarch64-linux-gnu-

#
# Aarch32 toolchain
#
# If you don't want to download the aarch32 toolchain, comment out
# the next line and set CROSS_COMPILE32 to your compiler command
CROSS_COMPILE32 ?= $(CCACHE)arm-linux-gnueabihf-


#
# U-BOOT
#

BL33 = u-boot-artik7/u-boot.bin


.PHONY: build-bl33
build-bl33:: $(aarch64-linux-gnu-gcc)
build-bl33 $(BL33)::
	$(ECHO) '  BUILD   $@'
	$(Q)set -e ; cd u-boot-artik7 ; \
	    $(MAKE) artik710_raptor_config ; \
	    $(MAKE) CROSS_COMPILE="$(CROSS_COMPILE)"
	$(Q)touch ${BL33}

clean-bl33:
	$(ECHO) '  CLEAN   $@'
	$(Q) $(MAKE) -C u-boot-artik7 clean

#
# ARM Trusted Firmware
#

ATF_DEBUG = 0
ifeq ($(ATF_DEBUG),1)
ATF = arm-trusted-firmware/build/s5p6818/debug
else
ATF = arm-trusted-firmware/build/s5p6818/release
endif
BL1 = $(ATF)/bl1.bin
BL2 = $(ATF)/bl2.bin
#BL30 = mcuimage.bin
BL31 = $(ATF)/bl31.bin
# Comment out to not include OP-TEE OS image in fip.bin
ifneq (,$(USE_SECOS))
$(ECHO) '  Set BL32 : secos.bin'
BL32 = secos/out/kernel-install/secos.bin
else
BL32 = optee_os/out/arm-plat-s5p6818/core/tee.bin
endif
FIP = $(ATF)/fip.bin
FIPloader = $(ATF)/fip-loader.bin
FIPsecure = $(ATF)/fip-secure.bin
FIPnonsecure = $(ATF)/fip-nonsecure.bin

ARMTF_FLAGS := PLAT=s5p6818 DEBUG=$(ATF_DEBUG)
ARMTF_FLAGS += LOG_LEVEL=10
ARMTF_EXPORTS := NEED_BL30=no BL30=$(PWD)/$(BL30) BL33=$(PWD)/$(BL33) #CFLAGS=""
ifneq (,$(BL32))
ifneq (,$(USE_SECOS))
$(ECHO) '  Set spd : secureosd'
ARMTF_FLAGS += SPD=secureosd
else
ARMTF_FLAGS += SPD=opteed
endif
ARMTF_EXPORTS += BL32=$(PWD)/$(BL32)
endif
ifneq (,$(PLAT_UART_BASE))
ARMTF_FLAGS += PLAT_UART_BASE="$(PLAT_UART_BASE)"
endif
ifneq (,$(PLAT_DRAM_SIZE))
ARMTF_FLAGS += PLAT_DRAM_SIZE="$(PLAT_DRAM_SIZE)"
endif
ifneq (,$(BL31_ON_SRAM))
ARMTF_FLAGS += BL31_ON_SRAM="$(BL31_ON_SRAM)"
endif

define arm-tf-make
        $(ECHO) '  BUILD   build-$(strip $(1)) [$@]'
        +$(Q)export $(ARMTF_EXPORTS) ; \
	    $(MAKE) -C arm-trusted-firmware $(ARMTF_FLAGS) $(1)
endef

.PHONY: build-bl1
build-bl1 $(BL1): $(aarch64-linux-gnu-gcc)
	$(call arm-tf-make, bl1) CROSS_COMPILE="$(CROSS_COMPILE)"

.PHONY: build-bl2
build-bl2 $(BL2): $(aarch64-linux-gnu-gcc)
	$(call arm-tf-make, bl2) CROSS_COMPILE="$(CROSS_COMPILE)"

.PHONY: build-bl31
build-bl31 $(BL31): $(aarch64-linux-gnu-gcc)
	$(call arm-tf-make, bl31) CROSS_COMPILE="$(CROSS_COMPILE)"


ifneq ($(filter all build-bl2,$(MAKECMDGOALS)),)
tf-deps += build-bl2
endif
ifneq ($(filter all build-bl31,$(MAKECMDGOALS)),)
tf-deps += build-bl31
endif
ifneq (,$(USE_SECOS))
# Nothing to do
else
ifneq ($(filter all build-bl32,$(MAKECMDGOALS)),)
tf-deps += build-bl32
endif
endif
tf-deps += build-bl33

tf-deps-loader += build-bl1 build-bl2 build-lloader
tf-deps-secure += build-bl31
ifneq (,$(USE_SECOS))
# Nothing to do
else
tf-deps-secure += build-bl32
endif
tf-deps-nonsecure += build-bl33

.PHONY: build-fip
build-fip:: $(tf-deps)
build-fip $(FIP)::
	$(call arm-tf-make, fip) CROSS_COMPILE="$(CROSS_COMPILE)"

.PHONY: build-fip-split
build-fip-split:: $(tf-deps-loader) $(tf-deps-secure) $(tf-deps-nonsecure)
build-fip-split::
	$(call arm-tf-make, fip-loader) CROSS_COMPILE="$(CROSS_COMPILE)"
ifneq (,$(USE_SECOS))
	$(call arm-tf-make, fip-secure) USE_SECOS=1 CROSS_COMPILE="$(CROSS_COMPILE)"
else
	$(call arm-tf-make, fip-secure) CROSS_COMPILE="$(CROSS_COMPILE)"
endif
	$(call arm-tf-make, fip-nonsecure) CROSS_COMPILE="$(CROSS_COMPILE)"

.PHONY: build-fip-loader
build-fip-loader:: $(tf-deps-loader)
build-fip-loader $(FIPloader)::
	$(call arm-tf-make, fip-loader) CROSS_COMPILE="$(CROSS_COMPILE)"

.PHONY: build-fip-secure
build-fip-secure:: $(tf-deps-secure)
build-fip-secure $(FIPsecure)::
ifneq (,$(USE_SECOS))
	$(call arm-tf-make, fip-secure) USE_SECOS=1 CROSS_COMPILE="$(CROSS_COMPILE)"
else
	$(call arm-tf-make, fip-secure) CROSS_COMPILE="$(CROSS_COMPILE)"
endif
.PHONY: build-fip-nonsecure
build-fip-nonsecure:: $(tf-deps-nonsecure)
build-fip-nonsecure $(FIPnonsecure)::
	$(call arm-tf-make, fip-nonsecure) CROSS_COMPILE="$(CROSS_COMPILE)"

clean-bl1-bl2-bl31-fip:
	$(ECHO) '  CLEAN   edk2/BaseTools'
	$(Q)export $(ARMTF_EXPORTS) ; \
	    $(MAKE) -C arm-trusted-firmware $(ARMTF_FLAGS) clean

#
# l-loader
#

LLOADER = l-loader/l-loader.bin

lloader-deps += build-bl1

# FIXME: adding $(BL1) as a dependency [after $(LLOADER)::] breaks
# parallel build (-j) because the same rule is run twice simultaneously
# $ make -j9 build-bl1 build-lloader
#   BUILD   build-bl1 # $@ = build-bl1
#   BUILD   build-bl1 # $@ = arm-trusted-firmware/build/.../bl1.bin
#   DEPS    build/s5p6818/debug/bl31/bl31.ld.d
#   DEPS    build/s5p6818/debug/bl31/bl31.ld.d
.PHONY: build-lloader
build-lloader:: $(lloader-deps) $(arm-linux-gnueabihf-gcc)
build-lloader $(LLOADER)::
	$(ECHO) '  BUILD   build-lloader'
	$(Q)$(MAKE) -C l-loader BL1=$(PWD)/$(BL1) PLAT_DRAM_SIZE=$(PLAT_DRAM_SIZE) \
		CROSS_COMPILE="$(CROSS_COMPILE32)" l-loader.bin

clean-lloader:
	$(ECHO) '  CLEAN   $@'
	$(Q)$(MAKE) -C l-loader clean

#
# Linux/DTB
#

# FIXME: 'make build-linux' needlessy (?) recompiles a few files (efi.o...)
# each time it is run

LINUX = linux/arch/arm64/boot/Image
DTB = nexell/s5p6818-artik710-raptor.dtb
DTB2 = linux/arch/arm64/boot/dts/$(DTB)
# Config fragments to merge with the default kernel configuration
KCONFIGS += linux/arch/arm64/configs/s5p6818_drone_defconfig

ifneq ($(filter all build-linux,$(MAKECMDGOALS)),)
linux-build-deps += build-dtb
endif

.PHONY: build-linux
build-linux:: $(linux-build-deps) $(aarch64-linux-gnu-gcc)
build-linux $(LINUX):: linux/.config
	$(ECHO) '  BUILD   build-linux'
	$(Q)optee_build/modify_linux_config.sh
	$(Q)flock .linuxbuildinprogress $(MAKE) -C linux ARCH=arm64 LOCALVERSION= Image

build-dtb:: $(aarch64-linux-gnu-gcc)
build-dtb $(DTB):: linux/.config
	$(ECHO) '  BUILD   build-dtb'
	$(Q)flock .linuxbuildinprogress $(MAKE) -C linux ARCH=arm64 $(DTB)

linux/.config: $(KCONFIGS)
	$(ECHO) '  BUILD   $@'
#	$(Q)cp $(KCONFIGS) linux/.config
	$(Q)make -C linux ARCH=arm64 s5p6818_drone_defconfig

linux/usr/gen_init_cpio: linux/.config
	$(ECHO) '  BUILD   $@'
	$(Q)$(MAKE) -C linux/usr ARCH=arm64 gen_init_cpio

clean-linux-dtb:
	$(ECHO) '  CLEAN   $@'
	$(Q)$(MAKE) -C linux-artik7 ARCH=arm64 clean
	$(Q)rm -f linux-artik7/.config
	$(Q)rm -f .linuxbuildinprogress

#
# Initramfs
#

INITRAMFS = optee-rfs.gz

ifneq (,$(USE_SECOS))
# Nothing to do
else
ifneq ($(filter all build-optee-linuxdriver,$(MAKECMDGOALS)),)
optee-rfs-deps += build-optee-linuxdriver
endif
ifneq ($(filter all build-optee-client,$(MAKECMDGOALS)),)
optee-rfs-deps += build-optee-client
endif
#ifneq ($(filter all build-aes-perf,$(MAKECMDGOALS)),)
#optee-rfs-deps += build-aes-perf
#endif
#ifneq ($(filter all build-helloworld,$(MAKECMDGOALS)),)
#optee-rfs-deps += build-helloworld
#endif
ifneq ($(filter all build-optee-test,$(MAKECMDGOALS)),)
optee-rfs-deps += build-optee-test
endif
endif

.PHONY: build-optee-rfs
build-optee-rfs:: $(optee-rfs-deps)
build-optee-rfs:: optee_build/build_optee_rfs.sh
	$(ECHO) "  GEN    $(INITRAMFS)"
	$(Q)optee_build/build_optee_rfs.sh
	$(call build-linux)

clean-optee-rfs:
	$(ECHO) "  CLEAN  $@"
	$(Q)rm -f $(INITRAMFS)


#
# build single binary
#

SINGLE_IMG = singleimage.bin

DRAM_BASE=0x7fe00000
ifneq (,$(PLAT_DRAM_SIZE))
ifeq (${PLAT_DRAM_SIZE},2048)
DRAM_BASE=0xbfe00000
else ifeq (${PLAT_DRAM_SIZE},512)
DRAM_BASE=0x5fe00000
else
DRAM_BASE=0x7fe00000
endif
endif

LOADER_SIZE=256
ifneq (,$(PLAT_LOADER_SIZE))
LOADER_SIZE=$(PLAT_LOADER_SIZE)
endif

SINGLE_PARAM="-b $(DRAM_BASE) -m $(ATF_DEBUG) -s $(LOADER_SIZE)"
singleimage-deps += build-fip-split

.PHONY: build-singleimage
build-singleimage:: $(singleimage-deps)
build-singleimage:: optee_build/gen_singleimage.sh
	$(ECHO) "  GEN    $(SINGLE_IMG)"
	$(Q)optee_build/gen_singleimage.sh $(SINGLE_PARAM)

clean-singleimage:
	$(ECHO) "  CLEAN  $@"
	$(Q)rm -f $(SINGLE_IMG)



#
# OP-TEE Linux driver
#

optee-linuxdriver-files := optee_linuxdriver/optee.ko \
                           optee_linuxdriver/optee_armtz.ko

ifneq ($(filter all build-linux,$(MAKECMDGOALS)),)
optee-linuxdriver-deps += build-linux
endif

.PHONY: build-optee-linuxdriver
build-optee-linuxdriver:: $(optee-linuxdriver-deps)
build-optee-linuxdriver $(optee-linuxdriver-files):: $(aarch64-linux-gnu-gcc)
	$(ECHO) '  BUILD   build-optee-linuxdriver'
	$(Q)$(MAKE) -C linux-artik7 \
	   ARCH=arm64 \
	   LOCALVERSION= \
	   M=$(PWD)/optee_linuxdriver \
	   modules

clean-optee-linuxdriver:
	$(ECHO) '  CLEAN   $@'
	$(Q)$(MAKE) -C linux-artik7 \
	   ARCH=arm64 \
	   LOCALVERSION= \
	   M=$(PWD)/optee_linuxdriver \
	   clean

#
# OP-TEE client library and tee-supplicant executable
#

.PHONY: build-optee-client
build-optee-client: $(aarch64-linux-gnu-gcc)
	$(ECHO) '  BUILD   $@'
	$(Q)$(MAKE) -C optee_client CROSS_COMPILE="$(CROSS_COMPILE)"

clean-optee-client:
	$(ECHO) '  CLEAN   $@'
	$(Q)$(MAKE) -C optee_client clean

#
# OP-TEE OS
#

optee-os-flags := CROSS_COMPILE="$(CROSS_COMPILE32)" PLATFORM=s5p6818
optee-os-flags += DEBUG=0
optee-os-flags += CFG_TEE_CORE_LOG_LEVEL=1 # 0=none 1=err 2=info 3=debug 4=flow
#optee-os-flags += CFG_WITH_PAGER=y
#optee-os-flags += CFG_TEE_TA_LOG_LEVEL=3
ifneq (,$(PLAT_UART_BASE))
optee-os-flags += PLAT_UART_BASE="$(PLAT_UART_BASE)"
endif
ifneq (,$(PLAT_DRAM_SIZE))
optee-os-flags += PLAT_DRAM_SIZE="$(PLAT_DRAM_SIZE)"
endif

# 64-bit TEE Core
# FIXME: Compiler bug? xtest 4002 hangs (endless loop) when:
# - TEE Core is 64-bit (OPTEE_64BIT=1 below) and compiler is aarch64-linux-gnu-gcc
#   4.9.2-10ubuntu13, and
# - DEBUG=0, and
# - 32-bit user libraries are built with arm-linux-gnueabihf-gcc 4.9.2-10ubuntu10
# Set DEBUG=1, or set $(arm-linux-gnueabihf-) to build user code with:
#   'arm-linux-gnueabihf-gcc (crosstool-NG linaro-1.13.1-4.8-2013.08 - Linaro GCC 2013.08)
#    4.8.2 20130805 (prerelease)'
# or with:
#   'arm-linux-gnueabihf-gcc (Linaro GCC 2014.11) 4.9.3 20141031 (prerelease)'
# and the problem disappears.
OPTEE_64BIT ?= 1
ifeq ($(OPTEE_64BIT),1)
optee-os-flags += CFG_ARM64_core=y CROSS_COMPILE_core="$(CROSS_COMPILE)"
endif

.PHONY: build-bl32
build-bl32:: $(aarch64-linux-gnu-gcc) $(arm-linux-gnueabihf-gcc)
build-bl32::
	$(ECHO) '  BUILD   $@'
	$(Q)$(MAKE) -C optee_os $(optee-os-flags)

.PHONY: clean-bl32
clean-bl32:
	$(ECHO) '  CLEAN   $@'
	$(Q)$(MAKE) -C optee_os $(optee-os-flags) clean


#
# OP-TEE tests (xtest)
#


all: build-optee-test
clean: clean-optee-test

optee-test-flags := CROSS_COMPILE_HOST="$(CROSS_COMPILE)" \
		    CROSS_COMPILE_TA="$(CROSS_COMPILE32)" \
		    TA_DEV_KIT_DIR=$(PWD)/optee_os/out/arm-plat-s5p6818/export-user_ta \
		    O=$(PWD)/optee_test/out #CFG_TEE_TA_LOG_LEVEL=3

ifneq (,$(USE_SECOS))
# Nothing to do
else
ifneq ($(filter all build-bl32,$(MAKECMDGOALS)),)
optee-test-deps += build-bl32
endif
ifneq ($(filter all build-optee-client,$(MAKECMDGOALS)),)
optee-test-deps += build-optee-client
endif
endif

.PHONY: build-optee-test
build-optee-test:: $(optee-test-deps)
build-optee-test:: $(aarch64-linux-gnu-gcc)
	$(ECHO) '  BUILD   $@'
	$(Q)$(MAKE) -C optee_test $(optee-test-flags)

# FIXME:
# No "make clean" in optee_test: fails if optee_os has been cleaned
# previously.
clean-optee-test:
	$(ECHO) '  CLEAN   $@'
	$(Q)rm -rf optee_test/out

#
# aes-perf (AES crypto performance test)
#

aes-perf-flags := CROSS_COMPILE_HOST="$(CROSS_COMPILE)" \
		  CROSS_COMPILE_TA="$(CROSS_COMPILE32)" \
		  TA_DEV_KIT_DIR=$(PWD)/optee_os/out/arm-plat-s5p6818/export-user_ta \

ifneq (,$(USE_SECOS))
# Nothing to do
else
ifneq ($(filter all build-bl32,$(MAKECMDGOALS)),)
aes-perf-deps += build-bl32
endif
ifneq ($(filter all build-optee-client,$(MAKECMDGOALS)),)
aes-perf-deps += build-optee-client
endif
endif

.PHONY: build-aes-perf
build-aes-perf:: $(aes-perf-deps)
build-aes-perf:: $(aarch64-linux-gnu-gcc)
	$(ECHO) '  BUILD   $@'
	$(Q)$(MAKE) -C aes-perf $(aes-perf-flags)

clean-aes-perf:
	$(ECHO) '  CLEAN   $@'
	$(Q)rm -rf aes-perf/out

#
# helloworld
#

helloworld-flags := CROSS_COMPILE_HOST="$(CROSS_COMPILE)" \
		    CROSS_COMPILE_TA="$(CROSS_COMPILE32)" \
		    TA_DEV_KIT_DIR=$(PWD)/optee_os/out/arm-plat-s5p6818/export-user_ta \

ifneq (,$(USE_SECOS))
# Nothing to do
else
ifneq ($(filter all build-bl32,$(MAKECMDGOALS)),)
helloworld-deps += build-bl32
endif
ifneq ($(filter all build-optee-client,$(MAKECMDGOALS)),)
helloworld-deps += build-optee-client
endif
endif

.PHONY: build-helloworld
build-helloworld:: $(helloworld-deps)
build-helloworld:: $(aarch64-linux-gnu-gcc)
	$(ECHO) '  BUILD   $@'
	$(Q)$(MAKE) -C helloworld $(helloworld-flags)

clean-helloworld:
	$(ECHO) '  CLEAN   $@'
	$(Q)rm -rf helloworld/out
