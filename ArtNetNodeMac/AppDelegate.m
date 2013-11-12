//
//  AppDelegate.m
//  ArtNetNodeMac
//
//  Created by Toru Nayuki on 2013/11/08.
//  Copyright (c) 2013年 Toru Nayuki. All rights reserved.
//

#import "AppDelegate.h"

#import <SystemConfiguration/SystemConfiguration.h>

#include <artnet/artnet.h>
#include <artnet/packets.h>
#include <ftdi.h>
#include <libusb.h>

static dispatch_semaphore_t semaphore;
static unsigned char data[512];

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

int artnetReceiver(artnet_node node, void *pp, void *d) {
    artnet_packet pack = (artnet_packet) pp;

    if (pack->type == 0x5000) {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        memcpy(data, pack->data.admx.data, 512);
        dispatch_semaphore_signal(semaphore);
    }
  
    return ARTNET_EOK;
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
    
    //dispatch_async(dispatch_get_global_queue(0, 0), ^{
        char *ip_addr = NULL;
    
        uint8_t subnet_addr = 0;
        uint8_t port_addr = 1;
        
        artnet_node *artnetNode = artnet_new(ip_addr, 1);
        
        if (!artnetNode) {
            printf("Error: %s\n", artnet_strerror());
            exit(-1);
        }
        
        NSString *computerName = (__bridge NSString *)SCDynamicStoreCopyComputerName(NULL, NULL);
        
        artnet_set_long_name(artnetNode, [[computerName stringByAppendingString:@" ArtNet Node"] UTF8String]);
        artnet_set_short_name(artnetNode, [computerName UTF8String]);
        
        // set the upper 4 bits of the universe address
        artnet_set_subnet_addr(artnetNode, subnet_addr) ;
        
        // enable port 0
        artnet_set_port_type(artnetNode, 0, ARTNET_ENABLE_OUTPUT, ARTNET_PORT_DMX) ;
        
        // bind port 0 to universe 1
        artnet_set_port_addr(artnetNode, 0, ARTNET_OUTPUT_PORT, port_addr);
        
        artnet_dump_config(artnetNode);
        
        artnet_set_handler(artnetNode, ARTNET_RECV_HANDLER, artnetReceiver, NULL);
        
        if (artnet_start(artnetNode) != 0) {
            printf("Error: %s\n", artnet_strerror());
            exit(-1);
        }

    semaphore = dispatch_semaphore_create(1);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        unsigned char buf[513];

        dmx_init(&ftdic);
        
        while (1) {
            
            buf[0] = 0;

            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            memcpy(buf + 1, data, 512);
            dispatch_semaphore_signal(semaphore);
            
            dmx_write(&ftdic, buf, 513);
            usleep(100 * 1000);
        }
    });
    
    
    //dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        while (1) {
            artnet_read(artnetNode, 1);
        }
    //});
    
    // Use this to deallocate memory
    //artnet_stop(artnetNode);
    //artnet_destroy(artnetNode);
}

@end
