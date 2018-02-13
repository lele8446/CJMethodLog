//
//  CJLogger.m
//  CJMethodLog
//
//  Created by ChiJinLian on 2018/2/9.
//  Copyright © 2018年 ChiJinLian. All rights reserved.
//

#import "CJLogger.h"
#import "HighSpeedLogger.h"

static size_t normal_size = 5*1024;
//static size_t normal_size = 512;
malloc_zone_t *global_memory_zone;

@interface CJLogger ()
{
    HighSpeedLogger *normal_stack_logger;
    NSString *_normal_path;
    NSRecursiveLock *_flushLock;
    NSString *_currentDir;
}


@end

@implementation CJLogger

+ (CJLogger *)getInstance {
    static CJLogger *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[CJLogger alloc] init];
    });
    return manager;
}

- (id)init {
    if(self = [super init]){
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        NSString *LibDirectory = [paths objectAtIndex:0];
        NSDateFormatter* df = [[NSDateFormatter alloc]init];
        df.dateFormat = @"yyyyMMdd_HHmmssSSS";
        NSString *dateStr = [df stringFromDate:[NSDate date]];
        _currentDir = [LibDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"OOMDetector/%@",dateStr]];
        NSLog(@"_currentDir = %@",_currentDir);
        _normal_path = [_currentDir stringByAppendingPathComponent:[NSString stringWithFormat:@"normal_malloc%@.txt",dateStr]];
        if(global_memory_zone == nil){
            global_memory_zone = malloc_create_zone(0, 0);
            malloc_set_zone_name(global_memory_zone, "OOMDetector");
        }
        _flushLock = [NSRecursiveLock new];
        
        if(normal_stack_logger == NULL){
            NSFileManager *fileManager = [NSFileManager defaultManager];
            if (![fileManager fileExistsAtPath:_currentDir]) {
                [fileManager createDirectoryAtPath:_currentDir withIntermediateDirectories:YES attributes:nil error:nil];
            }
            if (![fileManager fileExistsAtPath:_normal_path]) {
                [fileManager createFileAtPath:_normal_path contents:nil attributes:nil];
            }
            normal_stack_logger = new HighSpeedLogger(global_memory_zone, _normal_path, normal_size);
        }
    }
    return self;
}

- (void)flush_allocation_stack:(NSString *)log {
    [_flushLock lock];
    [self flush_allocation_stack2:log];
    [_flushLock unlock];
}

/**
 开始内存堆栈映射
 */
- (void)flush_allocation_stack2:(NSString *)log {
//    normal_stack_logger->current_len = 0;
    NSDateFormatter* df = [[NSDateFormatter alloc]init];
    df.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    NSString *dateStr = [df stringFromDate:[NSDate date]];
    int exceedNum = 0;
    
    normal_stack_logger->sprintfLogger(normal_size,"%s",[log UTF8String]);
//    normal_stack_logger->syncLogger();
    
//    if(exceedNum == 0){
//        normal_stack_logger->cleanLogger();
//    }
    
    
}

- (void)stopFlush {
    normal_stack_logger->cleanLogger();
}

@end
