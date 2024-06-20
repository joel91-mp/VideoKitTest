//
//  VKICYMetadata.m
//  VideoKitSample
//
//  Created by Murat Sudan on 12/08/2017.
//  Copyright © 2017 iosvideokit. All rights reserved.
//

#import "VKICYMetadata.h"

@implementation VKICYMetadata

- (id)initWithTitle:(NSString *)streamTitle headersRaw:(NSString *)headersRaw {
    
    self = [super init];
    
    if (self) {
        _title = [streamTitle retain];
        [self parseHeaders:headersRaw];
    }
    return self;
}

- (void)parseHeaders:(NSString *)headersStr {
    NSArray *headers = [headersStr componentsSeparatedByString:@"\n"];
    for (NSString *header in headers) {
        
        NSArray *pair = [header componentsSeparatedByString:@":"];
        if ([pair count] != 2)
            continue;
        
        if ([pair[0] rangeOfString:@"icy-br"].location != NSNotFound) {
            _bitrate = [pair[1] retain];
        } else if ([pair[0] rangeOfString:@"icy-description"].location != NSNotFound) {
            _desc = [pair[1] retain];
        } else if ([pair[0] rangeOfString:@"icy-genre"].location != NSNotFound) {
            _genre = [pair[1] retain];
        } else if ([pair[0] rangeOfString:@"icy-name"].location != NSNotFound) {
            _name = [pair[1] retain];
        } else if ([pair[0] rangeOfString:@"icy-pub"].location != NSNotFound) {
            _pub = [pair[1] retain];
        } else if ([pair[0] rangeOfString:@"icy-url"].location != NSNotFound) {
            _url = [pair[1] retain];
        }
    }
}

- (void)dealloc {
    
    [_title release];
    [_desc release];
    [_genre release];
    [_name release];
    [_pub release];
    [_url release];
    
    [super dealloc];
}

@end
