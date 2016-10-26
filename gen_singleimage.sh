#!/bin/bash

VERBOSE=false

TOP=`pwd`
BUILD_DIR="${TOP}/optee_build"
RESULT=${BUILD_DIR}/result


MERGE_TYPE=fixed

BASE_ADDR=0x7fe00000
LOAD_ADDR=0x40000000

LLOADER_FILE=${TOP}/l-loader/l-loader.bin
BL1=bl1.bin
FIP_RESULT=
FIP_FILE=
LOADER_FILE=
HEADER_FILE=${RESULT}/hdr.bin
SINGLE_FILE=${RESULT}/singleimage.bin
DUMMY_FILE=${RESULT}/dummy.bin
LOADER_SIZE=256			# in KB

#is debug mode
DEBUG=0

FIP_MERGE=fip-loader.bin
FIP_LOADER=
FIP_SECURE=
FIP_NONSECURE=
 
function usage()
{
	echo "Usage: ./gen_singleimage.sh -l LOADADDR \
		-e LLOADER_BIN -f FIP_BIN -s FIPLOADER_SIZE -b BASEADDR -m DEBUG"
	echo "        -s FIP_LOADER_SIZE (in KB)"
}

function prepare()
{
#	if [ ! -f $FIP_FILE ]; then
#		echo "no fip file"
#		exit 2
#	fi

#	if [ ! -f $LLOADER_FILE ]; then
#		echo "no l-loader file"
#		exit 3
#	fi

	if [ ! -d ${RESULT} ]; then
		mkdir -p ${RESULT}
	fi
}

function parse_args()
{
	TEMP=`getopt -o "m:b:f:l:s:hv" -- "$@"`
	eval set -- "$TEMP"

	while true; do
		case "$1" in
			-f ) FIP_FILE=$2; shift 2 ;;
			-e ) LLOADER_FILE=$2; shift 2;;
			-l ) LOAD_ADDR=$2; shift 2 ;;
			-b ) BASE_ADDR=$2; shift 2 ;;
			-s ) LOADER_SIZE=$2; shift 2 ;;
			-m ) DEBUG=$2; shift 2 ;;
			-h ) usage; exit 1 ;;
			-v ) VERBOSE=true; shift 1 ;;
			-- ) break ;;
			*  ) echo "invalid option $1"; usage; exit 1 ;;
		esac
	done

	if [ ${DEBUG} == 1 ]; then
		FIP_RESULT=${TOP}/arm-trusted-firmware/build/s5p6818/debug
	else
		FIP_RESULT=${TOP}/arm-trusted-firmware/build/s5p6818/release
	fi

	FIP_FILE=${FIP_RESULT}/fip.bin
	LOADER_FILE=${FIP_RESULT}/bl1.bin

	FIP_LOADER=${FIP_RESULT}/fip-loader.bin
	FIP_SECURE=${FIP_RESULT}/fip-secure.bin
	FIP_NONSECURE=${FIP_RESULT}/fip-nonsecure.bin
}

function write_header()
{
        if [ ${MERGE_TYPE} != "fixed" ]; then
		FIP_SIZE=`stat --printf="%s" $FIP_FILE`
		LL_SIZE=`stat --printf="%s" $LLOADER_FILE`

		FIP_START=$(($BASE_ADDR + 0x800 + $LL_SIZE))
		#echo -e $(printf "%08x" $xxx)

		./rev.sh $(printf "%08x" $FIP_START) | xxd -r -p >  ${HEADER_FILE}
		./rev.sh $(printf "%08x" $FIP_SIZE)  | xxd -r -p >> ${HEADER_FILE}
		./rev.sh $(printf "%08x" $LOAD_ADDR) | xxd -r -p >> ${HEADER_FILE}
		./rev.sh $(printf "%08x" 0x0) | xxd -r -p >> ${HEADER_FILE}
	fi
}

function merge_bins()
{
: << END_COMMENT
        if [ ${MERGE_TYPE} == "fixed" ]; then
		dd if=/dev/zero ibs=1024 count=2050 of=${SINGLE_FILE}
		dd if=${FIP_FILE} of=${SINGLE_FILE} conv=notrunc
		cat ${LLOADER_FILE} >> ${SINGLE_FILE}
	else
		dd if=/dev/zero ibs=2048 count=1 of=${DUMMY_FILE}
		cat ${HEADER_FILE}  >  ${SINGLE_FILE}
		cat ${DUMMY_FILE}   >> ${SINGLE_FILE}
		cat ${LLOADER_FILE} >> ${SINGLE_FILE}
		cat ${FIP_FILE}     >> ${SINGLE_FILE}
        fi
END_COMMENT
}

function post()
{
	# (LOADER_SIZE - HEADER 1KB) + SPACE 2KB + L-LOADER(l-loader + ATF bl1)
	local loader_realsize=$((${LOADER_SIZE}-1+2))

	mkdir -p ${RESULT}/tmpdir
	rm -rf ${RESULT}/tmpdir/*

	# fip-XXX.bin
	\cp -a ${FIP_SECURE} ${RESULT}
	\cp -a ${FIP_NONSECURE} ${RESULT}

	pushd "${RESULT}/tmpdir"

	# BL1
	#\cp -a ${LOADER_FILE} ${BL1}
	# BL2
	\cp -a ${FIP_LOADER} .
	dd if=/dev/zero ibs=1024 count=${loader_realsize} of=merged_loader
	dd if=${FIP_LOADER} of=merged_loader conv=notrunc
	cat ${LLOADER_FILE} >> merged_loader
	\cp merged_loader ../${FIP_MERGE}

	popd
	rm -rf ${RESULT}/tmpdir
}

parse_args $@


prepare

#write_header

#merge_bins

post

exit 0
