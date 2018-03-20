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

static NSString *CJLogDetector      = @"CJLogDetector";/*沙盒文件夹名称*/
static NSString *CJLogWriteDetector = @"CJLogWriteDetector";/*写日志文件夹名称*/
static NSString *CJLogReadDetector  = @"CJLogReadDetector";/*读日志文件夹名称*/

@interface CJLogger : NSObject

- (void)flushAllocationStack:(NSString *)log;

- (void)stopFlush;

- (void)afterSyncLogData:(BOOL)deleteData finishBlock:(void(^)(NSData *logData))syncDataBlock;


@end

#endif /* CJLogger_h */


