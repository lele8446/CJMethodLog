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

@interface CJMethodLog (CJMessage)

/**
 判断是否为结构体参赛

 @param argumentType 参数类型
 @return BOOL
 */
FOUNDATION_EXPORT BOOL isStructType(const char *argumentType);

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

 @param str 类描述
 @return BOOL
 */
FOUNDATION_EXPORT BOOL isInstanceType(NSString *str);

/**
 根据SEL生成NSInvocation实例

 @param cls Class类
 @param originSelector SEL方法
 @param target target对象
 @return NSInvocation
 */
FOUNDATION_EXPORT NSInvocation *cjlMethodInvocation(Class cls, SEL originSelector, id target);

/**
 设置NSInvocation参数

 @param argList 参数列表
 @param invocation invocation实例
 @param index 第index个参数
 @param argumentType 参数类型
 @return 是否设置成功
 */
FOUNDATION_EXPORT BOOL setMethodArguments(va_list argList,NSInvocation *invocation,NSInteger index, char *argumentType);

/**
 hook Class 的 originSelector 方法

 @param cls Class
 @param originSelector SEL方法
 @param returnType 返回类型
 @return 是否hook成功
 */
FOUNDATION_EXPORT BOOL cjlHookMethod(Class cls, SEL originSelector, char *returnType);

@end
