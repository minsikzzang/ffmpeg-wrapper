//
//  Demuxer.h
//  ffmpeg-wrapper
//
//  Created by Min Kim on 10/7/13.
//  Copyright (c) 2013 iFactory Lab Limited. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "libavformat/avformat.h"

typedef void (^readHandler)(AVPacket *packet);

@interface Demuxer : NSObject

// @property (atomic, retain) NSString *inputFile;
@property (atomic, retain) NSMutableArray *inputStreams;

- (BOOL)openInputFile:(NSString *)input;
- (void)readFrame:(readHandler)readHandler;

@end
