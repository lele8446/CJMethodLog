//
//  CJMethodLog.h
//  CJMethodLog
//
//  Created by ChiJinLian on 2018/1/29.
//  Copyright © 2018年 ChiJinLian. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_OPTIONS (NSUInteger, CJLogOptions) {
    /**
     * 默认只记录执行函数名称
     */
    CJLogDefault = 1<<0,
    
    /**
     * 函数执行耗时
     */
    CJLogMethodTimer = 1<<1,
    
    /**
     * 函数参数（未实现）
     */
    CJLogMethodArgs = 1<<2,
    
    /**
     * 函数返回值（未实现）
     */
    CJLogMethodReturnValue = 1<<3,
};

/**
 * Objective-C任意类，任意方法的调用日志监听系统
 */
@interface CJMethodLog : NSObject

/**
 * 设置是否打印CJMethodLog的log信息，默认NO（不打印log）
 * @param value 设置为YES，会输出方法监听的log信息，该值只在 DEBUG 环境有效
 */
+ (void)setCJLogEnabled:(BOOL)value;

/**
 * 基于消息转发（forwardInvocation:）实现对指定类的函数调用监听
 * 注意！！！所有设置的hook类不能存在继承关系
 *
 * @param classNameList 需要hook的类名
 * @param options       日志选项
 */
+ (void)forwardingClasses:(NSArray <NSString *>*)classNameList logOptions:(CJLogOptions)options;


/**
 * 获取日志文件
 *
 * @param deleteData    获取文件后是否删除数据
 * @param syncDataBlock 获取文件回调blokc
 */
+ (void)afterSyncLogData:(BOOL)deleteData finishBlock:(void(^)(NSData *logData))syncDataBlock;

@end
