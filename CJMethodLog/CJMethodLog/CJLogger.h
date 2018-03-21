//
//  CJLogger.h
//  CJMethodLog
//
//  Created by ChiJinLian on 2018/2/9.
//  Copyright © 2018年 ChiJinLian. All rights reserved.
//

#ifndef CJLogger_h
#define CJLogger_h

#import <Foundation/Foundation.h>
#import <malloc/malloc.h>

static NSString *kCJLogDetector      = @"CJLogDetector";/*沙盒文件夹名称*/
static NSString *kCJLogWriteDetector = @"CJLogWriteDetector";/*写日志文件夹名称*/
static NSString *kCJLogReadDetector  = @"CJLogReadDetector";/*读日志文件夹名称*/
static NSString *kFileExtension      = @"txt";/*日志文件格式*/

@interface CJLogger : NSObject

- (void)flushAllocationStack:(NSString *)log;

- (void)stopFlush;

- (void)syncLogData:(void(^)(NSData *logData))finishBlock;

- (void)clearLogData;
@end

#endif /* CJLogger_h */


