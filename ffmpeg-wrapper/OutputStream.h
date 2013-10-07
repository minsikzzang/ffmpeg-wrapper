//
//  OutputStream.h
//  ffmpeg-wrapper
//
//  Created by Min Kim on 10/7/13.
//  Copyright (c) 2013 iFactory Lab Limited. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "libavformat/avformat.h"

@interface OutputStream : NSObject

@property (atomic, assign) AVCodec *codec;
@property (atomic, assign) AVStream *stream;
@property (atomic, assign) BOOL streamCopy;

@end