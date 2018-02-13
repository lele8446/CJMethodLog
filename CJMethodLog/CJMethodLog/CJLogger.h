//
//  CJLogger.h
//  CJMethodLog
//
//  Created by ChiJinLian on 2018/2/9.
//  Copyright © 2018年 ChiJinLian. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface CJLogger : NSObject

+ (CJLogger *)getInstance;
- (void)flush_allocation_stack:(NSString *)log;

- (void)stopFlush;
@end
