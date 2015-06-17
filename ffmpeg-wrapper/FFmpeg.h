//
//  FFmpeg.h
//  FFmpeg
//
//  Created by Min Kim on 10/3/13.
//  Copyright (c) 2013 iFactory Lab Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^FFmpegCompletioBlock)(BOOL success, NSError *error);
typedef void (^FFmpegProgressBlock)(void);

extern NSString const* kMovieUnknown;
extern NSString const* kMovieMpeg4;
extern NSString const* kMovieFLV;

@interface FFmpeg : NSObject

@property (atomic, retain) NSString *inputFile;
@property (atomic, assign) const NSString *inputFormat;
@property (atomic, retain) NSString *outputFile;
@property (atomic, assign) const NSString *outputFormat;
@property (atomic, assign) const NSString *videoCodec;
@property (atomic, assign) const NSString *audioCodec;
@property (atomic, assign) int width;
@property (atomic, assign) int height;

- (void)run:(FFmpegProgressBlock)progressBlock completionBlock:(FFmpegCompletioBlock)completionBlock;

@end
