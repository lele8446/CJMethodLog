//
//  CJMethodLog.h
//  CJMethodLog
//
//  Created by ChiJinLian on 2018/1/29.
//  Copyright © 2018年 ChiJinLian. All rights reserved.
//

#import <Foundation/Foundation.h>

<<<<<<< HEAD
=======
FOUNDATION_EXTERN BOOL shouldInterceptMessage(Class cls, SEL selector);

>>>>>>> origin/master
/**
 任意类，任意方法的调用日志监听系统，包含以下两种调用方式：
  + forwardingClassMethod:
  + hookClassMethod:
 注意！！！！两种调用方法互斥，不可同时调用
 */
@interface CJMethodLog : NSObject

/**
 * 基于消息转发（forwardInvocation:）实现对指定类的方法调用监听
 * 注意！！！所有设置的hook类不能存在继承关系
 *
 * @param classNameList 需要hook的类名
 */
+ (void)forwardingClassMethod:(NSArray <NSString *>*)classNameList;


//TODO: 未完全实现
///**
// 监听指定类的方法调用
//
// @param classNameList 需要hook的类名
// */
//+ (void)hookClassMethod:(NSArray <NSString *>*)classNameList;

@end
