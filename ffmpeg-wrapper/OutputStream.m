//
//  OutputStream.m
//  ffmpeg-wrapper
//
//  Created by Min Kim on 10/7/13.
//  Copyright (c) 2013 iFactory Lab Limited. All rights reserved.
//

#import "OutputStream.h"
#import "InputStream.h"
#import "libavutil/parseutils.h"

@interface OutputStream () {


}

- (id)initWithStream:(AVStream *)stream;
+ (OutputStream *)newOutputStream:(AVFormatContext *)context
                             type:(enum AVMediaType)type
                        codecName:(NSString *)codecName;
- (void)chooseEncoder:(AVFormatContext *)context
            codecName:(const char *)codecName;

@end

@implementation OutputStream

@synthesize codec;
@synthesize stream;
@synthesize streamCopy;
@synthesize fileIndex;
@synthesize index;
@synthesize maxFrames;
@synthesize swrOpts;
@synthesize mediaType;
@synthesize inputStream;
@synthesize frameRate;
@synthesize frameAspectRatio;

+ (OutputStream *)newOutputStream:(AVFormatContext *)context
                             type:(enum AVMediaType)type
                        codecName:(NSString *)codecName {
  AVStream *st = avformat_new_stream(context, NULL);
  OutputStream *ost = [[OutputStream alloc] initWithStream:st];
  NSInteger idx = context->nb_streams - 1;
  
  // We only support single output at the moment, it is always 0 now
  ost.fileIndex = 0;
  ost.index = idx;
  ost.mediaType = type;
  st->codec->codec_type = type;
  [ost chooseEncoder:context
           codecName:[codecName cStringUsingEncoding:NSASCIIStringEncoding]];
  if (ost.codec) {
    
  }
  
  // We do only stream copy at this time and ost.codec will be always nil
  avcodec_get_context_defaults3(st->codec, ost.codec);
  st->codec->codec_type = type; // XXX hack,
                                // avcodec_get_context_defaults2() sets type
                                // to unknown for stream copy
  ost.maxFrames = INT64_MAX;
  if (context->oformat->flags & AVFMT_GLOBALHEADER) {
    st->codec->flags |= CODEC_FLAG_GLOBAL_HEADER;
  }
    
  /*
  if (ost.codec && av_get_exact_bits_per_sample(ost.codec->id) == 24)
    av_dict_set(&ost.swrOpts, "output_sample_bits", "24", 0);
  */
  ost.lastMuxDts = AV_NOPTS_VALUE;
  return [ost autorelease];
}

+ (OutputStream *)newVideoStream:(AVFormatContext *)context
                       codecName:(NSString *)codecName {
  OutputStream *ost = [self newOutputStream:context
                                       type:AVMEDIA_TYPE_VIDEO
                                  codecName:codecName];
  
  AVRational frameRate;
  if (av_parse_video_rate(&frameRate, "25") < 0) {
    NSLog(@"Invalid framerate value: 25");
    return 0;
  }
  
  ost.frameRate = frameRate;
  
  if (!ost.streamCopy) {
    // see line 1193 in ffmpeg_opt.c file if you'd love to implement this.
  }
  return ost;
}

+ (OutputStream *)newAudioStream:(AVFormatContext *)context
                        codecName:(NSString *)codecName {
  OutputStream *ost = [self newOutputStream:context
                                       type:AVMEDIA_TYPE_AUDIO
                                  codecName:codecName];
  if (!ost.streamCopy) {
    // see line 1322 in ffmpeg_opt.c file if you'd love to implement this.
  }
  return ost;
}

- (id)initWithStream:(AVStream *)aStream {
  self = [super init];
  if (self != nil) {
    self.stream = aStream;
  }
  return self;
}

- (void)dealloc {
  [super dealloc];
}

- (void)chooseEncoder:(AVFormatContext *)context
            codecName:(const char *)codecName{
  if (!codecName) {
    stream->codec->codec_id = av_guess_codec(context->oformat,
                                             NULL,
                                             context->filename,
                                             NULL,
                                             stream->codec->codec_type);
    codec = avcodec_find_encoder(stream->codec->codec_id);
  } else if (!strcmp(codecName, "copy"))
    streamCopy = 1;
  else {
    codec = avcodec_find_encoder(stream->codec->codec_id);
    stream->codec->codec_id = codec->id;
  }
}

@end
