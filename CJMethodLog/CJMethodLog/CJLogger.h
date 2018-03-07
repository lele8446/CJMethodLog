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

static NSString *CJLogDetector = @"CJLogDetector";/*沙盒文件夹名称*/

@interface CJLogger : NSObject

- (id)initWithFileName:(NSString *)fileName;

- (void)flushAllocationStack:(NSString *)log;

- (void)stopFlush;


@end

#endif /* CJLogger_h */


