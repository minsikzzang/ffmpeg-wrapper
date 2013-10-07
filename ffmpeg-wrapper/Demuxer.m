//
//  Demuxer.m
//  ffmpeg-wrapper
//
//  Created by Min Kim on 10/7/13.
//  Copyright (c) 2013 iFactory Lab Limited. All rights reserved.
//

#import "Demuxer.h"
// #import "NSData+Hex.h"
#import "InputStream.h"

@interface Demuxer () {
  AVFormatContext *formatContext_;
  int videoStreamId_;
  int audioStreamId_;
  AVCodecContext *videoCodecContext_;
  AVCodecContext *audioCodecContext_;
}

- (int)openCodecContext:(int *)streamId
                context:(AVFormatContext *)context
                   type:(enum AVMediaType)type;

@end

@implementation Demuxer

// @synthesize inputFile;
@synthesize inputStreams;

- (id)init {
  self = [super init];
  if (self != nil) {
    videoStreamId_ = -1;
    audioStreamId_ = -1;
    inputStreams = [NSMutableArray arrayWithCapacity:2];
  }
  return self;
}

- (void)dealloc {
  [self.inputStreams release];
  [super dealloc];
}

- (int)openCodecContext:(int *)streamId
                context:(AVFormatContext *)context
                   type:(enum AVMediaType)type {
  int ret;
  AVStream *st;
  AVCodecContext *decContext = NULL;
  AVCodec *dec = NULL;
  ret = av_find_best_stream(context, type, -1, -1, NULL, 0);
  if (ret < 0) {
    NSLog(@"Could not find %s stream in input file",
          av_get_media_type_string(type));
    return ret;
  } else {
    *streamId = ret;
    st = context->streams[*streamId];
    /* find decoder for the stream */
    decContext = st->codec;
    dec = avcodec_find_decoder(decContext->codec_id);
    if (!dec) {
      NSLog(@"Failed to find %s codec\n",
            av_get_media_type_string(type));
      return ret;
    }
    if ((ret = avcodec_open2(decContext, dec, NULL)) < 0) {
      NSLog(@"Failed to open %s codec\n",
            av_get_media_type_string(type));
      return ret;
    }
  }
  return 0;
}

- (AVCodec *)chooseDecoder:(AVFormatContext *)context stream:(AVStream *)stream {
  return avcodec_find_decoder(stream->codec->codec_id);
}

- (void)addInputStreams:(AVFormatContext *)context {
  for (int i = 0; i < context->nb_streams; ++i) {
    AVStream *stream = context->streams[i];
    AVCodecContext *codec = stream->codec;
    InputStream *ist = [[InputStream alloc] init];
    
    ist.stream = stream;
    ist.fileIndex = 1;
    ist.codec = [self chooseDecoder:context stream:stream];
    
    [inputStreams addObject:ist];
    [ist release];
    
    switch (codec->codec_type) {
      case AVMEDIA_TYPE_VIDEO:
      case AVMEDIA_TYPE_AUDIO:
      case AVMEDIA_TYPE_DATA:
      case AVMEDIA_TYPE_SUBTITLE: {
      }
      case AVMEDIA_TYPE_ATTACHMENT:
      case AVMEDIA_TYPE_UNKNOWN:
        break;
      default:
        break;
    }
  }
}

- (BOOL)openInputFile:(NSString *)inputFile {
  const char *filename = [inputFile cStringUsingEncoding:NSASCIIStringEncoding];
  // Open input file, and allocate format context
  if (avformat_open_input(&formatContext_, filename, 0, 0) < 0) {
    NSLog(@"Could not open source file %@", inputFile);
    return NO;
  }
  
  // Retrieve stream information
  if (avformat_find_stream_info(formatContext_, NULL) < 0) {
    NSLog(@"Could not find stream information\n");
    return NO;
  }

  [self addInputStreams:formatContext_];
  
  AVStream *videoStream = 0;
  AVStream *audioStream = 0;
  
  if ([self openCodecContext:&videoStreamId_
                     context:formatContext_
                        type:AVMEDIA_TYPE_VIDEO] >= 0) {
    videoStream = formatContext_->streams[videoStreamId_];
    if (videoStream) {
      videoCodecContext_ = videoStream->codec;
    }
  }
  
  if ([self openCodecContext:&audioStreamId_
                     context:formatContext_
                        type:AVMEDIA_TYPE_AUDIO] >= 0) {
    audioStream = formatContext_->streams[audioStreamId_];
    if (audioStream) {
      audioCodecContext_ = audioStream->codec;
    }
  }

  av_dump_format(formatContext_, 0, filename, 0);
  if (!videoStream && !audioStream) {
    NSLog(@"Could not find audio or video stream in the input, aborting");
    return NO;
  }

  return YES;
}

- (void)readFrame:(readHandler)readHandler {
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
}

@end
