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

  NSFileManager *fileManager = [NSFileManager defaultManager];
  /*
  // If flv file already exists, remove it
  if([fileManager fileExistsAtPath:flvPath]) {
    [fileManager removeItemAtPath:flvPath error:nil];
  }
  */
  NSLog(@"mp4 data size: %d", [mp4 length]);
  NSLog(@"mp4 path %@, flv path %@", mp4Path, flvPath);
  RTMP *r = RTMP_Alloc();
  RTMP_LogSetLevel(RTMP_LOGALL);
  RTMP_LogCallback(rtmpLog);
  
  RTMP_Init(r);
  if (!RTMP_SetupURL(r, "rtmp://media20.lsops.net/live/test")) {
    return;
  }
  
  RTMP_EnableWrite(r);
  if (!RTMP_Connect(r, NULL) || !RTMP_ConnectStream(r, 0)) {
    return;
  }
  NSData *data =
  [NSData dataWithContentsOfURL:[NSURL URLWithString:flvPath]];
  
  // NSData *data = [NSData dataWithContentsOfFile:flvPath];
  // NSLog(@"output data size: %d", [data length]);
  
  // RTMP_Write(r, [data bytes], [data length]);
  
  NSLog(@"output data size: %d", [data length]);
  long length = [data length];
  unsigned long position = 0;
  
  // FLVWriter *fw = [[FLVWriter alloc] init];
  FLVMetadata *metadata = [[FLVMetadata alloc] init];
  // set video encoding metadata
  metadata.width = 480;
  metadata.height = 360;
  metadata.videoBitrate = 300000 / 1024.0;
  metadata.framerate = 25;
  metadata.videoCodecId = kFLVCodecIdH264;
  
  metadata.audioBitrate = 200000 / 1024.0;
  metadata.sampleRate = 44100;
  metadata.sampleSize = 16;// * 1024; // 16K
  metadata.stereo = YES;
  metadata.audioCodecId = kFLVCodecIdAAC;
  
  // [fw writeHeader];
  // [fw writeMetaTag:metadata];
  
  NSLog(@"FLV HEADER%@", [[NSData dataWithBytesNoCopy:(char *)[data bytes]
                                               length:13
                                         freeWhenDone:NO] hexString]);
  position = 13;
  
  FLVWriter *f = [[FLVWriter alloc] init];
  while (length >= position + 11) {
    [f reset];
    
    /*
     NSLog(@"TAG HEADER%@", [[NSData dataWithBytesNoCopy:(char *)[data bytes] + position
     length:11
     freeWhenDone:NO] hexString]);
     */
    char packetType = (char)*((char *)[data bytes] + position);
    int size = AMF_DecodeInt24((char *)[data bytes] + position + 1);
    long ts = AMF_DecodeInt24((char *)[data bytes] + position + 4);
    ts |= (char)*((char *)[data bytes] + position + 5) << 24;
    position += 11;
    
    NSData *pkt = nil;
    if (packetType == 0x09) {
      /*
      NSData *pkt = [f writeVideoPacket:[NSData
                                         dataWithBytes:(char *)([data bytes] + position)
                                         length:size] timestamp:ts];
       */
      // NSLog(@"%u == %d", [pkt length], size + 15);
      // RTMP_Write(r, [pkt bytes], size + 11);
      
      NSMutableData *buf = [NSMutableData dataWithCapacity:size + 11];//[[NSMutableData alloc] initWithCapacity:11 + size + 4];
//
      /*
      // [buf putInt8:kFLVTagTypeVideo];                   // tag type META
      int i = kFLVTagTypeVideo;
      [buf appendData:[NSData dataWithBytes:&i length:1]];
      i = size >> 16;
      [buf appendData:[NSData dataWithBytes:&i length:1]];

      short fliped = CFSwapInt16HostToBig(size & 0xffff);
      [buf appendData:[NSData dataWithBytes:&fliped length:2]];
      
      i = ts >> 16;
      [buf appendData:[NSData dataWithBytes:&i length:1]];
      fliped = CFSwapInt16HostToBig(ts & 0xffff);
      [buf appendData:[NSData dataWithBytes:&fliped length:2]];


      i = ((ts >> 24) & 0x7F);
      [buf appendData:[NSData dataWithBytes:&i length:1]];
      

      i = 0 >> 16;
      [buf appendData:[NSData dataWithBytes:&i length:1]];
      fliped = CFSwapInt16HostToBig(0 & 0xffff);
      [buf appendData:[NSData dataWithBytes:&fliped length:2]];
 */
   
      [buf appendData:[NSData dataWithBytes:(char *)([data bytes] + position - 11)
                                                             length:11]];
      [buf appendData:[NSData dataWithBytes:(char *)([data bytes] + position)
                                     length:size]];
      
      @try {
        // RTMP_Write(r, [ph bytes], 11);
        RTMP_Write(r, [buf bytes], size + 11);
      }
      @catch (NSException *exception) {

      }
      @finally {

      }
      
      
      // RTMP_Write(r, [pkt bytes], [pkt length]);      
      // int previousTagSize = 11 + size;
      // [buf putInt32:previousTagSize];

      pkt = nil;
    } else if (packetType == 0x08) {
       [f writeAudioPacket:[NSData dataWithBytesNoCopy:(char *)[data bytes] + position
                                                length:size
                                          freeWhenDone:NO] timestamp:ts];
      pkt = [NSData dataWithBytesNoCopy:(char *)[data bytes] + position - 11
                                 length:size + 11];
      /*
       NSLog(@"TAG BODY%@", [[NSData dataWithBytesNoCopy:(char *)[data bytes] + position - 11
       length:size + 15
       freeWhenDone:NO] hexString]);
       NSLog(@"TAG BODY FROM FW%@", [f.packet hexString]);
       */
      // RTMP_Write(r, [f.packet bytes], size + 11);
    } else {
      // RTMP_Write(r, [data bytes] + position - 11, size + 11);
      pkt = [NSData dataWithBytesNoCopy:(char *)[data bytes] + position - 11
                                 length:size + 11];
    }
    
    if (pkt) {
      RTMP_Write(r, [pkt bytes], [pkt length]);
    }
    // RTMP_Write(r, [data bytes] + position - 11, size + 11);
    sleep(0.1);
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
  }

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
