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
#import "OutputStream.h"
#import "InputStream.h"

@interface Transcoder () {
  // NSMutableArray *outputStreams;
  InputFile *inputFile;
  OutputFile *outputFile;
}

- (OutputStream *)chooseOutput;
- (int)processInput:(NSInteger)fileIndex;
- (int)gotEagain;
- (void)resetEagain;
- (int)transcodeInit:(NSString **)error;
- (int)transcodeStep;

@end

@implementation Transcoder

/*
@synthesize inputFiles;
@synthesize outputFiles;
*/

- (id)init {
  self = [super init];
  if (self != nil) {
    // self.inputFiles = [NSMutableArray arrayWithCapacity:1];
    // self.outputFiles = [NSMutableArray arrayWithCapacity:1];
    // outputStreams = [[NSMutableArray alloc] init];
    inputFile = [[InputFile alloc] init];
    outputFile = [[OutputFile alloc] init];
  }
  return self;
}

- (void)dealloc {
  // [self.inputFiles release];
  // [self.outputFiles release];
  // [outputStreams release];
  if (inputFile) {
    [inputFile closeFile];
    [inputFile release];
  }
    
  if (outputFile) {
    [outputFile closeFile];
    [outputFile release];
  }
  
  [super dealloc];
}

- (void)openInputFile:(NSString *)file {
  [inputFile openFile:file];
}

- (void)openOutputFile:(NSString *)file
        withVideoCodec:(NSString *)videoCodec
            audioCodec:(NSString *)audioCodec {
  // Set up video and audio codecs for output
  outputFile.videoCodec = videoCodec;
  outputFile.audioCodec = audioCodec;
  [outputFile openFile:file];
  
  // Link ouput streams with input streams
  [outputFile linkWithInputStreams:inputFile.inputStreams];
}

- (int)transcodeInit:(NSString **)error {
  // Do we need to initialize framerate emulation? if so, see line 2108 in
  // ffmpeg.c
  
  // Initialize output stream
  // If there is no stream exist in the output file
  if (![outputFile hasStream]) {
    [outputFile dumpFormat:0];
    *error = [NSString stringWithFormat:@"Output file #%d does not contain "
              @"any stream", 0];
    return AVERROR(EINVAL);
  }
  
  int ret = 0;
  
  // Compute the right encoding parameters for each output streams
  ret = [outputFile getEncodingParams:0];
  if (ret != 0) {
    // Let users know we failed....
    NSLog(@"Failed to compute encoding parameters");
    return ret;
  }
  
  // Init input streams
  if (![inputFile initStreams]) {
    [outputFile closeCodecs];
    return NO;
  }
  
  // Open files and write file headers
  // oc->interrupt_callback = int_cb;
  NSString *err = nil;
  ret = [outputFile writeHeader:&err];
  if (err) {
    *error =
        [NSString stringWithFormat:@"Could not write header for output file %@ "
                                   @"(incorrect codec parameters ?): %@",
          outputFile.fileName, err];
    return ret;
  }
  
  [outputFile dumpFormat:0];
  [outputFile dumpOutputStreams];
  
  // We are ready to go....
  return 0;
}

- (int)gotEagain {
  for (OutputStream *ost in outputFile.outputStreams) {
    if (ost.unAvailable)
      return 1;
  }
  return 0;
}

- (void)resetEagain {
  inputFile.eAgain = 0;
  
  for (OutputStream *ost in outputFile.outputStreams) {
    ost.unAvailable = 0;
  }
}

- (int)processInput:(NSInteger)fileIndex {
  InputFile *ifile = inputFile;
  // AVFormatContext *is = ifile.context;
  
  AVPacket pkt;
  int ret = [inputFile getInputPacket:&pkt];
  if (ret == AVERROR(EAGAIN)) {
    ifile.eAgain = 1;
    return ret;
  }

  if (ret < 0) {
    if (ret != AVERROR_EOF) {
      return ret;
    }
    ifile.eofReached = 1;
    
    for (InputStream *ist in ifile.inputStreams) {
      if (ist.decodingNeeded) {
        [outputFile outputPacket:NULL stream:ist error:nil];
      }
      
      // mark all outputs that don't go through lavfi as finished
      for (OutputStream *ost in outputFile.outputStreams) {
        if (ost.inputStream == ist &&
            (ost.streamCopy || ost.codec->type == AVMEDIA_TYPE_SUBTITLE)) {
          [ost closeStream];
        }
      }
    }
    
    return AVERROR(EAGAIN);
  }
  
  [self resetEagain];
  
  // the following test is needed in case new streams appear
  // dynamically in stream : we ignore them
  if (pkt.stream_index >= ifile.inputStreams.count) {
    goto discard_packet;
  }
  
  InputStream *ist = [ifile.inputStreams objectAtIndex:pkt.stream_index];
  if (ist.discard) {
    goto discard_packet;
  }
  /*
  if (!ist.wrapCorrectionDone && is->start_time != AV_NOPTS_VALUE &&
      ist.stream->pts_wrap_bits < 64) {
    int64_t stime, stime2;
    // Correcting starttime based on the enabled streams
    // FIXME this ideally should be done before the first use of starttime but
    // we do not know which are the enabled streams at that point.
    // so we instead do it here as part of discontinuity handling
    if (ist.nextDts == AV_NOPTS_VALUE
        && ifile.tsOffset == -is->start_time
        && (is->iformat->flags & AVFMT_TS_DISCONT)) {
      int64_t newStartTime = INT64_MAX;
      for (int i = 0; i < is->nb_streams; i++) {
        AVStream *st = is->streams[i];
        if (st->discard == AVDISCARD_ALL || st->start_time == AV_NOPTS_VALUE)
          continue;
        newStartTime = FFMIN(newStartTime, av_rescale_q(st->start_time,
                                                        st->time_base,
                                                        AV_TIME_BASE_Q));
      }
      if (newStartTime > is->start_time) {
        av_log(is, AV_LOG_VERBOSE, "Correcting start time by %"PRId64"\n",
               newStartTime - is->start_time);
        ifile.tsOffset = -newStartTime;
      }
    }
    
    stime = av_rescale_q(is->start_time, AV_TIME_BASE_Q, ist.stream->time_base);
    stime2= stime + (1ULL << ist.stream->pts_wrap_bits);
    ist.wrapCorrectionDone = 1;
    
    if (stime2 > stime && pkt.dts != AV_NOPTS_VALUE &&
        pkt.dts > stime + (1LL << (ist.stream->pts_wrap_bits - 1))) {
      pkt.dts -= 1ULL << ist.stream->pts_wrap_bits;
      ist.wrapCorrectionDone = 0;
    }
    if (stime2 > stime && pkt.pts != AV_NOPTS_VALUE &&
        pkt.pts > stime + (1LL << (ist.stream->pts_wrap_bits - 1))) {
      pkt.pts -= 1ULL << ist.stream->pts_wrap_bits;
      ist.wrapCorrectionDone = 0;
    }
  }
  */
  
  if (pkt.dts != AV_NOPTS_VALUE) {
    pkt.dts += av_rescale_q(ifile.tsOffset,
                            AV_TIME_BASE_Q,
                            ist.stream->time_base);
  }
  
  if (pkt.pts != AV_NOPTS_VALUE) {
    pkt.pts += av_rescale_q(ifile.tsOffset,
                            AV_TIME_BASE_Q,
                            ist.stream->time_base);
  }
  
  if (pkt.pts != AV_NOPTS_VALUE) {
    pkt.pts *= ist.tsScale;
  }
  
  if (pkt.dts != AV_NOPTS_VALUE) {
    pkt.dts *= ist.tsScale;
  }

  if (pkt.dts != AV_NOPTS_VALUE) {
    ifile.lastTs = av_rescale_q(pkt.dts, ist.stream->time_base, AV_TIME_BASE_Q);
  }
  
  NSString *error = nil;
  [outputFile outputPacket:&pkt stream:ist error:&error];
  if (error != nil) {
    NSLog(@"Error while decoding stream #%d:%d: %@",
           ist.fileIndex, ist.stream->index, error);
    return -1;
  }
  
discard_packet:
  av_free_packet(&pkt);
  
  return 0;
}

/**
 * Run a single step of transcoding.
 *
 * @return  0 for success, <0 for error
 */
- (int)transcodeStep {
  OutputStream *ost = [self chooseOutput];
  if (!ost) {
    if ([self gotEagain]) {
      [self resetEagain];
      sleep(10);
      return 0;
    }
    NSLog(@"No more inputs to read from, finishing");
    return AVERROR_EOF;
  }
  
  int ret = [self processInput:ost.inputStream.fileIndex];
  if (ret == AVERROR(EAGAIN)) {
    if (inputFile.eAgain) {
      ost.unAvailable = 1;
    }
    return 0;
  }
  if (ret < 0) {
    return ret == AVERROR_EOF ? 0 : ret;
  }
  
  return 0;
}

/**
 * Select the output stream to process.
 *
 * @return  selected output stream, or NULL if none available
 */
- (OutputStream *)chooseOutput {
  int64_t optsMin = INT64_MAX;
  OutputStream *ostMin = 0;
  
  for (OutputStream *ost in outputFile.outputStreams) {
    int64_t opts = av_rescale_q(ost.stream->cur_dts,
                                ost.stream->time_base,
                                AV_TIME_BASE_Q);
    if (!ost.unAvailable && !ost.finished && opts < optsMin) {
      optsMin = opts;
      ostMin  = ost;
    }
  }
  return ostMin;
}

static NSString * const kFFmpegError = @"kFFmpegError";
static NSString * const kFFmpegErrorDomain = @"org.ffmpeg";

- (NSError *)createNSError:(int)errorNum errorString:(NSString *)errorString {
  NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:1];
  if (errorString) {
    [userInfo setObject:errorString forKey:NSLocalizedDescriptionKey];
  } else {
    [userInfo setObject:@"Unknown ffmpeg error" forKey:NSLocalizedDescriptionKey];
  }
  
  [userInfo setObject:@(errorNum) forKey:kFFmpegError];
  return [NSError errorWithDomain:kFFmpegErrorDomain
                             code:errorNum
                         userInfo:userInfo];
}

- (int)transcode:(NSError **)nsError {
  NSString *error = nil;
  int ret = [self transcodeInit:&error];
  if (ret != 0) {
    // call failure block....
    *nsError = [self createNSError:ret errorString:error];
    return ret;
  }
  
  // int64_t startTime = av_gettime();
  while (true) {
    // check if there's any stream where output is still needed
    if (![outputFile needOutput]) {
      NSLog(@"No more output streams to write to, finishing.");
      break;
    }
    
    // int64_t curTime= av_gettime();
    ret = [self transcodeStep];
    if (ret < 0) {
      if (ret == AVERROR_EOF || ret == AVERROR(EAGAIN)) {
        continue;
      }
      
      NSLog(@"Error while filtering.");
      break;
    }
    
    // dump report by using the ouput first video and audio streams
    // print_report -> implement this later, see line 1117 in ffmpeg.c
  }
  
  // at the end of stream, we must flush the decoder buffers
  // we don't have stream which decoding needed
  // for (i = 0; i < nb_input_streams; i++) {
  //   ist = input_streams[i];
  //   if (!input_files[ist->file_index]->eof_reached && ist->decoding_needed) {
  //     output_packet(ist, NULL);
  //   }
  // }
  
  // write the trailer if needed and close file
  [outputFile writeTrailer];
  
  // dump report by using the first video and audio streams
  // print_report(1, timer_start, av_gettime()); -> implement this later,
  // see line 1117 in ffmpeg.c
  
  [outputFile cleanUp];
  return 0;
}

@end
