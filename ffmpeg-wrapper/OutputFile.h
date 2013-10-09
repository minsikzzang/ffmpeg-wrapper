//
//  OutputFile.h
//  ffmpeg-wrapper
//
//  Created by Min Kim on 10/8/13.
//  Copyright (c) 2013 iFactory Lab Limited. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "libavformat/avformat.h"

@class InputStream;

@interface OutputFile : NSObject

@property (atomic, assign) AVFormatContext *context;
@property (atomic, retain) NSString *videoCodec;
@property (atomic, retain) NSString *audioCodec;
@property (atomic, assign) AVDictionary *opts;
@property (atomic, retain) NSString *fileName;
@property (atomic, retain) NSMutableArray *outputStreams;
@property (atomic, assign) int64_t startTime;
// filesize limit expressed in bytes 
@property (atomic, assign) uint64_t limitFileSize;

- (BOOL)openFile:(NSString *)file;
- (void)linkWithInputStreams:(NSArray *)inputStreams;
- (BOOL)getEncodingParams:(int)copyTB;
- (void)closeCodecs;
- (void)dumpOutputStreams;
- (void)writeHeader:(NSString **)error;
- (void)writeTrailer;
- (void)dumpFormat:(NSInteger)index;
- (BOOL)hasStream;
- (BOOL)needOutput;
- (int)outputPacket:(const AVPacket *)pkt
             stream:(InputStream *)ist
              error:(NSString **)error;
- (void)cleanUp;
- (void)closeFile;

@end
