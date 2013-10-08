//
//  OutputStream.h
//  ffmpeg-wrapper
//
//  Created by Min Kim on 10/7/13.
//  Copyright (c) 2013 iFactory Lab Limited. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "libavformat/avformat.h"

@class InputStream;

@interface OutputStream : NSObject

@property (atomic, assign) AVCodec *codec;
@property (atomic, assign) AVStream *stream;
@property (atomic, assign) BOOL streamCopy;
@property (atomic, assign) NSInteger fileIndex;
@property (atomic, assign) NSInteger index;
@property (atomic, assign) NSInteger sourceIndex;
@property (atomic, assign) uint64_t maxFrames;
@property (atomic, assign) AVDictionary *swrOpts;
@property (atomic, assign) uint64_t lastMuxDts;
@property (atomic, assign) enum AVMediaType mediaType;
@property (atomic, assign) InputStream *inputStream;
/* video only */
@property (atomic, assign) AVRational frameRate;
@property (atomic, assign) AVRational frameAspectRatio;

+ (OutputStream *)newVideoStream:(AVFormatContext *)context
                       codecName:(NSString *)codecName;
+ (OutputStream *)newAudioStream:(AVFormatContext *)context
                       codecName:(NSString *)codecName;

@end
