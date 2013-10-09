//
//  InputFile.h
//  ffmpeg-wrapper
//
//  Created by Min Kim on 10/8/13.
//  Copyright (c) 2013 iFactory Lab Limited. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "libavformat/avformat.h"

@interface InputFile : NSObject

@property (atomic, assign) AVFormatContext *context;
@property (atomic, assign) NSInteger istIndex;
@property (atomic, assign) NSInteger nbStreams;
@property (atomic, retain) NSMutableArray *inputStreams;
// true if last read attempt returned EAGAIN
@property (atomic, assign) int eAgain;
// true if eof reached
@property (atomic, assign) int eofReached;
@property (atomic, assign) int64_t tsOffset;
@property (atomic, assign) int64_t lastTs;
@property (atomic, assign) int64_t startTime;

- (BOOL)openFile:(NSString *)file;
- (void)closeFile;
- (BOOL)initStreams;
- (int)getInputPacket:(AVPacket *)pkt;


@end
