//
//  opendmx.c
//  ArtNetNodeMac
//
//  Created by Toru Nayuki on 2013/11/10.
//  Copyright (c) 2013年 Toru Nayuki. All rights reserved.
//

#include <stdio.h>

#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <unistd.h>
#include <ftd2xx.h>

void panic(const char *panicstr, ...)
{
    char msgbuf[256];
    va_list args;
    va_start(args, panicstr);
    vsnprintf(msgbuf, 256, panicstr, args);
    va_end(args);
    fprintf(stderr, "*panic: %s\n", msgbuf);
    //exit(1);
}

FT_HANDLE opendmx_open(void)
{
    FT_HANDLE fthandle;
    FT_STATUS ftstatus;
    char buf[512];
    ftstatus = FT_ListDevices(0, buf, FT_LIST_BY_INDEX | FT_OPEN_BY_DESCRIPTION);
    if (ftstatus != FT_OK)
        panic("FT_ListDevices %d", ftstatus);
    
    ftstatus = FT_Open(0, &fthandle);
    if (ftstatus != FT_OK)
        panic("FT_Open %d", ftstatus);
/*
    ftstatus = FT_ResetDevice(fthandle);
    if (ftstatus != FT_OK)
        panic("FT_ResetDevice %d", ftstatus);
  */  
    ftstatus = FT_SetBaudRate(fthandle, 250000);
    if (ftstatus != FT_OK)
        panic("FT_SetBaudRate %d", ftstatus);
    
    ftstatus = FT_SetDataCharacteristics(fthandle, FT_BITS_8, FT_STOP_BITS_2, FT_PARITY_NONE);
    if (ftstatus != FT_OK)
        panic("FT_SetDataCharacteristics %d", ftstatus);
    
    ftstatus = FT_SetFlowControl(fthandle, FT_FLOW_NONE, 0, 0);
    if (ftstatus != FT_OK)
        panic("FT_SetFlowControl %d", ftstatus);
    
    ftstatus = FT_ClrRts(fthandle);
    if (ftstatus != FT_OK)
        panic("CrlRts %d", ftstatus);
    
    return fthandle;
}

void opendmx_send_frame(FT_HANDLE fthandle, unsigned numchannels,
                        uint8_t *buf)
{
    FT_STATUS ftstatus;
    DWORD num;
    int startcode = 0;
/*
    ftstatus = FT_Purge(fthandle, FT_PURGE_TX);
    if (ftstatus != FT_OK)
        panic("FT_Purge %d", ftstatus);

    ftstatus = FT_Purge(fthandle, FT_PURGE_RX);
    if (ftstatus != FT_OK)
        panic("FT_Purge %d", ftstatus);
*/
    ftstatus = FT_SetBreakOn(fthandle);
    if (ftstatus != FT_OK)
        panic("SetBreakOn %d", ftstatus);
    
    usleep(176);
    
    ftstatus = FT_SetBreakOff(fthandle);
    if (ftstatus !=FT_OK)
        panic("SetBreakOff %d", ftstatus);
    
    usleep(12);

    ftstatus = FT_Write(fthandle, &startcode, 1, &num);
    if ((ftstatus != FT_OK) || (num != 1))
        panic("FT_Write %d %d", ftstatus, num);
    
    ftstatus = FT_Write(fthandle, buf, numchannels, &num);
    if ((ftstatus != FT_OK) || (num != numchannels))
        panic("FT_Write %d %d", ftstatus, num);
}

void opendmx_close(FT_HANDLE fthandle)
{
    FT_Close(fthandle);
}

