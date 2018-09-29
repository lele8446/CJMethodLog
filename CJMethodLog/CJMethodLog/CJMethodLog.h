//
//  CJMethodLog.h
//  CJMethodLog
//
//  Created by ChiJinLian on 2018/1/29.
//  Copyright © 2018年 ChiJinLian. All rights reserved.
//
//
//  Objective-C 函数日志监听系统
//  CJMethodLog 对于 Objective-C 中的任意类、任意类的任意方法，均可监听其调用日志
//

#import <Foundation/Foundation.h>

/**
 获取日志block

 @param logData 日志数据
 */
typedef void(^SyncDataBlock)(NSData *logData);

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
     * 函数参数
     */
    CJLogMethodArgs = 1<<2,
    
    /**
     * 函数返回值
     */
    CJLogMethodReturnValue = 1<<3,
};

@interface CJMethodLog : NSObject

/**
 * hook指定类
 * 注意！！！所有设置的hook类不能存在继承关系
 *
 * @param classNameList 需要hook的类名数组
 * @param options       日志选项
 * @param value         是否打印监听日志，全局有效（设置为YES，会输出方法监听的log信息，该值只在 DEBUG 环境有效）
 */
+ (void)forwardingClasses:(NSArray <NSString *>*)classNameList logOptions:(CJLogOptions)options logEnabled:(BOOL)value;

/**
 * hook指定类的指定实例方法
 *
 * @param className  需要hook的类
 * @param methodList 指定方法列表
 * @param options    日志选项
 * @param value      是否打印监听日志，全局有效（设置为YES，会输出方法监听的log信息，该值只在 DEBUG 环境有效）
 */
+ (void)forwardingInstanceMethodWithClass:(NSString *)className methodList:(NSArray <NSString *>*)methodList logOptions:(CJLogOptions)options logEnabled:(BOOL)value;

/**
 * hook指定类的指定类方法
 *
 * @param className  需要hook的类
 * @param methodList 指定方法列表
 * @param options    日志选项
 * @param value      是否打印监听日志，全局有效（设置为YES，会输出方法监听的log信息，该值只在 DEBUG 环境有效）
 */
+ (void)forwardingClassMethodWithClass:(NSString *)className methodList:(NSArray <NSString *>*)methodList logOptions:(CJLogOptions)options logEnabled:(BOOL)value;

/**
 * 获取日志文件
 *
 * @param finishBlock 获取日志文件回调block
 */
+ (void)syncLogData:(SyncDataBlock)finishBlock;

/**
 * 删除日志数据
 */
+ (void)clearLogData;

@end
