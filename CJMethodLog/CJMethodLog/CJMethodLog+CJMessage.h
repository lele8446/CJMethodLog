//
//  CJMethodLog+CJMessage.h
//  CJMethodLog
//
//  Created by ChiJinLian on 2018/2/8.
//  Copyright © 2018年 ChiJinLian. All rights reserved.
//

#import "CJMethodLog.h"

#ifdef DEBUG
#define CJLNSLog(...) NSLog(__VA_ARGS__)
#else
#define CJLNSLog(...)
#endif

static NSString *_CJMethodPrefix = @"cjlMethod_";/*新增方法前缀*/
static NSInteger _CJDeep = -1;/*调用方法层级*/

static NSString *_CJMethodArgsResult = @"_CJMethodArgsResult";/*获取方法参数是否成功*/
static NSString *_CJMethodArgsListKey = @"_CJMethodArgsListKey";/*获取到的方法参数列表*/

@interface CJMethodLog (CJMessage)

/**
 判断是否为结构体类型

 @param encoding 方法字符串编码
 @return BOOL
 */
FOUNDATION_EXPORT BOOL isStructType(const char *encoding);

/**
 获取结构体参数名称

 @param argumentType 参数类型
 @return 结构体名称
 */
FOUNDATION_EXPORT NSString *structName(const char *argumentType);

/**
 创建规定前缀的方法

 @param originalSelector 旧方法
 @return SEL
 */
FOUNDATION_EXPORT SEL createNewSelector(SEL originalSelector);

/**
 判断是否为实例对象

 @param cls 判断类
 @return BOOL
 */
FOUNDATION_EXPORT BOOL isInstanceType(Class cls);

/**
 根据SEL生成NSInvocation实例

 @param cls Class类
 @param originSelector SEL方法
 @param target target对象
 @return NSInvocation
 */
FOUNDATION_EXPORT NSInvocation *cjlMethodInvocation(Class cls, SEL originSelector, id target);

/**
 获取调用方法的参数
 
 @param invocation 调用方法的NSInvocation实例
 @return 方法参数结果 { _CJMethodArgsResult: @(YES)/@(NO) 是否成功
                      _CJMethodArgsListKey: @[]         参数数组
                    }
 */
FOUNDATION_EXPORT NSDictionary *CJMethodArguments(NSInvocation *invocation);

/**
 获取方法返回值
 
 @param invocation 调用方法的NSInvocation实例
 @return 返回结果
 */
FOUNDATION_EXPORT id getReturnValue(NSInvocation *invocation);

/**
 hook Class 的 originSelector 方法

 @param cls Class
 @param originSelector SEL方法
 @param returnType 返回类型
 @return 是否hook成功
 */
FOUNDATION_EXPORT BOOL cjlHookMethod(Class cls, SEL originSelector, char *returnType);

@end
