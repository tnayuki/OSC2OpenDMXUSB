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

extern void *opendmx_open(void);
extern void opendmx_send_frame(void *fthandle, unsigned numchannels, uint8_t *buf);

static dispatch_semaphore_t semaphore;
static unsigned char data[512];
static void *h;
static struct timeval ot;

int artnetReceiver(artnet_node node, void *pp, void *d) {
    artnet_packet pack = (artnet_packet) pp;

    //NSLog(@"Receiving Art-Net data!");
    //printf("Received packet sequence %d\n", pack->data.admx.sequence);
    //printf("Received packet type %d\n", pack->type);
    //printf("Received packet data %s\n", pack->data.admx.data);
/*
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    memcpy(data, pack->data.admx.data, 512);

    dispatch_semaphore_signal(semaphore);
  */

    struct timeval t1;
    gettimeofday(&t1, NULL);

    //if (t1.tv_usec - ot.tv_usec > 30000) {
        opendmx_send_frame(h, 512, pack->data.admx.data);

        ot = t1;
    //}

    return ARTNET_EOK;
}

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    
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

    h = opendmx_open();
    gettimeofday(&ot, NULL);

        //dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            while (1) {
                //artnet_send_poll(artnetNode, NULL, ARTNET_TTM_DEFAULT);
                //printf("arnet_get_sd() => %i\n", artnet_get_sd(artnetNode));
                printf("artnet_read() => %i\n", artnet_read(artnetNode, 1));
            }
        //});
/*
        //dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{

            int i = 0;
            while (1) {
                unsigned char buf[512];
                
                printf("%d\n", i);

                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                
                memcpy(buf, data, 512);
                
                dispatch_semaphore_signal(semaphore);
                
                opendmx_send_frame(h, 512, buf);
                
                i++;
            }
        //});
 */
    
        // Use this to deallocate memory
        //artnet_stop(artnetNode);
        //artnet_destroy(artnetNode);
    //});
}

@end
