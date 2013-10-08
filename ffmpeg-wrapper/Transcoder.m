//
//  Transcoder.m
//  ffmpeg-wrapper
//
//  Created by Min Kim on 10/7/13.
//  Copyright (c) 2013 iFactory Lab Limited. All rights reserved.
//

#import "Transcoder.h"
// #import "NSData+Hex.h"
#import "InputFile.h"
#import "OutputFile.h"

@interface Transcoder () {
  
}

@end

@implementation Transcoder

@synthesize inputFiles;
@synthesize outputFiles;

- (id)init {
  self = [super init];
  if (self != nil) {
    self.inputFiles = [NSMutableArray arrayWithCapacity:1];
    self.outputFiles = [NSMutableArray arrayWithCapacity:1];
  }
  return self;
}

- (void)dealloc {
  [self.inputFiles release];
  [self.outputFiles release];
  [super dealloc];
}

- (void)openInputFile:(NSString *)file {
  InputFile *f = [[InputFile alloc] init];
  [f openFile:file];
  [inputFiles addObject:f];
  [f release];
}

- (void)openOutputFile:(NSString *)file
        withVideoCodec:(NSString *)videoCodec
            audioCodec:(NSString *)audioCodec {
  OutputFile *f = [[OutputFile alloc] init];
  f.videoCodec = videoCodec;
  f.audioCodec = audioCodec;
  [f openFile:file];
  
  // Link ouput streams with input streams
  for (InputFile *inputFile in inputFiles) {
    [f linkWithInputStreams:inputFile.inputStreams];
  }
  
  [outputFiles addObject:f];
  [f release];
}

- (BOOL)transcodeInit {
  // Do we need to initialize framerate emulation? if so, see line 2108 in
  // ffmpeg.c
  AVFormatContext *oc = NULL;
  int i = 0;
  
  // Initialize output stream
  for (OutputFile *file in outputFiles) {
    oc = file.context;
    if (!oc->nb_streams && !(oc->oformat->flags & AVFMT_NOSTREAMS)) {
      av_dump_format(oc, i, oc->filename, 1);
      NSLog(@"Output file #%d does not contain any stream\n", i);
      return NO;
    }
  
    // Compute the right encoding parameters for each output streams
    if (![file computeEncodingParameters:0]) {
      // Let users know we failed....
    }
    i++;
  }
      
  // Init input streams
  for (InputFile *file in inputFiles) {
    if (![file initStreams]) {
      for (OutputFile *of in outputFiles) {
        [of closeCodecs];
      }
      return NO;
    }
  }
  
  int ret = 0;
  
  // Open files and write file headers
  for (OutputFile *of in outputFiles) {
    oc = of.context;
    // oc->interrupt_callback = int_cb;
    // AVDictionary *opts;
    if ((ret = avformat_write_header(of.context, 0)) < 0) {
      // of.opts = opts;
      
      char errbuf[128];
      av_strerror(ret, errbuf, sizeof(errbuf));
      NSLog(@"Could not write header for output file %@ "
            @"(incorrect codec parameters ?): %s", of.fileName, errbuf);
      // return NO;
    }
  }
  
  i = 0;
  for (OutputFile *of in outputFiles) {
    av_dump_format(of.context, i, of.context->filename, 1);
    i++;
  }
  
  // We are ready to go....
  return YES;
}

- (void)readFrame:(readHandler)readHandler {
  /*
  AVPacket packet;
  
  // initialize packet, set data to NULL, let the demuxer fill it
  av_init_packet(&packet);
  packet.data = NULL;
  packet.size = 0;
  
  while (av_read_frame(formatContext_, &packet) >= 0) {
    if (readHandler) {
      readHandler(&packet);
    }
    av_free_packet(&packet);
  }
   */
}

@end
