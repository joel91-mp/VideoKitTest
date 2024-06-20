//
//  VKICYMetadata.h
//  VideoKitSample
//
//  Created by Murat Sudan on 12/08/2017.
//  Copyright © 2017 iosvideokit. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VKICYMetadata : NSObject

///Initialize VKICYMetadata class object instance with title and headers in raw string format (unformatted)
- (id)initWithTitle:(NSString *)title headersRaw:(NSString *)headersRaw;

///Holds stream title information
@property (nonatomic, readonly) NSString *title;

///Holds stream bitrate information
@property (nonatomic, readonly) NSString *bitrate;

///Holds stream description information
@property (nonatomic, readonly) NSString *desc;

///Holds stream genre information
@property (nonatomic, readonly) NSString *genre;

///Holds stream name information
@property (nonatomic, readonly) NSString *name;

///Holds stream pub information
@property (nonatomic, readonly) NSString *pub;

///Holds stream url information
@property (nonatomic, readonly) NSString *url;

@end
