//
//  InputStream.h
//  ffmpeg-wrapper
//
//  Created by Min Kim on 10/7/13.
//  Copyright (c) 2013 iFactory Lab Limited. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "libavformat/avformat.h"

@interface InputStream : NSObject

@property (atomic, assign) AVCodec *codec;
@property (atomic, assign) AVStream *stream;
@property (atomic, assign) NSUInteger fileIndex;
@property (atomic, assign) NSInteger resampleHeight;
@property (atomic, assign) NSInteger resampleWidth;
@property (atomic, assign) NSInteger resamplePixFmt;
@property (atomic, assign) NSInteger guessLayoutMax;
@property (atomic, assign) NSInteger resampleSampleFmt;
@property (atomic, assign) NSInteger resampleSampleRate;
@property (atomic, assign) NSInteger resampleChannels;
@property (atomic, assign) uint64_t resampleChannelLayout;
@property (atomic, assign) NSInteger discard;
/* video only */
@property (atomic, assign) AVRational frameRate;

@property (atomic, assign) uint64_t nextPts;
@property (atomic, assign) uint64_t nextDts;
@property (atomic, assign) int isStart; /* is 1 at the start and after a discontinuity */

- (id)initWithStream:(AVStream *)stream;
- (int)guessInputChannelLayout;

@end
