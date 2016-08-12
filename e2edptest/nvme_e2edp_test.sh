#!/bin/bash
#
# Copyright 2016 SK telecom Co., Ltd.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA  02110-1301, USA.
#
#   Author: Yongseok Oh <yongseok.oh@sk.com>
#
#   Description:
#     Test Suite for End to End Data Protection using NVMe CLI.
#

NVME_DEVICE=/dev/nvme0n1

FILE_DATA_NAME_ORG=file.data.org
FILE_DATA_NAME_READ=file.data.read
META_DATA_NAME_ORG=meta.data.org
META_DATA_NAME_READ=meta.data.read

FORMAT=true

# LBA Sector Format
LBAF_512=0 # unsupported 
LBAF_520=1
LBAF_4096=2 # unsupported
LBAF_4104=3

# Protection Type for NVMe Format
PI_TYPE0=0 # No Protection Information
PI_TYPE1=1 # Guard + Ref Tags Checking (Disable protection checking if the protection app tag is 0xFFFF)
PI_TYPE2=2 # Gaurd + Ref Tags Checking 
PI_TYPE3=3 # Guard Tag Checking (Disable protection checking if the protection app tag and ref tag are 0xFFFF and 0xFFFF_FFFF, respectively 

# Protection Info Location Last/First 8 Bytes of metadata
PIL_LAST=0
PIL_FIRST=1
PIL=$PIL_LAST

# The metadata is transffered
MS_SEP=0 # as part of a seperate buffer
MS_EXT=1 # as part of an extended data LBA


PRACT_TRANSFER=0
PRACT_INSERT=1

function nvme_format(){
    if $FORMAT ; then
        echo "nvme format (with lbaf=$LBAF pi=$PI pil=$PIL ms=$MS)"
        nvme format $NVME_DEVICE --lbaf=$LBAF --pi=$PI --pil=$PIL --ms=$MS
    fi
}

function nvme_sector_size_set(){
    if [ $LBAF -eq $LBAF_520 ]; then
        if [ $MS -eq $MS_SEP ]; then
            SECTOR_SIZE=512
            META_SIZE=8
        else
            SECTOR_SIZE=520
            META_SIZE=8
        fi
    else
        if [ $MS -eq $MS_SEP ]; then
            SECTOR_SIZE=4096
            META_SIZE=8
        else
            SECTOR_SIZE=4104
            META_SIZE=8
        fi
    fi
    echo Sector Size $SECTOR_SIZE Meta Size $META_SIZE
}

function del_file() {
    if [ -e $FILE_DATA_NAME_ORG ]; then
        rm $FILE_DATA_NAME_ORG > /dev/null
    fi

    if [ -e $FILE_DATA_NAME_READ ]; then
        rm $FILE_DATA_NAME_READ > /dev/null
    fi

    if [ -e $META_DATA_NAME_ORG ]; then
        rm $META_DATA_NAME_ORG > /dev/null
    fi

    if [ -e $META_DATA_NAME_READ ]; then
        rm $META_DATA_NAME_READ > /dev/null
    fi
}

function gen_file(){

    if [ $LBAF -eq $LBAF_520 ]; then
        SEC_SIZE=512
    else
        SEC_SIZE=4096
    fi

    dd if=/dev/urandom of=$FILE_DATA_NAME_ORG bs=$SEC_SIZE count=1 2> /dev/null
    ./metagen $SEC_SIZE $FILE_DATA_NAME_ORG $META_DATA_NAME_ORG $APPTAG $SEC_NO 2> /dev/null

    if [ $MS -eq $MS_EXT ]; then
        if [ ! -e $META_DATA_NAME_ORG ]; then
            echo File $META_DATA_NAME_ORG does not exist.
            return 1
        fi
        cat $META_DATA_NAME_ORG >> $FILE_DATA_NAME_ORG
    fi
}

function data_diff(){
    if [ $MS -eq $MS_SEP ]; then
        diff $META_DATA_NAME_ORG $META_DATA_NAME_READ
        ret=$?
        if [ $ret -ne 0 ]; then 
            echo "metadata missmatch has been found"
            hexdump $META_DATA_NAME_ORG
            hexdump $META_DATA_NAME_READ
            return 1
        fi
    fi

    diff $FILE_DATA_NAME_ORG $FILE_DATA_NAME_READ
    ret=$?
    if [ $ret -ne 0 ]; then 
        echo "data missmatch has been found"
        hexdump $FILE_DATA_NAME_ORG
        hexdump $FILE_DATA_NAME_READ
        return 1
    fi
}

function nvme_write_read()
{
    echo Write Sector $SEC_NO Data Size $SECTOR_SIZE Meta Size $META_SIZE PRINFO $PRINFO
    # write command to store data and metadata 
    nvme write $NVME_DEVICE --start-block=$SEC_NO --block-count=0 --data-size=$SECTOR_SIZE --metadata-size=$META_SIZE --data=$FILE_DATA_NAME_ORG --metadata=$META_DATA_NAME_ORG --ref-tag=$REFTAG --app-tag=$APPTAG  --app-tag-mask=$APPTAG_MASK --prinfo=$PRINFO
#nvme write $NVME_DEVICE --start-block=$SEC_NO --block-count=0 --data-size=$SECTOR_SIZE --metadata-size=$META_SIZE --data=$FILE_DATA_NAME_ORG --metadata=$META_DATA_NAME_ORG --ref-tag=$REFTAG --app-tag=$APPTAG  --app-tag-mask=$APPTAG_MASK --prinfo=$PRINFO 2> /dev/null
    ret=$?
    if [ $ret -ne 0 ]; then 
        return 1
    fi

    echo Read Sector $SEC_NO Data Size $SECTOR_SIZE Meta Size $META_SIZE PRINFO $PRINFO
    # read command to transfer data and metadata to the host
    nvme read $NVME_DEVICE --start-block=$SEC_NO --block-count=0 --data-size=$SECTOR_SIZE --metadata-size=$META_SIZE --data=$FILE_DATA_NAME_READ --metadata=$META_DATA_NAME_READ --ref-tag=$REFTAG --app-tag=$APPTAG  --app-tag-mask=$APPTAG_MASK --prinfo=$PRINFO
#nvme read $NVME_DEVICE --start-block=$SEC_NO --block-count=0 --data-size=$SECTOR_SIZE --metadata-size=$META_SIZE --data=$FILE_DATA_NAME_READ --metadata=$META_DATA_NAME_READ --ref-tag=$REFTAG --app-tag=$APPTAG  --app-tag-mask=$APPTAG_MASK --prinfo=$PRINFO 2>/dev/null
    ret=$?
    if [ $ret -ne 0 ]; then 
        return 1
    fi

#if [ $PI -eq $PI_TYPE0 ]; then
    if [ $PRACT == $PRACT_TRANSFER ]; then
        data_diff
    fi

	return 0
}

function nvme_gen_req(){
    if [ $PI -ne $PI_TYPE0 ]; then
        PRINFO_REF=1    # ref tag checking
        PRINFO_APP=2    # app tag checking
        PRINFO_GUARD=4  # guard checking
        if [ $PRACT == $PRACT_INSERT ]; then
            PRINFO_PRACT=8  # Protection Information Action (PRACT) (insert on write or strip on read)
        else
            PRINFO_PRACT=0  # Protection Information ACTION (PRACT) (Just Transfer from/to the host)
        fi
    else
        PRINFO_REF=0    # ref tag checking
        PRINFO_APP=0    # app tag checking
        PRINFO_GUARD=0  # guard checking
        PRINFO_PRACT=0  # Protection Information ACTION (PRACT) (Just Transfer from/to the host)
    fi

    PRINFO=$((PRINFO_REF + PRINFO_APP + PRINFO_GUARD + PRINFO_PRACT))

    echo "Gen requests (with PRACT $PRINFO_PRACT Guard $PRINFO_GUARD App $PRINFO_APP Ref $PRINFO_REF)"

	for((SEC_NO = 1; SEC_NO < SEC_COUNT + 1; SEC_NO++)) 
	do
        APPTAG=8
        APPTAG_MASK=8
        REFTAG=$SEC_NO

        del_file

        gen_file

        nvme_write_read
	done

    if [ $? -ne 0 ]; then 
        return $?
    fi
}

function nvme_module_reload(){
    echo NMVe Module Reloading for namespace_id update
    rmmod nvme
    modprobe nvme 
}

LBAF_SET=($LBAF_520 $LBAF_4104)
PRACT_SET=($PRACT_TRANSFER $PRACT_INSERT)
MS_SET=($MS_SEP $MS_EXT)
PI_SET=($PI_TYPE0 $PI_TYPE1 $PI_TYPE2 $PI_TYPE3)

SEC_COUNT=16 # Total Sector I/O Count to issue to underlying NVMe SSDs

# build metagen (see metagen.c file for further information)
make clean > /dev/null || exit -1
make > /dev/null || exit -1

nvme_module_reload

TC=0
for LBAF in ${LBAF_SET[@]}
do
    for PRACT in ${PRACT_SET[@]} 
    do
        for MS in ${MS_SET[@]} 
        do
            for PI in ${PI_SET[@]} 
            do
                if [ ! -b $NVME_DEVICE ]; then
                    echo "No such device $NVME_DEVICE"

                    break
                fi

                echo " "
                TC=$((TC + 1))
                echo Test Case $TC: Started

#if [ $TC -ne 7 ]; then
#                    continue
#                fi

                nvme_format

                nvme_module_reload

                nvme_sector_size_set

                nvme_gen_req

                ret=$?
                if [ $ret -ne 0 ]; then 
                    echo Test Case $TC: Failed
                    return 1
                else
                    echo Test Case $TC: Passed Successfully
                fi
            done
        done
    done
done

del_file
