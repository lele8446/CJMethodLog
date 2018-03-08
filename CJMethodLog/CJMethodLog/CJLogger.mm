//
//  CJLogger.m
//  CJMethodLog
//
//  Created by ChiJinLian on 2018/2/9.
//  Copyright © 2018年 ChiJinLian. All rights reserved.
//

#import "CJLogger.h"
//#import "HighSpeedLogger.h"
#import <sys/mman.h>

static size_t normal_size = 5*1024;
malloc_zone_t *global_memory_zone;

class CJHighSpeedLogger {
public:
    ~CJHighSpeedLogger();
    CJHighSpeedLogger(malloc_zone_t *zone, NSString *path, size_t mmap_size);
    BOOL sprintfLogger(size_t grain_size,const char *format, ...);
    void cleanLogger();
    void syncLogger();
    bool isValid();
private:
    char *mmap_ptr;
    size_t mmap_size;
    size_t current_len;
    malloc_zone_t *memory_zone;
    FILE *mmap_fp;
    bool isFailed;
};

@interface CJLogger () {
    CJHighSpeedLogger *_stacklogger;
    NSString *_normalPath;
    NSRecursiveLock *_flushLock;
    NSString *_currentDir;
}


@end

@implementation CJLogger

+ (CJLogger *)instance {
    static CJLogger *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[CJLogger alloc] init];
    });
    return manager;
}

- (id)initWithFileName:(NSString *)fileName {
    if(self = [super init]){
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        NSString *LibDirectory = [paths objectAtIndex:0];
        NSDateFormatter *dateFormat = [[NSDateFormatter alloc]init];
        dateFormat.dateFormat = @"yyyyMMdd_HH_mm_ss";
        NSString *dateStr = [dateFormat stringFromDate:[NSDate date]];
        _currentDir = [LibDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@",CJLogDetector,dateStr]];
        NSLog(@"log日志目录 = %@",_currentDir);
        
        NSString *file = (fileName.length>0)?fileName:[NSString stringWithFormat:@"CJLog_%@.txt",dateStr];
        _normalPath = [_currentDir stringByAppendingPathComponent:file];
        if(global_memory_zone == nil){
            global_memory_zone = malloc_create_zone(0, 0);
            malloc_set_zone_name(global_memory_zone, "CJLogDetector");
        }
        _flushLock = [NSRecursiveLock new];
        
        if(_stacklogger == NULL){
            NSFileManager *fileManager = [NSFileManager defaultManager];
            if (![fileManager fileExistsAtPath:_currentDir]) {
                [fileManager createDirectoryAtPath:_currentDir withIntermediateDirectories:YES attributes:nil error:nil];
            }
            if (![fileManager fileExistsAtPath:_normalPath]) {
                [fileManager createFileAtPath:_normalPath contents:nil attributes:nil];
            }
            _stacklogger = new CJHighSpeedLogger(global_memory_zone, _normalPath, normal_size);
        }
    }
    return self;
}

/**
 开始内存堆栈映射
 */
- (void)flushAllocationStack:(NSString *)log {
    if (_stacklogger != NULL && _stacklogger->isValid()) {
        [_flushLock lock];
        _stacklogger->sprintfLogger(normal_size,"%s",[log UTF8String]);
        [_flushLock unlock];
    }
}

- (void)stopFlush {
    _stacklogger->cleanLogger();
    _stacklogger->syncLogger();
}

@end

CJHighSpeedLogger::~CJHighSpeedLogger() {
    if(mmap_ptr != NULL){
        //取消参数start所指的映射内存起始地址，参数length则是欲取消的内存大小
        munmap(mmap_ptr , mmap_size);
    }
}

CJHighSpeedLogger::CJHighSpeedLogger(malloc_zone_t *zone, NSString *path, size_t size) {
    current_len = 0;
    mmap_size = size;
    memory_zone = zone;
    FILE *fp = fopen ( [path fileSystemRepresentation] , "wb+" ) ;
    if(fp != NULL){
        int ret = ftruncate(fileno(fp), size);
        if(ret == -1){
            isFailed = true;
        }
        else {
            //函数设置文件指针stream的位置
            fseek(fp, 0, SEEK_SET);
            char *ptr = (char *)mmap(0, size, PROT_WRITE | PROT_READ, (MAP_FILE|MAP_SHARED), fileno(fp), 0);
            memset(ptr, '\0', size);
            if(ptr != NULL){
                mmap_ptr = ptr;
                mmap_fp = fp;
            }
            else {
                isFailed = true;
            }
        }
    }
    else {
        isFailed = true;
    }
}

BOOL CJHighSpeedLogger::sprintfLogger(size_t grain_size,const char *format, ...) {
    va_list args;
    va_start(args, format);
    BOOL result = NO;
    size_t maxSize = 10240;
    char *tmp = (char *)memory_zone->malloc(memory_zone, maxSize);
    size_t length = vsnprintf(tmp, maxSize, format, args);
    if(length >= maxSize) {
        memory_zone->free(memory_zone,tmp);
        return NO;
    }

    if(length + current_len < mmap_size - 1){
        current_len += snprintf(mmap_ptr + current_len, (mmap_size - 1 - current_len), "%s", (const char*)tmp);
        result = YES;
    }
    else {
        char *copy = (char *)memory_zone->malloc(memory_zone, mmap_size);
        memcpy(copy, mmap_ptr, mmap_size);
        munmap(mmap_ptr ,mmap_size);
        size_t copy_size = mmap_size;
        mmap_size += grain_size;
        int ret = ftruncate(fileno(mmap_fp), mmap_size);
        if(ret == -1){
            memory_zone->free(memory_zone,copy);
            result = NO;
        }
        else {
            fseek(mmap_fp, 0, SEEK_SET);
            mmap_ptr = (char *)mmap(0, mmap_size, PROT_WRITE | PROT_READ, (MAP_FILE|MAP_SHARED), fileno(mmap_fp), 0);
            memset(mmap_ptr, '\0', mmap_size);
            if(!mmap_ptr){
                memory_zone->free(memory_zone,copy);
                result = NO;
            }
            else {
                result = YES;
                memcpy(mmap_ptr, copy, copy_size);
                current_len += snprintf(mmap_ptr + current_len, (mmap_size - 1 - current_len), "%s", (const char*)tmp);
            }
        }
        memory_zone->free(memory_zone,copy);
    }
    va_end(args);
    memory_zone->free(memory_zone,tmp);
    return result;
}

void CJHighSpeedLogger::cleanLogger() {
    current_len = 0;
    memset(mmap_ptr, '\0', mmap_size);
}

void CJHighSpeedLogger::syncLogger() {
    msync(mmap_ptr, mmap_size, MS_ASYNC);
}

bool CJHighSpeedLogger::isValid() {
    return !isFailed;
}

