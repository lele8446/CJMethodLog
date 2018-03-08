//
//  CJMethodLog.m
//  CJMethodLog
//
//  Created by ChiJinLian on 2018/1/29.
//  Copyright © 2018年 ChiJinLian. All rights reserved.
//

#import "CJMethodLog.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <UIKit/UIKit.h>
#import "CJMethodLog+CJMessage.h"

#import "CJLogger.h"

typedef void (*_VIMP)(id, SEL, ...);
typedef id (*_IMP)(id, SEL, ...);

static NSString *_logFileName = nil;/*沙盒文件夹名称*/
static NSMutableArray *_hookedClassList = nil;/*保存已被hook的类名*/
static NSMutableDictionary *_hookClassMethodDic = nil;/*记录已被hook的类的方法列表*/
static CJLogger *_logger;

#pragma mark - Function Define
BOOL isInMainBundle(Class hookClass);/*判断是否为自定义类*/
BOOL haveHookClass(Class hookClass);
BOOL enableHook(Method method, const char *returnType);
BOOL inBlackList(NSString *methodName);
BOOL forwardInvocationReplaceMethod(Class cls, SEL originSelector, char *returnType, CJLogOptions options);

#pragma mark - Function implementation

CJLogger *logger() {
    if (!_logger) {
        _logger = [[CJLogger alloc]initWithFileName:_logFileName];
    }
    return _logger;
}

BOOL isInMainBundle(Class hookClass) {
    BOOL inMainBundle = NO;
    NSBundle *mainBundle = [NSBundle bundleForClass:hookClass];
    if (mainBundle == [NSBundle mainBundle]) {
        inMainBundle = YES;
    }
    return inMainBundle;
}

BOOL haveHookClass(Class hookClass) {
    NSString *className = NSStringFromClass(hookClass);
    return ([_hookedClassList containsObject:className]);
}

BOOL enableHook(Method method, const char *returnType) {
    //若在黑名单中则不处理
    NSString *selectorName = NSStringFromSelector(method_getName(method));
    if (inBlackList(selectorName)) return NO;
    
    if ([selectorName rangeOfString:_CJMethodPrefix].location != NSNotFound) return NO;
    
    return YES;
}

BOOL inBlackList(NSString *methodName) {
    static NSArray *defaultBlackList = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultBlackList = @[/*UIViewController的:*/
                             @".cxx_destruct",
                             @"dealloc",
                             @"_isDeallocating",
                             @"release",
                             @"autorelease",
                             @"retain",
                             @"Retain",
                             @"_tryRetain",
                             @"copy",
                             /*UIView的:*/
                             @"nsis_descriptionOfVariable:",
                             /*NSObject的:*/
                             @"respondsToSelector:",
                             @"class",
                             @"allowsWeakReference",
                             @"retainWeakReference",
                             @"init",
                             @"resolveInstanceMethod:",
                             @"resolveClassMethod:",
                             @"forwardingTargetForSelector:",
                             @"methodSignatureForSelector:",
                             @"forwardInvocation:",
                             @"doesNotRecognizeSelector:",
                             @"description",
                             @"debugDescription",
                             @"self",
                             @"beginBackgroundTaskWithExpirationHandler:",
                             @"beginBackgroundTaskWithName:expirationHandler:",
                             @"endBackgroundTask:",
                             @"lockFocus",
                             @"lockFocusIfCanDraw",
                             @"lockFocusIfCanDraw"
                             ];
    });
    return ([defaultBlackList containsObject:methodName]);
}

BOOL forwardInvocationReplaceMethod(Class cls, SEL originSelector, char *returnType, CJLogOptions options) {
    Method originMethod = class_getInstanceMethod(cls, originSelector);
    if (originMethod == nil) {
        return NO;
    }
    const char *originTypes = method_getTypeEncoding(originMethod);
    IMP msgForwardIMP = _objc_msgForward;
#if !defined(__arm64__)
    if (isStructType(returnType)) {
        //Reference JSPatch:
        //In some cases that returns struct, we should use the '_stret' API:
        //http://sealiesoftware.com/blog/archive/2008/10/30/objc_explain_objc_msgSend_stret.html
        //NSMethodSignature knows the detail but has no API to return, we can only get the info from debugDescription.
        NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:originTypes];
        if ([methodSignature.debugDescription rangeOfString:@"is special struct return? YES"].location != NSNotFound) {
            msgForwardIMP = (IMP)_objc_msgForward_stret;
        }
    }
#endif
    
    IMP originIMP = method_getImplementation(originMethod);
    if (originIMP == nil || originIMP == msgForwardIMP) {
        return NO;
    }
    
    //添加一个新方法，该方法的IMP是原方法的IMP，并且在hook到的forwardInvocation里调用新方法
    SEL newSelecotr = createNewSelector(originSelector);
    BOOL addSucess = class_addMethod(cls, newSelecotr, originIMP, originTypes);
    if (!addSucess) {
        NSString *str = NSStringFromSelector(newSelecotr);
        CJLNSLog(@"class addMethod fail : %@，%@",cls,str);
        return NO;
    }
    
    //替换当前方法的IMP为msgForwardIMP，从而在调用时候触发消息转发
    class_replaceMethod(cls, originSelector, msgForwardIMP, originTypes);
    
    Method forwardInvocationMethod = class_getInstanceMethod(cls, @selector(forwardInvocation:));
    _VIMP originMethod_IMP = (_VIMP)method_getImplementation(forwardInvocationMethod);
    method_setImplementation(forwardInvocationMethod, imp_implementationWithBlock(^(id target, NSInvocation *invocation){
        
        SEL originSelector = invocation.selector;
        BOOL isInstance = isInstanceType(target);
        Class targetClass = isInstance?[target class]:object_getClass(target);
        if (class_respondsToSelector(targetClass, originSelector)) {
            
            _CJDeep ++;
            NSString *originSelectorStr = NSStringFromSelector(originSelector);
            NSMutableString *methodlog = [[NSMutableString alloc]initWithCapacity:3];
            for (NSInteger deepLevel = 0; deepLevel <= _CJDeep; deepLevel ++) {
                [methodlog appendString:@"-"];
            }
            
            [methodlog appendFormat:@" <%@> ",targetClass];
            
            CFTimeInterval startTimeInterval = 0;
            BOOL logTimer = NO;
            if (options & CJLogMethodTimer) {
                logTimer = YES;
                //TODO:参数处理
                [methodlog appendFormat:@" begin: "];
                startTimeInterval = CACurrentMediaTime();
            }
            
            if (options & CJLogMethodArgs) {
                //TODO:调用方法拼接参数处理
            }
            
            
            if (isInstance) {
                [methodlog appendFormat:@" -%@",originSelectorStr];
            }else{
                [methodlog appendFormat:@" +%@",originSelectorStr];
            }
            
            if (options & CJLogMethodReturnValue) {
                //TODO:函数返回值
            }
            
            CJLNSLog(@"%@",methodlog);
            [logger() flushAllocationStack:[NSString stringWithFormat:@"%@\n",methodlog]];
            
            [invocation setSelector:createNewSelector(originSelector)];
            [invocation setTarget:target];            
            [invocation invoke];
            
            if (logTimer) {
                [methodlog setString:[methodlog stringByReplacingOccurrencesOfString:@"begin: " withString:@"finish:"]];
                CFTimeInterval endTimeInterval = CACurrentMediaTime();
                [methodlog appendFormat:@" ; time=%f",(endTimeInterval-startTimeInterval)];
                CJLNSLog(@"%@",methodlog);
                [logger() flushAllocationStack:[NSString stringWithFormat:@"%@\n",methodlog]];
            }

            _CJDeep --;
            
        }
        //如果target实例本身已经实现了对无法执行的方法的消息转发(forwardInvocation:)，则这里要还原其本来的实现
        else {
            originMethod_IMP(target,@selector(forwardInvocation:),invocation);
        }
        if (_CJDeep == -1) {
            CJLNSLog(@"\n");
            [logger() flushAllocationStack:@"\n"];
        }
    }));
    return YES;
}


BOOL shouldInterceptMessage(Class cls, SEL selector) {
    NSArray *methodList = [_hookClassMethodDic objectForKey:NSStringFromClass(cls)];
    return ([methodList containsObject:NSStringFromSelector(selector)]);
}

#pragma mark - CJMethodLog implementation
@implementation CJMethodLog

+ (void)forwardingClasses:(NSArray <NSString *>*)classNameList logOptions:(CJLogOptions)options logFileName:(NSString *)logFileName {
    _logFileName = logFileName;
    [self forwardInvocationCommonInstall:YES];
    for (NSString *className in classNameList) {
        Class hookClass = NSClassFromString(className);
        [self hookClasses:hookClass forwardMsg:YES fromConfig:YES logOptions:options];
    }
}

+ (void)hookClasses:(NSArray <NSString *>*)classNameList logOptions:(CJLogOptions)options {
    [self forwardInvocationCommonInstall:NO];
    for (NSString *className in classNameList) {
        Class hookClass = NSClassFromString(className);
        [self hookClasses:hookClass forwardMsg:NO fromConfig:YES logOptions:options];
    }
}

+ (void)forwardInvocationCommonInstall:(BOOL)forwardInvocation {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _hookedClassList = [NSMutableArray array];
        _hookClassMethodDic = [NSMutableDictionary dictionary];
    });
    [_hookedClassList removeAllObjects];
    [_hookClassMethodDic removeAllObjects];
}

/**
 hook 指定类方法

 @param hookClass  指定类
 @param forwardMsg 是否采用消息转发机制
 @param fromConfig 指定类是否从配置获取
 @param options    记录日志选项
 */
+ (void)hookClasses:(Class)hookClass forwardMsg:(BOOL)forwardMsg fromConfig:(BOOL)fromConfig logOptions:(CJLogOptions)options {
    if (!hookClass) return;
    if (haveHookClass(hookClass)) return;
    
    if (fromConfig) {
        [self enumerateMethods:hookClass forwardMsg:forwardMsg logOptions:options];
    }else{
        if (isInMainBundle(hookClass)) {
            [self enumerateMethods:hookClass forwardMsg:forwardMsg logOptions:options];
        }
    }
}

+ (void)enumerateMethods:(Class)hookClass forwardMsg:(BOOL)forwardMsg logOptions:(CJLogOptions)options {
    [self enumerateClassMethods:hookClass forwardMsg:forwardMsg logOptions:options];
    [self enumerateMetaClassMethods:hookClass forwardMsg:forwardMsg logOptions:options];
    [self enumerateSuperclassMethods:hookClass forwardMsg:forwardMsg logOptions:options];
}

+ (void)enumerateMetaClassMethods:(Class)hookClass forwardMsg:(BOOL)forwardMsg logOptions:(CJLogOptions)options {
    //获取元类，处理类方法。object_getClass获取的isa指针即是元类
    Class metaClass = object_getClass(hookClass);
    [self enumerateClassMethods:metaClass forwardMsg:forwardMsg logOptions:options];
}

+ (void)enumerateSuperclassMethods:(Class)hookClass forwardMsg:(BOOL)forwardMsg logOptions:(CJLogOptions)options {
//    //hook 父类方法
//    Class superClass = class_getSuperclass(hookClass);
//    [self hookClasses:superClass forwardMsg:forwardMsg fromConfig:NO logOptions:options];
}

+ (void)enumerateClassMethods:(Class)hookClass forwardMsg:(BOOL)forwardMsg logOptions:(CJLogOptions)options {
    
    NSString *hookClassName = NSStringFromClass(hookClass);
    
    NSArray *hookClassMethodList = [_hookClassMethodDic objectForKey:hookClassName];
    NSMutableArray *methodList = [NSMutableArray arrayWithArray:hookClassMethodList];
    
    //属性的 set 与 get 方法不hook
    NSMutableArray *propertyMethodList = [NSMutableArray array];
    unsigned int propertyCount = 0;
    objc_property_t *properties = class_copyPropertyList(hookClass, &propertyCount);
    for (int i = 0; i < propertyCount; i++) {
        objc_property_t property = properties[i];
        NSString *propertyName = [[NSString alloc]initWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        [propertyMethodList addObject:propertyName];
        
        NSString *firstCharacter = [propertyName substringToIndex:1];
        firstCharacter = [firstCharacter uppercaseString];
        NSString *endCharacter = [propertyName substringFromIndex:1];
        NSMutableString *propertySetName = [[NSMutableString alloc]initWithString:@"set"];
        [propertySetName appendString:firstCharacter];
        [propertySetName appendString:endCharacter];
        [propertySetName appendString:@":"];
        [propertyMethodList addObject:propertySetName];
    }
    
    
    unsigned int outCount;
    Method *methods = class_copyMethodList(hookClass,&outCount);
    
    for (int i = 0; i < outCount; i ++) {
        Method tempMethod = *(methods + i);
        SEL selector = method_getName(tempMethod);
        
        BOOL needHook = YES;
        for (NSString *selStr in propertyMethodList) {
            SEL propertySel = NSSelectorFromString(selStr);
            if (selector == propertySel) {
                needHook = NO;
                break;
            }
        }
        
        if (needHook) {
            char *returnType = method_copyReturnType(tempMethod);
            
            if (forwardMsg) {
                /*
                 * 方案一：利用消息转发，hook forwardInvocation: 方法
                 */
                BOOL canHook = enableHook(tempMethod, returnType);
                if (canHook) {
                    forwardInvocationReplaceMethod(hookClass, selector, returnType, options);
                }
            }else{
                /*
                 * 方案二：hook每一个方法
                 */
                cjlHookMethod(hookClass, selector, returnType);
            }
            free(returnType);
            
            [methodList addObject:NSStringFromSelector(selector)];
        }
        
    }
    free(methods);
    
    [_hookedClassList addObject:hookClassName];
    [_hookClassMethodDic setObject:methodList forKey:hookClassName];
}

@end


