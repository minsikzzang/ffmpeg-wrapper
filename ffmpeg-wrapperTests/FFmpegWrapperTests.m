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
  
  NSString *flvPath = [path stringByAppendingPathComponent:@"test.flv"];
  NSFileManager *fileManager = [NSFileManager defaultManager];
  
  // If flv file already exists, remove it
  if([fileManager fileExistsAtPath:flvPath]) {
    [fileManager removeItemAtPath:flvPath error:nil];
  }
  
  NSLog(@"mp4 data size: %d", [mp4 length]);
  NSLog(@"mp4 path %@, flv path %@", mp4Path, flvPath);
  
  FFmpeg *ffmpeg = [[FFmpeg alloc] init];
  ffmpeg.inputFile = mp4Path;
  ffmpeg.outputFile = flvPath;
  ffmpeg.videoCodec = @"copy";
  ffmpeg.audioCodec = @"copy";
  [ffmpeg run:^{
    
  } completionBlock:^(BOOL success, NSError *error) {
    if (error == nil) {
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
      
      NSData *data = [NSData dataWithContentsOfFile:flvPath];
      NSLog(@"output data size: %d", [data length]);
      
      RTMP_Write(r, [data bytes], [data length]);
    } else {
      NSLog(@"%@", [error localizedDescription]);
    }
    
  }];
  
  for (int ii = 0; ii < 100; ii++) {
    sleep(1);
  }


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
