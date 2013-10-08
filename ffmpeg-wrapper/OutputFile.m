//
//  OutputFile.m
//  ffmpeg-wrapper
//
//  Created by Min Kim on 10/8/13.
//  Copyright (c) 2013 iFactory Lab Limited. All rights reserved.
//

#import "OutputFile.h"
#import "OutputStream.h"
#import "InputStream.h"

@interface OutputFile () {
  NSMutableArray *outputStreams;
}

- (void)addOutputStreams;
- (InputStream *)getInputStream:(OutputStream *)ost;

@end

@implementation OutputFile

@synthesize context;
@synthesize videoCodec;
@synthesize audioCodec;
@synthesize opts;
@synthesize fileName;

- (id)init {
  self = [super init];
  if (self != nil) {
    outputStreams = [[NSMutableArray alloc] init];
    context = 0;
  }
  return self;
}

- (void)dealloc {
  [outputStreams release];
  
  // release context object
  
  [super dealloc];
}

- (BOOL)openFile:(NSString *)file {
  self.fileName = file;
  
  const char *filename = [file cStringUsingEncoding:NSASCIIStringEncoding];
  
  // Allocate the output media context
  avformat_alloc_output_context2(&context, NULL, NULL, filename);
  if (!context) {
    NSLog(@"Could not open ouput file %@", file);
    avformat_alloc_output_context2(&context, NULL, "mpeg", filename);
    if (!context) {
      return NO;
    }
  }

  [self addOutputStreams];
  
  if (!(context->oformat->flags & AVFMT_NOFILE)) {
    // test if it already exists to avoid losing precious files
    // assert_file_overwrite(filename);
    
    // open the file
    if (avio_open2(&context->pb, filename, AVIO_FLAG_WRITE, 0, 0) < 0) {
      return NO;
    }
  }
  
  return YES;
}

- (void)addOutputStreams {
  [outputStreams addObject:[OutputStream newVideoStream:context
                                              codecName:videoCodec]];
  [outputStreams addObject:[OutputStream newAudioStream:context
                                              codecName:audioCodec]];
}

- (InputStream *)getInputStream:(OutputStream *)ost {
  return ost.inputStream;
}

- (int)findVideoInputStream:(NSArray *)inputStreams {
  if (context->oformat->video_codec == AV_CODEC_ID_NONE) {
    return -1;
  }
  
  int area = 0, idx = -1, i = 0;
  int qcr = avformat_query_codec(context->oformat,
                                 context->oformat->video_codec,
                                 0);
  for (InputStream *ist in inputStreams) {
    int new_area;
    new_area = ist.stream->codec->width * ist.stream->codec->height;
    if ((qcr != MKTAG('A', 'P', 'I', 'C')) &&
        (ist.stream->disposition & AV_DISPOSITION_ATTACHED_PIC)) {
      new_area = 1;
    }
      
    if (ist.stream->codec->codec_type == AVMEDIA_TYPE_VIDEO &&
        new_area > area) {
      if ((qcr == MKTAG('A', 'P', 'I', 'C')) &&
          !(ist.stream->disposition & AV_DISPOSITION_ATTACHED_PIC)) {
        continue;
      }
        
      area = new_area;
      idx = i;
    }
    i++;
  }
  
  return idx;
}

- (int)findAudioInputStream:(NSArray *)inputStreams {
  if (context->oformat->audio_codec == AV_CODEC_ID_NONE) {
    return -1;
  }
  
  int channels = 0, idx = -1, i = 0;
  for (InputStream *ist in inputStreams) {
    if (ist.stream->codec->codec_type == AVMEDIA_TYPE_AUDIO &&
        ist.stream->codec->channels > channels) {
      channels = ist.stream->codec->channels;
      idx = i;
    }
    i++;
  }
  
  return idx;
}

- (void)linkWithInputStreams:(NSArray *)inputStreams {
  // we need to synchronize input and ouput streams
  int videoSourceId = [self findVideoInputStream:inputStreams];
  if (videoSourceId >= 0) {
    InputStream *ist = [inputStreams objectAtIndex:videoSourceId];
    for (OutputStream *ost in outputStreams) {
      if (ost.mediaType == AVMEDIA_TYPE_VIDEO) {
        ost.inputStream = ist;
        ist.discard = 0;
        ist.stream->discard = AVDISCARD_NONE;
      }
      
      ost.sourceIndex = videoSourceId;
    }
  }

  int audioSourceId = [self findAudioInputStream:inputStreams];
  if (audioSourceId >= 0) {
    InputStream *ist = [inputStreams objectAtIndex:audioSourceId];
    for (OutputStream *ost in outputStreams) {
      if (ost.mediaType == AVMEDIA_TYPE_AUDIO) {
        ost.inputStream = ist;
        ist.discard = 0;
        ist.stream->discard = AVDISCARD_NONE;
      }
      
      ost.sourceIndex = audioSourceId;
    }
  }
}

- (BOOL)computeEncodingParameters:(int)copyTB {
  InputStream *ist = NULL;
  AVCodecContext *codec = NULL;
  int audioVolume = 256;
  
  for (OutputStream *ost in outputStreams) {
    AVCodecContext *icodec = NULL;
    ist = [self getInputStream:ost];
    codec = ost.stream->codec;
    
    if (ist) {
      icodec = ist.stream->codec;
      
      ost.stream->disposition = ist.stream->disposition;
      codec->bits_per_raw_sample = icodec->bits_per_raw_sample;
      codec->chroma_sample_location = icodec->chroma_sample_location;
    }
    
    if (ost.streamCopy) {
      AVRational sar;
      uint64_t extraSize =
          (uint64_t)icodec->extradata_size + FF_INPUT_BUFFER_PADDING_SIZE;
      
      if (extraSize > INT_MAX) {
        return NO;
      }
      
      // if streamCopy is selected, no need to decode or encode
      codec->codec_id = icodec->codec_id;
      codec->codec_type = icodec->codec_type;
      
      if (!codec->codec_tag) {
        unsigned int codec_tag;
        if (!context->oformat->codec_tag ||
            av_codec_get_id(context->oformat->codec_tag,
                            icodec->codec_tag) == codec->codec_id ||
            !av_codec_get_tag2(context->oformat->codec_tag,
                               icodec->codec_id, &codec_tag)) {
            codec->codec_tag = icodec->codec_tag;
        }
      }      
      
      codec->bit_rate       = icodec->bit_rate;
      codec->rc_max_rate    = icodec->rc_max_rate;
      codec->rc_buffer_size = icodec->rc_buffer_size;
      codec->field_order    = icodec->field_order;
      codec->extradata      = av_mallocz((size_t)extraSize);
      if (!codec->extradata) {
        return NO;
      }
      memcpy(codec->extradata, icodec->extradata, icodec->extradata_size);
      codec->extradata_size= icodec->extradata_size;
      codec->bits_per_coded_sample  = icodec->bits_per_coded_sample;
      codec->time_base = ist.stream->time_base;
      
      //
      // Avi is a special case here because it supports variable fps but
      // having the fps and timebase differe significantly adds quite some
      // overhead
      //
      /*
      // We don't support avi as a source type. If you want to support it,
      // comment this below out.
      if(!strcmp(oc->oformat->name, "avi")) {
        if ( copy_tb<0 && av_q2d(ist->st->r_frame_rate) >= av_q2d(ist->st->avg_frame_rate)
            && 0.5/av_q2d(ist->st->r_frame_rate) > av_q2d(ist->st->time_base)
            && 0.5/av_q2d(ist->st->r_frame_rate) > av_q2d(icodec->time_base)
            && av_q2d(ist->st->time_base) < 1.0/500 && av_q2d(icodec->time_base) < 1.0/500
            || copy_tb==2){
          codec->time_base.num = ist->st->r_frame_rate.den;
          codec->time_base.den = 2*ist->st->r_frame_rate.num;
          codec->ticks_per_frame = 2;
        } else if (   copy_tb<0 && av_q2d(icodec->time_base)*icodec->ticks_per_frame > 2*av_q2d(ist->st->time_base)
                   && av_q2d(ist->st->time_base) < 1.0/500
                   || copy_tb==0){
          codec->time_base = icodec->time_base;
          codec->time_base.num *= icodec->ticks_per_frame;
          codec->time_base.den *= 2;
          codec->ticks_per_frame = 2;
        }
      } else */
      if (!(context->oformat->flags & AVFMT_VARIABLE_FPS) &&
          strcmp(context->oformat->name, "mov") &&
          strcmp(context->oformat->name, "mp4") &&
          strcmp(context->oformat->name, "3gp") &&
          strcmp(context->oformat->name, "3g2") &&
          strcmp(context->oformat->name, "psp") &&
          strcmp(context->oformat->name, "ipod") &&
          strcmp(context->oformat->name, "f4v")) {
        if ((copyTB < 0 &&
             icodec->time_base.den &&
             av_q2d(icodec->time_base)*icodec->ticks_per_frame > av_q2d(ist.stream->time_base) &&
             av_q2d(ist.stream->time_base) < 1.0 / 500)
            || copyTB == 0) {
          codec->time_base = icodec->time_base;
          codec->time_base.num *= icodec->ticks_per_frame;
        }
      }
      
      /*
      if (   codec->codec_tag == AV_RL32("tmcd")
          && icodec->time_base.num < icodec->time_base.den
          && icodec->time_base.num > 0
          && 121LL*icodec->time_base.num > icodec->time_base.den) {
        codec->time_base = icodec->time_base;
      }
      */
      
      if (ist && !ost.frameRate.num) {
        ost.frameRate = ist.frameRate;
      }
      
      if (ost.frameRate.num) {
        codec->time_base = av_inv_q(ost.frameRate);
      }
            
      av_reduce(&codec->time_base.num, &codec->time_base.den,
                codec->time_base.num, codec->time_base.den, INT_MAX);
      
      switch (codec->codec_type) {
        case AVMEDIA_TYPE_AUDIO:
          if (audioVolume != 256) {
            NSLog(@"-acodec copy and -vol are incompatible (frames are not decoded)");
            return NO;
          }
          codec->channel_layout     = icodec->channel_layout;
          codec->sample_rate        = icodec->sample_rate;
          codec->channels           = icodec->channels;
          codec->frame_size         = icodec->frame_size;
          codec->audio_service_type = icodec->audio_service_type;
          codec->block_align        = icodec->block_align;
          if((codec->block_align == 1 || codec->block_align == 1152 || codec->block_align == 576) &&
             codec->codec_id == AV_CODEC_ID_MP3)
            codec->block_align= 0;
          if(codec->codec_id == AV_CODEC_ID_AC3)
            codec->block_align= 0;
          break;
          
        case AVMEDIA_TYPE_VIDEO:
          codec->pix_fmt            = icodec->pix_fmt;
          codec->width              = icodec->width;
          codec->height             = icodec->height;
          codec->has_b_frames       = icodec->has_b_frames;
          if (ost.frameAspectRatio.num) { // overridden by the -aspect cli option
            sar = av_mul_q(ost.frameAspectRatio,
                     (AVRational){ codec->height, codec->width });
            NSLog(@"Overriding aspect ratio "
                  @"with stream copy may produce invalid files");
          } else if (ist.stream->sample_aspect_ratio.num) {
            sar = ist.stream->sample_aspect_ratio;
          } else {
            sar = icodec->sample_aspect_ratio;
          }
          
          ost.stream->sample_aspect_ratio = codec->sample_aspect_ratio = sar;
          ost.stream->avg_frame_rate = ist.stream->avg_frame_rate;
          break;
        case AVMEDIA_TYPE_SUBTITLE:
          codec->width  = icodec->width;
          codec->height = icodec->height;
          break;
        case AVMEDIA_TYPE_DATA:
        case AVMEDIA_TYPE_ATTACHMENT:
          break;
        default:
          return NO;
      }
    } else {
      // I won't implement this case, if you want, please see line 2284 in
      // ffmpeg.c
    }
  }
  
  return YES;
}

- (void)closeCodecs {
  for (OutputStream *ost in outputStreams) {
    avcodec_close(ost.stream->codec);
  }
}

@end
