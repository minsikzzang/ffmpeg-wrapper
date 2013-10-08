//
//  FFmpeg.m
//  FFmpeg
//
//  Created by Min Kim on 10/3/13.
//  Copyright (c) 2013 iFactory Lab Limited. All rights reserved.
//

#import "FFmpeg.h"
#import "libavformat/avformat.h"

#import "InputStream.h"
#import "OutputStream.h"
#import "Transcoder.h"

NSString const* kMovieUnknown = @"UNKNOWN";
NSString const* kMovieMpeg4 = @"MP4";
NSString const* kMovieFLV = @"FLV";

@interface FFmpeg () {
  
}

- (const NSString *)getFileFormat:(NSString *)filePath;
- (void)registerDemuxer:(const NSString *)format;
- (void)registerMuxer:(const NSString *)format;

@end

@implementation FFmpeg

@synthesize inputFile;
@synthesize inputFormat;
@synthesize outputFile;
@synthesize outputFormat;
@synthesize videoCodec;
@synthesize audioCodec;
@synthesize width;
@synthesize height;

#define CONFIG_MOV_DEMUXER  1
#define CONFIG_FLV_MUXER    1

#define REGISTER_MUXER(X, x)                                      \
{                                                                 \
  extern AVOutputFormat ff_##x##_muxer;                           \
  if (CONFIG_##X##_MUXER)                                         \
    av_register_output_format(&ff_##x##_muxer);                   \
}

#define REGISTER_DEMUXER(X, x)                                    \
{                                                                 \
  extern AVInputFormat ff_##x##_demuxer;                          \
  if (CONFIG_##X##_DEMUXER)                                       \
    av_register_input_format(&ff_##x##_demuxer);                  \
}

void av_log_callback(void *opaque, int format, const char *str, va_list va) {
  NSLog([NSString stringWithUTF8String:str], va);
}

- (id)init {
  self = [super init];
  if (self != nil) {
    // av_log_set_callback(av_log_callback);
    av_log_set_level(AV_LOG_DEBUG);    
  }
  return self;
}

- (void)dealloc {
  [super dealloc];
}

// Decide the given file's media format based on its extension.
- (const NSString *)getFileFormat:(NSString *)filePath {
  NSString *ext = [filePath pathExtension];
  
  // We currently support mp4 and flv
  if ([ext caseInsensitiveCompare:@"mp4"] == 0 ||
      [ext caseInsensitiveCompare:@"m4a"] == 0 ||
      [ext caseInsensitiveCompare:@"m4p"] == 0 ||
      [ext caseInsensitiveCompare:@"m4b"] == 0 ||
      [ext caseInsensitiveCompare:@"m4r"] == 0 ||
      [ext caseInsensitiveCompare:@"m4v"]) {
    return kMovieMpeg4;
  } else if ([ext caseInsensitiveCompare:@"flv"] == 0) {
    return kMovieFLV;
  }
  
  return kMovieUnknown;
}

- (void)registerDemuxer:(const NSString *)format {
  if (format == kMovieMpeg4) {
    REGISTER_DEMUXER(MOV, mov)
  }
}

- (void)registerMuxer:(const NSString *)format {
  if (format == kMovieFLV) {
    REGISTER_MUXER(FLV, flv)
  }
}

- (void)run {
  // input and output should be present
  if (inputFile == nil || outputFile == nil) {
    NSLog(@"Both input and ouput should be present");
    // call failure callback function
    return;
  }
  
  // Figure out input format and register demuxer for it
  if (inputFormat == nil) {
    inputFormat = [self getFileFormat:inputFile];
  }
  
  // Figure out output format and register muxer for it
  if (outputFormat == nil) {
    outputFormat = [self getFileFormat:outputFile];
  }
  
  // Register all formats and codecs now, but eventually, we want to register
  // codeces what we only use
  // Register ffmpeg muxer and demuxers
  //  [self registerDemuxer:inputFormat];
  //  [self registerMuxer:outputFormat];
  av_register_all();
   
  Transcoder *transcoder = [[Transcoder alloc] init];
  [transcoder openInputFile:inputFile];
  [transcoder openOutputFile:outputFile
         withVideoCodec:(videoCodec == nil ? @"copy" : videoCodec)
             audioCodec:(audioCodec == nil ? @"copy" : audioCodec)];
  [transcoder transcodeInit];
  
 /*
  [demuxer readFrame:^(AVPacket *packet) {
    
  }];
  */
  /*
  InputStream *input = [[InputStream alloc] init];
  [input openInputFile:inputFile];
  
  OutputStream *output = [[OutputStream alloc] init];
  [output openOutputFile:outputFile];
  */
}

@end
