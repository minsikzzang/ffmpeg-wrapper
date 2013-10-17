//
//  FFmpegWrapperTests.m
//  FFmpegWrapperTests
//
//  Created by Min Kim on 10/3/13.
//  Copyright (c) 2013 iFactory Lab Limited. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FFmpeg.h"
#import <librtmp/rtmp.h>
#import <librtmp/log.h>
#import "FLVMetadata.h"
#import "FLVWriter.h"
#import "NSData+Hex.h"
#import "FLVTag.h"
#import "NSMutableData+Bytes.h"
#import "NSData+Bytes.h"

@interface FFmpegWrapperTests : XCTestCase

@end

@implementation FFmpegWrapperTests

NSString const* kSourceMP4 = @"http://bcn01.livestation.com/test.mp4";

- (void)setUp {
  [super setUp];
  // Put setup code here. This method is called before the invocation of each
  // test method in the class.
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each
  // test method in the class.
  [super tearDown];
}

- (unsigned long)b2l:(const char *)b {
  unsigned long l = (Byte)*(b) << 24;
  l |= (Byte)*(b + 1) << 16;
  l |= (Byte)*(b + 2) << 8;
  l |= (Byte)*(b + 3);
  return l;
}

- (void)parseMp4:(NSData *)mp4 {
  unsigned long position = 0;
  char *bytes = (char *)[mp4 bytes];
  BOOL foundMdat = NO;
  unsigned long mdatLen = 0;
  
  while ([mp4 length] >= position + 4) {
    if (foundMdat == NO) {
      if ((char)*(bytes + position) == 'm' &&
          (char)*(bytes + position + 1) == 'd' &&
          (char)*(bytes + position + 2) == 'a' &&
          (char)*(bytes + position + 3) == 't') {
        foundMdat = YES;
        // get mdat size
        // NSLog(@"%@", [[NSData dataWithBytes:bytes + position - 4 length:4] hexString]);
        mdatLen = [self b2l:bytes + position - 4];
        NSLog(@"MDAT LENGTH:%ld", mdatLen);
        
        position += 4;
      } else {
        // NSLog(@"%@", [[NSData dataWithBytes:bytes + position length:4] hexString]);
        position += 1;
      }
    } else {
      unsigned long len = [self b2l:(bytes + position)];
      NSLog(@"FRAME LENGTH:%ld", len);
      NSLog(@"%@", [[NSData dataWithBytes:bytes + position length:4] hexString]);
      
      if (len > 0 && [mp4 length] >= len + position) {
        position += 4;
        
        NSLog(@"FRAME BODY%@", [[NSData dataWithBytesNoCopy:(char *)bytes + position
                                                     length:len
                                               freeWhenDone:NO] hexString]);
      } else {
        NSLog(@"FRAME BODY%@", [[NSData dataWithBytesNoCopy:(char *)bytes + position
                                                     length:[mp4 length] - position
                                               freeWhenDone:NO] hexString]);
      }
      position += len;
    }
    
    if (mdatLen != 0 && mdatLen <= position) {
      break;
    }
  }
}

- (void)parseFlv:(NSData *)flv {
  unsigned long position = 13;
  
  char *bytes = (char *)[flv bytes];
  while ([flv length] >= position + 11) {
    NSLog(@"TAG HEADER%@", [[NSData dataWithBytesNoCopy:bytes + position
                                                 length:11
                                           freeWhenDone:NO] hexString]);
    
    char packetType = (char)*(bytes + position);
    int size = AMF_DecodeInt24(bytes + position + 1);
    unsigned long ts = AMF_DecodeInt24(bytes + position + 4);
    char t = *((char *)[flv bytes] + position + 5);
    t = t << 24;
    ts |= t;
    position += 11;

    int flagsSize = 0;
    if (packetType == 0x09) {
      flagsSize = 5;
    } else if (packetType == 0x08) {
      flagsSize = 2;
    } else {
      flagsSize = 1;
    }
    
    if ([flv length] >= position + size) {
      if (flagsSize == 5) {
        NSLog(@"%x", *(bytes + position) & 0x0f);
        if ((*(bytes + position) & 0x0f) == 0x07) {
          NSLog(@"H264");
        }
        if ((*(bytes + position) & 0xf0) == 0x10) {
          NSLog(@"SEEKABLE");
        } else if ((*(bytes + position) & 0xf0) == 0x20) {
          NSLog(@"NON-SEEKABLE");
        }
        
        if (*(bytes + position + 1) == 1) {
          NSLog(@"NALU");
        }
        
        int ts = AMF_DecodeInt24(bytes + position + 2);
        NSLog(@"TS: %d", ts);
      } else if (flagsSize == 2) {
        char first = *(bytes + position);
        if (first & 10) {
          NSLog(@"AAC");
        }
        
        if (first & 3) {
          NSLog(@"FLV_SAMPLERATE_44100HZ");
        }
      } else {
        NSLog(@"FLAGS: %@", [[NSData dataWithBytes:bytes + position length:flagsSize] hexString]);
        NSLog(@"TAG BODY%@", [[NSData dataWithBytesNoCopy:bytes + position + flagsSize
                                                   length:size - flagsSize
                                             freeWhenDone:NO] hexString]);
      }
      
      /*
      NSLog(@"TAG BODY%@", [[NSData dataWithBytesNoCopy:bytes + position + flagsSize
                                                 length:size - flagsSize
                                           freeWhenDone:NO] hexString]);
       */
    } else {
      NSLog(@"FLAGS: %@", [[NSData dataWithBytes:bytes + position length:flagsSize] hexString]);
      /*
      NSLog(@"TAG BODY%@", [[NSData dataWithBytesNoCopy:bytes + position + flagsSize
                                                 length:[flv length] - position - flagsSize
                                           freeWhenDone:NO] hexString]);
       */
    }
    
    
    
    position += size;
    /*
     NSLog(@"TAG TAIL%@", [[NSData dataWithBytesNoCopy:(char *)[data bytes] + position
     length:4
     freeWhenDone:NO] hexString]);
     */
    
    position += 4;
  }
}

- (void)testMpeg4toFlv {
  // Download test mp4 file from test server
  NSData *mp4 =
    [NSData dataWithContentsOfURL:[NSURL URLWithString:(NSString *)kSourceMP4]];
  NSString *path = NSTemporaryDirectory();
  NSString *mp4Path = [path stringByAppendingPathComponent:@"test.mp4"];
  
  // Write downloaded mp4 file to local file system
  [mp4 writeToFile:mp4Path atomically:YES];
  
  // NSString *flvPath = [path stringByAppendingPathComponent:@"test.flv"];
  NSString *flvPath = @"http://bcn01.livestation.com/test.flv";

  // NSFileManager *fileManager = [NSFileManager defaultManager];
  // If flv file already exists, remove it
  // if([fileManager fileExistsAtPath:flvPath]) {
  //  [fileManager removeItemAtPath:flvPath error:nil];
  // }

  NSLog(@"mp4 data size: %d", [mp4 length]);
  NSLog(@"mp4 path %@, flv path %@", mp4Path, flvPath);
  
  NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:flvPath]];
  
  // NSLog(@"mp4%@", [mp4 hexString:10240]);
  // NSLog(@"flv%@", [data hexString:10240]);
  // NSLog(@"\n\nMP4\n\n");
  // [self parseMp4:[NSData dataWithBytes:[mp4 bytes] length:102400]];
  NSLog(@"\n\nFLV\n\n");
  [self parseFlv:[NSData dataWithBytes:[data bytes] length:204800]];
  return;
  
  RTMP *r = RTMP_Alloc();
  RTMP_LogSetLevel(RTMP_LOGALL);
  RTMP_LogCallback(rtmpLog);
  
  RTMP_Init(r);
  if (!RTMP_SetupURL(r, "rtmp://media20.lsops.net/live/protos")) {
    return;
  }
  
  RTMP_EnableWrite(r);
  if (!RTMP_Connect(r, NULL) || !RTMP_ConnectStream(r, 0)) {
    return;
  }

  

  // NSData *data = [NSData dataWithContentsOfFile:flvPath];
  // NSLog(@"output data size: %d", [data length]);
  
  // RTMP_Write(r, [data bytes], [data length]);
  
  NSLog(@"output data size: %d", [data length]);

  long length = [data length];
  unsigned long position;

  // FLVWriter *fw = [[FLVWriter alloc] init];
  FLVMetadata *metadata = [[FLVMetadata alloc] init];
  // set video encoding metadata
  metadata.width = 640;
  metadata.height = 360;
  metadata.videoBitrate = 300;
  metadata.framerate = 25;
  metadata.videoCodecId = kFLVCodecIdH264;
  
  metadata.audioBitrate = 200;
  metadata.sampleRate = 44100;
  metadata.sampleSize = 16;// * 1024; // 16K
  metadata.stereo = YES;
  metadata.audioCodecId = kFLVCodecIdAAC;
  
  
  /*
  NSLog(@"FLV HEADER%@", [[NSData dataWithBytesNoCopy:(char *)[data bytes]
                                               length:13
                                         freeWhenDone:NO] hexString]);
   */
  position = 13;
  // NSMutableArray *pktQueue = [[NSMutableArray alloc] init];
  
  while (length >= position + 11) {
    FLVWriter *f = [[FLVWriter alloc] init];
    
    // NSLog(@"TAG HEADER%@", [[NSData dataWithBytesNoCopy:(char *)[data bytes] + position
    // length:11
    // freeWhenDone:NO] hexString]);

    char packetType = (char)*((char *)[data bytes] + position);
    int size = AMF_DecodeInt24((char *)[data bytes] + position + 1);
    unsigned long ts = AMF_DecodeInt24((char *)[data bytes] + position + 4);
    char t = *((char *)[data bytes] + position + 5);
    t = t << 24;
    ts |= t;
    position += 11;
  
    NSData *pkt = nil;
    NSData *body = [NSData dataWithBytes:(char *)([data bytes] + position)
                                  length:size];
    if (packetType == 0x09) {
      [f writeVideoPacket:body timestamp:ts keyFrame:NO];
      pkt = [f.packet retain];
      /*
      pkt = [[NSData alloc] initWithData:[NSData dataWithBytesNoCopy:(char *)[data bytes] + position - 11
                                                              length:size + 15
                                                        freeWhenDone:NO]];
*/

      // NSLog(@"TAG BODY%@", [[NSData dataWithBytesNoCopy:(char *)[data bytes] + position - 11
      //                                           length:size + 15
      //                                     freeWhenDone:NO] hexString]);

      // NSLog(@"TAG BODY FROM FW%@", [pkt hexString]);

      // NSLog(@"%u == %d", [pkt length], size + 15);
      // RTMP_Write(r, [pkt bytes], size + 11);
      
      // NSMutableData *buf = [NSMutableData dataWithCapacity:size + 11];//[[NSMutableData alloc] initWithCapacity:11 + size + 4];
//
      // [buf putInt8:kFLVTagTypeVideo];                   // tag type META
      // int i = kFLVTagTypeVideo;
      // [buf appendData:[NSData dataWithBytes:&i length:1]];
      // i = size >> 16;
      // [buf appendData:[NSData dataWithBytes:&i length:1]];

      // short fliped = CFSwapInt16HostToBig(size & 0xffff);
      // [buf appendData:[NSData dataWithBytes:&fliped length:2]];
      
      // i = ts >> 16;
      // [buf appendData:[NSData dataWithBytes:&i length:1]];
      // fliped = CFSwapInt16HostToBig(ts & 0xffff);
      // [buf appendData:[NSData dataWithBytes:&fliped length:2]];

      // i = ((ts >> 24) & 0x7F);
      // [buf appendData:[NSData dataWithBytes:&i length:1]];
   
      // i = 0 >> 16;
      // [buf appendData:[NSData dataWithBytes:&i length:1]];
      // fliped = CFSwapInt16HostToBig(0 & 0xffff);
      // [buf appendData:[NSData dataWithBytes:&fliped length:2]];
   
      // [buf appendData:[NSData dataWithBytes:(char *)([data bytes] + position - 11)
      //                                                       length:11]];
      // [buf appendData:[NSData dataWithBytes:(char *)([data bytes] + position)
      //                               length:size]];
      
            // RTMP_Write(r, [pkt bytes], [pkt length]);
      // int previousTagSize = 11 + size;
      // [buf putInt32:previousTagSize];

      // pkt = nil;
    } else if (packetType == 0x08) {
      [f writeAudioPacket:body timestamp:ts];
      pkt = [f.packet retain];
      /*
      pkt = [[NSData alloc] initWithData:[NSData dataWithBytesNoCopy:(char *)[data bytes] + position - 11
                                                                                     length:size + 15
                                                                               freeWhenDone:NO]];
       */
      // pkt = [NSData dataWithBytesNoCopy:(char *)[data bytes] + position - 11
      //                           length:size + 11];

      // NSLog(@"TAG BODY%@", [[NSData dataWithBytesNoCopy:(char *)[data bytes] + position - 11
      //                                           length:size + 15
      //                                     freeWhenDone:NO] hexString]);
      
      // NSLog(@"TAG BODY FROM FW%@", [pkt hexString]);
       
      // RTMP_Write(r, [f.packet bytes], size + 11);
    } else {
      // [f writeHeader];
      [f writeMetaTag:metadata];
      pkt = [f.packet retain];
      NSLog(@"TAG BODY%@", [[NSData dataWithBytesNoCopy:(char *)[data bytes] + position - 11
                                                 length:size + 15
                                           freeWhenDone:NO] hexString]);
      
      NSLog(@"TAG BODY FROM FW%@", [pkt hexString]);

      // RTMP_Write(r, [data bytes] + position - 11, size + 11);
      // pkt = [NSData dataWithBytesNoCopy:(char *)[data bytes] + position - 11
      //                           length:size + 11];
      // pkt = [[NSData alloc] initWithBytes:(char *)[data bytes] + position - 11
      //                             length:size + 11];
      // NSLog(@"Unsupport packet type: 0x%02x", packetType);
    }

        // pkt = [NSData dataWithBytesNoCopy:(char *)[data bytes] + position - 11
    //                           length:size + 11
    //                     freeWhenDone:YES];

    if (pkt) {
      RTMP_Write(r, [pkt bytes], [pkt length]);
      // [pktQueue addObject:pkt];
      [pkt release];
    }
    
    // RTMP_Write(r, [data bytes] + position - 11, size + 11);
    // sleep(0.1);

    /*
     if (packetType == 0x08 || packetType == 0x09) {
     NSLog(@"TAG HEADER FROM FW%@", [[NSData dataWithBytesNoCopy:(char *)[fw.packet bytes]
     length:11
     freeWhenDone:NO] hexString]);
     }
     
     NSLog(@"TAG BODY%@", [[NSData dataWithBytesNoCopy:(char *)[data bytes] + position
     length:size
     freeWhenDone:NO] hexString]);
     */
    position += size;
    /*
     NSLog(@"TAG TAIL%@", [[NSData dataWithBytesNoCopy:(char *)[data bytes] + position
     length:4
     freeWhenDone:NO] hexString]);
     */
    if (packetType == 0x08 || packetType == 0x09) {
      /*
       NSLog(@"TAG TAIL FROM FW%@", [[NSData dataWithBytesNoCopy:(char *)[fw.packet bytes] + [fw.packet length] - 4
       length:4
       freeWhenDone:NO] hexString]);
       */
    }
    position += 4;
    [f release];
    
    // if (pktQueue.count > 5) {
    //  [pktQueue removeObjectAtIndex:0];
    // }
  }

  RTMP_Free(r);
  
  // Destroy packet queue which stored all media buffer sent.
  // [pktQueue release];
  
  
  /*
  FFmpeg *ffmpeg = [[FFmpeg alloc] init];
  ffmpeg.inputFile = mp4Path;
  ffmpeg.outputFile = flvPath;
  ffmpeg.videoCodec = @"copy";
  ffmpeg.audioCodec = @"copy";
  [ffmpeg run:^{
   
  } completionBlock:^(BOOL success, NSError *error) {
    if (error == nil) {
   
    } else {
      NSLog(@"%@", [error localizedDescription]);
    }
   
  }];
  */
  

  /**
   
  ffmpeg.input = mp4Path;
  ffmpeg.output = flvPath;
  ffmpeg.outputFormat = @"FLV";
  ffmpeg.videoCodec = FFMPEG_VIDEO_COPY;
  ffmpeg.audioCodec = FFMPEG_AUDIO_COPY;
  ffmpeg.width = 640;
  ffmpeg.height = 320;
  ffmpeg.run({});
  */
}

@end
