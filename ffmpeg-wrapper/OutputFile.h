//
//  OutputFile.h
//  ffmpeg-wrapper
//
//  Created by Min Kim on 10/8/13.
//  Copyright (c) 2013 iFactory Lab Limited. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "libavformat/avformat.h"

@interface OutputFile : NSObject

@property (atomic, assign) AVFormatContext *context;
@property (atomic, retain) NSString *videoCodec;
@property (atomic, retain) NSString *audioCodec;
@property (atomic, assign) AVDictionary *opts;
@property (atomic, retain) NSString *fileName;

- (BOOL)openFile:(NSString *)file;
- (void)linkWithInputStreams:(NSArray *)inputStreams;
- (BOOL)computeEncodingParameters:(int)copyTB;
- (void)closeCodecs;

@end
