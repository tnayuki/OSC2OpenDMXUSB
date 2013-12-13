//
//  AppDelegate.m
//  OSC2OpenDMXUSB
//
//  Created by Toru Nayuki on 2013/11/08.
//  Copyright (c) 2013年 Toru Nayuki. All rights reserved.
//

#import "AppDelegate.h"

#include <ftdi.h>
#include <libusb.h>
#include <lo/lo.h>

static dispatch_semaphore_t semaphore;
static unsigned char buffer[512];

struct ftdi_context ftdic;

#define DMX_MAB 160    // Mark After Break 8 uS or more
#define DMX_BREAK 110  // Break 88 uS or more

static int do_dmx_break(struct ftdi_context* ftdic)
{
    int ret;
    
	if ((ret = ftdi_set_line_property2(ftdic, BITS_8, STOP_BIT_2, NONE, BREAK_ON)) < 0)
	{
        fprintf(stderr, "unable to set BREAK ON: %d (%s)\n", ret, ftdi_get_error_string(ftdic));
        return EXIT_FAILURE;
	}
    usleep(DMX_BREAK);
	if ((ret = ftdi_set_line_property2(ftdic, BITS_8, STOP_BIT_2, NONE, BREAK_OFF)) < 0)
	{
        fprintf(stderr, "unable to set BREAK OFF: %d (%s)\n", ret, ftdi_get_error_string(ftdic));
        return EXIT_FAILURE;
	}
    usleep(DMX_MAB);
	return EXIT_SUCCESS;
}

static int dmx_init(struct ftdi_context* ftdic)
{
    int ret;
    
    if (ftdi_init(ftdic) < 0)
    {
        fprintf(stderr, "ftdi_init failed\n");
        return EXIT_FAILURE;
    }
    
    if ((ret = ftdi_usb_open(ftdic, 0x0403, 0x6001)) < 0)
    {
        fprintf(stderr, "unable to open ftdi device: %d (%s)\n", ret, ftdi_get_error_string(ftdic));
        return EXIT_FAILURE;
    }
    
    if ((ret = ftdi_set_baudrate(ftdic, 250000)) < 0)
	{
        fprintf(stderr, "unable to set baudrate: %d (%s)\n", ret, ftdi_get_error_string(ftdic));
        return EXIT_FAILURE;
	}
    
	if ((ret = ftdi_set_line_property(ftdic, BITS_8, STOP_BIT_2, NONE)) < 0)
	{
        fprintf(stderr, "unable to set line property: %d (%s)\n", ret, ftdi_get_error_string(ftdic));
        return EXIT_FAILURE;
	}
    
    if ((ret = ftdi_setflowctrl(ftdic, SIO_DISABLE_FLOW_CTRL)) < 0)
	{
        fprintf(stderr, "unable to set flow control: %d (%s)\n", ret, ftdi_get_error_string(ftdic));
        return EXIT_FAILURE;
	}
	return EXIT_SUCCESS;
}

static int dmx_write(struct ftdi_context* ftdic, unsigned char* dmx, size_t size)
{
    int ret;
    
	if ((ret = do_dmx_break(ftdic)) == EXIT_SUCCESS)
	{
    	if ((ret = ftdi_write_data_submit(ftdic, dmx, size)) < 0)
    	{
        	fprintf(stderr, "unable to write data: %d (%s)\n", ret, ftdi_get_error_string(ftdic));
        	ret = EXIT_FAILURE;
    	}
	}
    
    usleep(88 * 513);
    
	return ret;
}

static int dmx_universe_handler(const char *path, const char *types, lo_arg ** argv, int argc, void *data, void *user_data) {
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    int datasize = lo_blob_datasize(argv[0]);
    memcpy(buffer, lo_blob_dataptr(argv[0]), datasize > 512 ? 512 : datasize);

    dispatch_semaphore_signal(semaphore);
    
    return 0;
}

void error(int num, const char *msg, const char *path)
{
    printf("liblo server error %d in path %s: %s\n", num, path, msg);
}

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    /*
    dmx_init(&ftdic);

    for (int j = 0; j < 512; j++) {
        data[j] = 0;
    }

    for (int i = 0; i < 255; i++) {
        for (int j = 0; j < 512; j++) {
            
        }
        
        data[0] = 0;
        data[1] = 255;
        data[2] = i;
        data[3] = i;
        data[4] = i;
        data[5] = 0;
        data[6] = 0;
        
        dmx_write(&ftdic, data, 512);
        
        usleep(100 * 1000);
    }
    
    printf("OK");
    exit(0);
    //*/
    
    semaphore = dispatch_semaphore_create(1);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        unsigned char dmx[513];

        dmx_init(&ftdic);
        
        while (1) {
            dmx[0] = 0;

            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            memcpy(dmx + 1, buffer, 512);
            dispatch_semaphore_signal(semaphore);
            
            dmx_write(&ftdic, dmx, 513);
            usleep(100 * 1000);
        }
    });
    
    lo_server st = lo_server_thread_new("7770", error);
    lo_server_thread_add_method(st, "/dmx/universe/0", "b", dmx_universe_handler, NULL);
    lo_server_thread_start(st);
}

@end