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

static BOOL _forwardInvocation = NO;/*标识是否为消息转发*/
static NSMutableArray *_hookedClassList = nil;/*保存已被hook的类名*/

#pragma mark - Function Define
BOOL isInMainBundle(Class hookClass);
BOOL haveHookClass(Class hookClass);
BOOL isCanHook(Method method, const char *returnType);
BOOL isInBlackList(NSString *methodName);
BOOL forwardInvocationReplaceMethod(Class cls, SEL originSelector, char *returnType);


#pragma mark - Function implementation

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

BOOL isCanHook(Method method, const char *returnType) {
    //若在黑名单中则不处理
    NSString *selectorName = NSStringFromSelector(method_getName(method));
    if (isInBlackList(selectorName)) return NO;
    
    if ([selectorName rangeOfString:_CJMethodPrefix].location != NSNotFound) return NO;
    
    return YES;
}

BOOL isInBlackList(NSString *methodName) {
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

BOOL forwardInvocationReplaceMethod(Class cls, SEL originSelector, char *returnType) {
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
        NSLog(@"class addMethod fail : %@，%@",cls,str);
        return NO;
    }
    
    //替换当前方法的IMP为msgForwardIMP，从而在调用时候触发消息转发
    class_replaceMethod(cls, originSelector, msgForwardIMP, originTypes);
    
    Method forwardInvocationMethod = class_getInstanceMethod(cls, @selector(forwardInvocation:));
    _VIMP originMethod_IMP = (_VIMP)method_getImplementation(forwardInvocationMethod);
    method_setImplementation(forwardInvocationMethod, imp_implementationWithBlock(^(id target, NSInvocation *invocation){
        
        SEL originSelector = invocation.selector;
        NSString *targetDescription = [target description];
        BOOL isInstance = isInstanceType(targetDescription)?YES:NO;
        Class targetClass = isInstance?[target class]:object_getClass(target);
        if (class_respondsToSelector(targetClass, originSelector)) {
            
            _CJDeep ++;
            NSString *originSelectorStr = NSStringFromSelector(originSelector);
            NSMutableString *methodlog = [[NSMutableString alloc]initWithCapacity:3];
            for (NSInteger deepLevel = 0; deepLevel <= _CJDeep; deepLevel ++) {
                [methodlog appendString:@"-"];
            }
            if (isInstance) {
                [methodlog appendFormat:@" %s: -%@",class_getName(targetClass),originSelectorStr];
            }else{
                [methodlog appendFormat:@" %s: +%@",class_getName(targetClass),originSelectorStr];
            }
            CJLNSLog(@"%@ start\n",methodlog);
//            [[CJLogger getInstance] flush_allocation_stack:methodlog];
            
            [invocation setSelector:createNewSelector(originSelector)];
            [invocation setTarget:target];            
            [invocation invoke];
            CJLNSLog(@"%@ end\n",methodlog);
            _CJDeep --;
            
        }
        //如果target实例本身已经实现了对无法执行的方法的消息转发(forwardInvocation:)，则这里要还原其本来的实现
        else {
            originMethod_IMP(target,@selector(forwardInvocation:),invocation);
        }
        if (_CJDeep == -1) {
            CJLNSLog(@"\n");
//            [[CJLogger getInstance] flush_allocation_stack:@"\n"];
        }
    }));
    return YES;
}


#pragma mark - CJMethodLog implementation
@implementation CJMethodLog

+ (void)forwardingClassMethod:(NSArray <NSString *>*)classNameList {
    [self commonInstall:YES];
    for (NSString *className in classNameList) {
        Class hookClass = NSClassFromString(className);
        [self hookClassMethod:hookClass config:YES];
    }
}

+ (void)hookClassMethod:(NSArray <NSString *>*)classNameList {
    [self commonInstall:NO];
    for (NSString *className in classNameList) {
        Class hookClass = NSClassFromString(className);
        [self hookClassMethod:hookClass config:YES];
    }
}

+ (void)commonInstall:(BOOL)forwardInvocation {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _hookedClassList = [NSMutableArray array];
    });
    [_hookedClassList removeAllObjects];
    _forwardInvocation = forwardInvocation;
}

+ (void)hookClassMethod:(Class)hookClass config:(BOOL)config {
    if (!hookClass) return;
    if (haveHookClass(hookClass)) return;
    
    if (config) {
        [self enumerateClassMethods:hookClass];
        [self enumerateMetaClassMethods:hookClass];
        
    }else{
        if (isInMainBundle(hookClass)) {
            [self enumerateClassMethods:hookClass];
            [self enumerateMetaClassMethods:hookClass];
        }
    }
}

+ (void)enumerateMetaClassMethods:(Class)hookClass {
    //获取元类，处理类方法。object_getClass获取的isa指针即是元类
    Class metaClass = object_getClass(hookClass);
    [self enumerateClassMethods:metaClass];
    
    //hook 父类方法
//    Class superClass = class_getSuperclass(hookClass);
//    [self hookClassMethod:superClass config:NO];
}

+ (void)enumerateClassMethods:(Class)hookClass {
    
    unsigned int outCount;
    Method *methods = class_copyMethodList(hookClass,&outCount);
    
    for (int i = 0; i < outCount; i ++) {
        Method tempMethod = *(methods + i);
        SEL selector = method_getName(tempMethod);
        char *returnType = method_copyReturnType(tempMethod);
        
        if (_forwardInvocation) {
            /*
             * 方案一：利用消息转发，hook forwardInvocation: 方法
             */
            BOOL canHook = isCanHook(tempMethod, returnType);
            if (canHook) {
                forwardInvocationReplaceMethod(hookClass, selector, returnType);
            }
        }else{
            /*
             * 方案二：hook每一个方法
             */
            cjlHookMethod(hookClass, selector, returnType);
        }
        
        [_hookedClassList addObject:NSStringFromClass(hookClass)];
        
        free(returnType);
    }
    free(methods);
}

@end
