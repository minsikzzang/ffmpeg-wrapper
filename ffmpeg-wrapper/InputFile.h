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

- (BOOL)openFile:(NSString *)file;
- (BOOL)initStreams;

@end
