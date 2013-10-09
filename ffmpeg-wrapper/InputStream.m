//
//  InputStream.m
//  ffmpeg-wrapper
//
//  Created by Min Kim on 10/7/13.
//  Copyright (c) 2013 iFactory Lab Limited. All rights reserved.
//

#import "InputStream.h"
#import "libavutil/parseutils.h"


@interface InputStream () {
}

- (AVCodec *)chooseDecoder;

@end

@implementation InputStream

@synthesize codec;
@synthesize stream;
@synthesize fileIndex;
@synthesize resampleHeight;
@synthesize resamplePixFmt;
@synthesize resampleWidth;
@synthesize guessLayoutMax;
@synthesize resampleChannelLayout;
@synthesize resampleChannels;
@synthesize resampleSampleFmt;
@synthesize resampleSampleRate;
@synthesize discard;
@synthesize frameRate;
@synthesize nextDts;
@synthesize nextPts;
@synthesize isStart;
@synthesize wrapCorrectionDone;
@synthesize tsScale;
@synthesize sawFirstTs;
@synthesize decodingNeeded;
@synthesize dts;
@synthesize pts;
@synthesize filterInRescaleDeltaLast;

- (id)initWithStream:(AVStream *)aStream {
  self = [super init];
  if (self != nil) {
    stream = aStream;
    AVCodecContext *dec = stream->codec;
    
    // We only support single input at the moment, it is always 0 now
    fileIndex = 0;
    discard = 1;
    stream->discard = AVDISCARD_ALL;
    tsScale = 1.0;
    decodingNeeded = 0;
    
    codec = [self chooseDecoder];
    
    switch (dec->codec_type) {
      case AVMEDIA_TYPE_VIDEO:
        resampleHeight = dec->height;
        resampleWidth = dec->width;
        resamplePixFmt = dec->pix_fmt;
        
        if (av_parse_video_rate(&frameRate, "25") < 0) {
          NSLog(@"Error parsing framerate 25.\n");
        }
        break;
      case AVMEDIA_TYPE_AUDIO:
        guessLayoutMax = INT_MAX;
        [self guessInputChannelLayout];
        
        resampleSampleRate = dec->sample_rate;
        resampleSampleFmt = dec->sample_fmt;
        resampleChannels = dec->channels;
        resampleChannelLayout = dec->channel_layout;
        
        break;
      case AVMEDIA_TYPE_DATA:
      case AVMEDIA_TYPE_SUBTITLE:
      case AVMEDIA_TYPE_ATTACHMENT:
      case AVMEDIA_TYPE_UNKNOWN:
        break;
      default:
        break;
    }
  }
  return self;
}

- (AVCodec *)chooseDecoder {
  return avcodec_find_decoder(stream->codec->codec_id);
}

- (int)guessInputChannelLayout {
  AVCodecContext *dec = stream->codec;
  
  if (!dec->channel_layout) {
    char layoutName[256];
    if (dec->channels > guessLayoutMax) {
      return 0;
    }
    
    dec->channel_layout = av_get_default_channel_layout(dec->channels);
    if (!dec->channel_layout) {
      return 0;
    }
    
    av_get_channel_layout_string(layoutName, sizeof(layoutName),
                                 dec->channels, dec->channel_layout);
    NSLog(@"Guessed Channel Layout for  Input Stream #%d.%d : %s\n",
          fileIndex, stream->index, layoutName);
  }
  return 1;
}

@end
