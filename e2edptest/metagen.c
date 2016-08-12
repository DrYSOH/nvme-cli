/*
 Copyright 2016 SK telecom Co., Ltd.

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 MA  02110-1301, USA.

   Author: Yongseok Oh <yongseok.oh@sk.com>

   Description:
     Metadata Generator for End to End Data Protection using NVMe CLI.
*/
#include <stdio.h>
#include <fcntl.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <endian.h>

short crc_t10dif_generic(const unsigned char *buffer, unsigned int len);

struct metadata_prot_info{
    unsigned short guard;
    unsigned short app_tag;
    unsigned int ref_tag;
};

unsigned char sector_buf[4096];
unsigned char meta_buf[8];

int main(int argc, char **argv)
{
    char *data_filename;
    char *meta_filename;
    int data_fd;
    int meta_fd;
    int ret;
    int sec_size;
    unsigned short crc16;

    struct metadata_prot_info *mpi = (struct metadata_prot_info *)meta_buf;

    if(argc < 6)
    {
        fprintf(stderr, " invalid options ... \n");
        return -1;
    }

    sec_size = atoi(argv[1]);
    data_filename = argv[2];
    meta_filename = argv[3];
    fprintf(stderr, " data filename = %s\n meta filename = %s \n", data_filename, meta_filename);

    data_fd = open(data_filename, O_RDONLY);
    if(data_fd < 0){
        fprintf(stderr, " file open error = %s \n", data_filename);
        return -1;
    }

    meta_fd = open(meta_filename, O_WRONLY|O_CREAT, 0644);
    if(meta_fd < 0){
        fprintf(stderr, " file open error = %s \n", meta_filename);
        return -1;
    }

    ret = read(data_fd, sector_buf, sec_size);
    if(ret < 0){
        fprintf(stderr, " read error = %d \n", ret);
        return -1;
    }

    //printf(" crc %X crct10 %X \n", (short)crc16(sector_buf, 512), (short) (0xffff & crc_t10dif_generic(sector_buf, 512)));

    crc16 = crc_t10dif_generic(sector_buf, sec_size);

    mpi->guard = htobe16(crc16);
    mpi->app_tag = htobe16(atoi(argv[4]));
    mpi->ref_tag = htobe32(atoi(argv[5]));
    
    ret = write(meta_fd, meta_buf, 8);
    if(ret < 0){
        fprintf(stderr, " write error = %d \n", ret);
        return -1;
    }

    close(data_fd);
    close(meta_fd);
        
    return 0;
}
