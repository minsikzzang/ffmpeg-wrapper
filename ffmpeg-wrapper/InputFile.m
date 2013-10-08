//
//  InputFile.m
//  ffmpeg-wrapper
//
//  Created by Min Kim on 10/8/13.
//  Copyright (c) 2013 iFactory Lab Limited. All rights reserved.
//

#import "InputFile.h"
#import "InputStream.h"

@interface InputFile () {
  
}

- (void)addInputStreams;

@end

@implementation InputFile

@synthesize nbStreams;
@synthesize context;
@synthesize istIndex;
@synthesize inputStreams;

- (id)init {
  self = [super init];
  if (self != nil) {
    inputStreams = [[NSMutableArray alloc] init];
    context = 0;
  }
  return self;
}

- (void)dealloc {
  [inputStreams release];
  
  // release context object
  
  [super dealloc];
}

- (BOOL)openFile:(NSString *)file {
  const char *filename = [file cStringUsingEncoding:NSASCIIStringEncoding];
    
  // Open input file, and allocate format context
  if (avformat_open_input(&context, filename, 0, 0) < 0) {
    NSLog(@"Could not open source file %@", file);
    return NO;
  }
    
  // Retrieve stream information
  if (avformat_find_stream_info(context, NULL) < 0) {
    NSLog(@"Could not find stream information\n");
    return NO;
  }
  
  [self addInputStreams];
  av_dump_format(context, 0, filename, 0);
  
  istIndex = inputStreams.count - context->nb_streams;
  nbStreams = context->nb_streams;

  return YES;
}

- (void)addInputStreams {
  for (int i = 0; i < context->nb_streams; ++i) {
    InputStream *ist = [[InputStream alloc] initWithStream:context->streams[i]];
    [inputStreams addObject:ist];
    [ist release];
  }
}

- (BOOL)initStreams {
  for (InputStream *ist in inputStreams) {
    /*
     // We don't need decode...
    if (ist.decoding_needed) {
      AVCodec *codec = ist->dec;
      if (!codec) {
        snprintf(error, error_len, "Decoder (codec %s) not found for input stream #%d:%d",
                 avcodec_get_name(ist->st->codec->codec_id), ist->file_index, ist->st->index);
        return AVERROR(EINVAL);
      }
      
      av_opt_set_int(ist->st->codec, "refcounted_frames", 1, 0);
      
      if (!av_dict_get(ist->opts, "threads", NULL, 0))
        av_dict_set(&ist->opts, "threads", "auto", 0);
      if ((ret = avcodec_open2(ist->st->codec, codec, &ist->opts)) < 0) {
        char errbuf[128];
        if (ret == AVERROR_EXPERIMENTAL)
          abort_codec_experimental(codec, 0);
        
        av_strerror(ret, errbuf, sizeof(errbuf));
        
        snprintf(error, error_len,
                 "Error while opening decoder for input stream "
                 "#%d:%d : %s",
                 ist->file_index, ist->st->index, errbuf);
        return ret;
      }
      assert_avoptions(ist->opts);
    }
    */
    ist.nextPts = AV_NOPTS_VALUE;
    ist.nextDts = AV_NOPTS_VALUE;
    ist.isStart = 1;
  }
  
  return YES;
}


@end
