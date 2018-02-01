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

#ifdef DEBUG
#define CJLNSLog(...) NSLog(__VA_ARGS__)
#else
#define CJLNSLog(...)
#endif

typedef void (*_VIMP)(id, SEL, ...);
typedef id (*_IMP)(id, SEL, ...);

static NSString *_methodPrefix = @"cjlMethod_";/*新增方法前缀*/
static BOOL _forwardInvocation = NO;/*标识是否为消息转发*/
static NSMutableArray *_hookedClassList = nil;/*保存已被hook的类名*/
static NSMutableDictionary *_classMethodMap = nil;/*记录已被hook的类的方法列表*/
static NSInteger _deep = -1;/*调用方法层级*/

#pragma mark - Function Define
BOOL isInMainBundle(Class hookClass);
BOOL haveHookClass(Class hookClass);
BOOL isCanHook(Method method, const char *returnType);
BOOL isInBlackList(NSString *methodName);
SEL createNewSelector(SEL originalSelector);
BOOL isStructType(const char *argumentType);
BOOL isInstanceType(NSString *str);
BOOL forwardInvocationReplaceMethod(Class cls, SEL originSelector, char *returnType);
//获取结构体名称
NSString *structName(const char *argumentType);
//设置方法参数
BOOL setMethodArguments(va_list argList,NSInvocation *invocation,NSInteger index, char *argumentType);
BOOL cjlHookMethod(Class cls, SEL originSelector, char *returnType);
NSInvocation *cjlMethodInvocation(Class cls, SEL originSelector, id target);

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
    if (isInBlackList(selectorName)) {
        return NO;
    }
    
    if ([selectorName rangeOfString:_methodPrefix].location != NSNotFound) {
        return NO;
    }
    
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

SEL createNewSelector(SEL originalSelector) {
    NSString *oldSelectorName = NSStringFromSelector(originalSelector);
    NSString *newSelectorName = [NSString stringWithFormat:@"%@%@",_methodPrefix,oldSelectorName];
    SEL newSelector = NSSelectorFromString(newSelectorName);
    return newSelector;
}

BOOL isStructType(const char *argumentType) {
    NSString *typeString = [NSString stringWithUTF8String:argumentType];
    return ([typeString hasPrefix:@"{"] && [typeString hasSuffix:@"}"]);
}

BOOL isInstanceType(NSString *str) {
    return ([str hasPrefix:@"<"] && [str hasSuffix:@">"]);
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
    
//    Method forwardingTargetMethod = class_getInstanceMethod(cls, @selector(forwardingTargetForSelector:));
////    _IMP originMethod_IMP = (_IMP)method_getImplementation(forwardingTargetMethod);
//    method_setImplementation(forwardingTargetMethod, imp_implementationWithBlock(^(id target, SEL aSelector){
//        CJLNSLog(@"target = %@",target);
//        return [[WZQMessageStub alloc] initWithTarget:target selector:aSelector];
    
//        NSString *targetDescription = [target description];
//        BOOL isInstance = isInstanceType(targetDescription)?YES:NO;
//        Class targetClass = isInstance?[target class]:object_getClass(target);
//        if (class_respondsToSelector(targetClass, originSelector)) {
//            return [[WZQMessageStub alloc] initWithTarget:target selector:aSelector];
//        }else{
//            return (id)originMethod_IMP(target,@selector(forwardingTargetForSelector:),aSelector);
//        }

//    }));
    
//    Method forwardInvocationMethod = class_getInstanceMethod(cls, @selector(forwardInvocation:));
//    _VIMP originMethod_IMP = (_VIMP)method_getImplementation(forwardInvocationMethod);
//    method_setImplementation(forwardInvocationMethod, imp_implementationWithBlock(^(id target, NSInvocation *invocation){
//
//        SEL originSelector = invocation.selector;
//        NSString *targetDescription = [target description];
//        BOOL isInstance = isInstanceType(targetDescription)?YES:NO;
//        Class targetClass = isInstance?[target class]:object_getClass(target);
//        if (class_respondsToSelector(targetClass, originSelector)) {
//
//            _deep ++;
//            NSString *originSelectorStr = NSStringFromSelector(originSelector);
//            NSMutableString *methodlog = [[NSMutableString alloc]initWithCapacity:3];
//            for (NSInteger deepLevel = 0; deepLevel <= _deep; deepLevel ++) {
//                [methodlog appendString:@"-"];
//            }
//            if (isInstance) {
//                [methodlog appendFormat:@" %s: -%@",class_getName(targetClass),originSelectorStr];
//            }else{
//                [methodlog appendFormat:@" %s: +%@",class_getName(targetClass),originSelectorStr];
//            }
//            CJLNSLog(@"%@",methodlog);
//
//            [invocation setSelector:createNewSelector(originSelector)];
//            [invocation setTarget:target];
//            [invocation invoke];
//            _deep --;
//
//        }
//        //如果target实例本身已经实现了对无法执行的方法的消息转发(forwardInvocation:)，则这里要还原其本来的实现
//        else {
//            originMethod_IMP(target,@selector(forwardInvocation:),invocation);
//        }
//        if (_deep == -1) {
//            CJLNSLog(@"\n");
//        }
//    }));
    return YES;
}

NSString *structName(const char *argumentType) {
    NSString *typeString = [NSString stringWithUTF8String:argumentType];
    NSUInteger start = [typeString rangeOfString:@"{"].location;
    NSUInteger end = [typeString rangeOfString:@"="].location;
    if (end > start) {
        return [typeString substringWithRange:NSMakeRange(start + 1, end - start - 1)];
    } else {
        return nil;
    }
}

BOOL isCGRect           (const char *type) {return [structName(type) isEqualToString:@"CGRect"];}
BOOL isCGPoint          (const char *type) {return [structName(type) isEqualToString:@"CGPoint"];}
BOOL isCGSize           (const char *type) {return [structName(type) isEqualToString:@"CGSize"];}
BOOL isCGVector         (const char *type) {return [structName(type) isEqualToString:@"CGVector"];}
BOOL isNSRange          (const char *type) {return [structName(type) isEqualToString:@"NSRange"];}
BOOL isUIOffset         (const char *type) {return [structName(type) isEqualToString:@"UIOffset"];}
BOOL isUIEdgeInsets     (const char *type) {return [structName(type) isEqualToString:@"UIEdgeInsets"];}
BOOL isCGAffineTransform(const char *type) {return [structName(type) isEqualToString:@"CGAffineTransform"];}

//获取方法参数
BOOL setMethodArguments(va_list argList,NSInvocation *invocation,NSInteger index, char *argumentType) {
    
    if (isStructType(argumentType)) {
        
        #define SET_STRUCT_ARGUMENT(_type) \
        if (is##_type(argumentType)) {\
            _type value = va_arg(argList, _type);\
            [invocation setArgument:&value atIndex:index];\
            return YES;\
        }\

        SET_STRUCT_ARGUMENT(CGRect)
        else SET_STRUCT_ARGUMENT(CGPoint)
        else SET_STRUCT_ARGUMENT(CGSize)
        else SET_STRUCT_ARGUMENT(CGVector)
        else SET_STRUCT_ARGUMENT(NSRange)
        else SET_STRUCT_ARGUMENT(UIOffset)
        else SET_STRUCT_ARGUMENT(UIEdgeInsets)
        else SET_STRUCT_ARGUMENT(CGAffineTransform)
        else {
            CJLNSLog(@"不能识别的结构体参数:%s",argumentType);
            return NO;
        }
        
    }
    else {
        
        #define SET_ARGUMENT(_type) \
        if(strcmp(@encode(_type), argumentType) == 0) \
        { \
            _type value = va_arg(argList, _type);\
            [invocation setArgument:&value atIndex:index];\
            return YES;\
        }
        
        SET_ARGUMENT(char)
        else SET_ARGUMENT(unsigned char)
        else SET_ARGUMENT(short)
        else SET_ARGUMENT(unsigned short)
        else SET_ARGUMENT(int)
        else SET_ARGUMENT(unsigned int)
        else SET_ARGUMENT(long)
        else SET_ARGUMENT(unsigned long)
        else SET_ARGUMENT(long long)
        else SET_ARGUMENT(unsigned long long)
        else SET_ARGUMENT(float)
        else SET_ARGUMENT(double)
        else SET_ARGUMENT(BOOL)
        else SET_ARGUMENT(id)
        else SET_ARGUMENT(SEL)
        else SET_ARGUMENT(char *)
        else SET_ARGUMENT(void *)
        else SET_ARGUMENT(Class)
        else {
            CJLNSLog(@"未知参数:%s",argumentType);
            return NO;
        }
    }
}

NSInvocation * cjlMethodInvocation(Class cls, SEL originSelector, id target) {
    NSString *originSelectorStr = NSStringFromSelector(originSelector);
    SEL newSelecotr = createNewSelector(originSelector);
    
    NSMethodSignature *signature = [cls instanceMethodSignatureForSelector:originSelector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = target;
    invocation.selector = newSelecotr;
    
    NSString *targetDescription = [target description];
    BOOL isInstance = isInstanceType(targetDescription)?YES:NO;
    Class targetClass = isInstance?[target class]:object_getClass(target);
    _deep ++;
    NSMutableString *methodlog = [[NSMutableString alloc]initWithCapacity:3];
    for (NSInteger deepLevel = 0; deepLevel <= _deep; deepLevel ++) {
        [methodlog appendString:@"-"];
    }
    if (isInstance) {
        [methodlog appendFormat:@" %s: -%@",class_getName(targetClass),originSelectorStr];
    }else{
        [methodlog appendFormat:@" %s: +%@",class_getName(targetClass),originSelectorStr];
    }
    CJLNSLog(@"%@",methodlog);
    
    return invocation;
}

//获取方法返回值
id getReturnValue(NSInvocation *invocation){
    const char *returnType = invocation.methodSignature.methodReturnType;
    if (returnType[0] == 'r') {
        returnType++;
    }
#define WRAP_GET_VALUE(type) \
do { \
type val = 0; \
[invocation getReturnValue:&val]; \
CJLNSLog(@"%@",@(val));\
return @(val); \
} while (0)
    if (strcmp(returnType, @encode(id)) == 0 || strcmp(returnType, @encode(Class)) == 0 || strcmp(returnType, @encode(void (^)(void))) == 0) {
        __autoreleasing id returnObj;
        [invocation getReturnValue:&returnObj];
        return returnObj;
    } else if (strcmp(returnType, @encode(char)) == 0) {
        WRAP_GET_VALUE(char);
    } else if (strcmp(returnType, @encode(int)) == 0) {
        WRAP_GET_VALUE(int);
    } else if (strcmp(returnType, @encode(short)) == 0) {
        WRAP_GET_VALUE(short);
    } else if (strcmp(returnType, @encode(long)) == 0) {
        WRAP_GET_VALUE(long);
    } else if (strcmp(returnType, @encode(long long)) == 0) {
        WRAP_GET_VALUE(long long);
    } else if (strcmp(returnType, @encode(unsigned char)) == 0) {
        WRAP_GET_VALUE(unsigned char);
    } else if (strcmp(returnType, @encode(unsigned int)) == 0) {
        WRAP_GET_VALUE(unsigned int);
    } else if (strcmp(returnType, @encode(unsigned short)) == 0) {
        WRAP_GET_VALUE(unsigned short);
    } else if (strcmp(returnType, @encode(unsigned long)) == 0) {
        WRAP_GET_VALUE(unsigned long);
    } else if (strcmp(returnType, @encode(unsigned long long)) == 0) {
        WRAP_GET_VALUE(unsigned long long);
    } else if (strcmp(returnType, @encode(float)) == 0) {
        WRAP_GET_VALUE(float);
    } else if (strcmp(returnType, @encode(double)) == 0) {
        WRAP_GET_VALUE(double);
    } else if (strcmp(returnType, @encode(BOOL)) == 0) {
        WRAP_GET_VALUE(BOOL);
    } else if (strcmp(returnType, @encode(char *)) == 0) {
        WRAP_GET_VALUE(const char *);
    } else if (strcmp(returnType, @encode(void)) == 0) {
        return @"void";
    } else {
        NSUInteger valueSize = 0;
        NSGetSizeAndAlignment(returnType, &valueSize, NULL);
        unsigned char valueBytes[valueSize];
        [invocation getReturnValue:valueBytes];
        
        return [NSValue valueWithBytes:valueBytes objCType:returnType];
    }
    return nil;
}

BOOL cjlHookMethod(Class cls, SEL originSelector, char *returnType) {
    Method originMethod = class_getInstanceMethod(cls, originSelector);
    if (originMethod == nil) {
        return NO;
    }
    
    const char *originTypes = method_getTypeEncoding(originMethod);
    IMP originIMP = method_getImplementation(originMethod);
    
    //添加一个新方法，该方法的IMP就是原方法的IMP，那么在旧方法的实现里调用新方法即可
    SEL newSelecotr = createNewSelector(originSelector);
    BOOL addSucess = class_addMethod(cls, newSelecotr, originIMP, originTypes);
    if (!addSucess) {
        NSString *str = NSStringFromSelector(newSelecotr);
        NSLog(@"class addMethod fail : %@，%@",cls,str);
        return NO;
    }
    
    // 无返回值的方法
    if (strcmp(returnType, @encode(void)) == 0) {
        
        class_replaceMethod(cls, originSelector, imp_implementationWithBlock(^(id target, ...){
            
            NSInvocation *invocation = cjlMethodInvocation(cls,originSelector,target);
            //参数类型数组
            NSMutableArray *argumentTypeArray = [NSMutableArray arrayWithCapacity:3];
            
            Method originMethod = class_getInstanceMethod(cls, originSelector);
            NSInteger argumentsNum = method_getNumberOfArguments(originMethod);
            for(int k = 2 ; k < argumentsNum; k ++) {
                char argument[250];
                memset(argument, 0, sizeof(argument));
                method_getArgumentType(originMethod, k, argument, sizeof(argument));
                NSString *argumentString = [NSString stringWithUTF8String:argument];
                [argumentTypeArray addObject:argumentString];
            }
            
            int index = 2;
            va_list argumentList;
            va_start(argumentList, target);
            while (index < argumentsNum) {
                NSString *argumentType = argumentTypeArray[index-2];
                char *typeChar = [argumentType cStringUsingEncoding:NSUTF8StringEncoding];
                BOOL argumentSet = setMethodArguments(argumentList, invocation, index, typeChar);
                index ++;
            }
            va_end(argumentList);
            
            [invocation invokeWithTarget:target];
            _deep --;
            
            if (_deep == -1) {
                CJLNSLog(@"\n");
            }
            
        }), originTypes);
        
    }else{
        
        // TODO: 有返回值的方法
        // 暂未处理
//        class_replaceMethod(cls, originSelector, originIMP, originTypes);
//        method_setImplementation(originMethod, originIMP);
        
//        class_replaceMethod(cls, originSelector, imp_implementationWithBlock(^(id target, ...){
//            
//            NSInvocation *invocation = cjlMethodInvocation(cls,originSelector,target);
//            //参数类型数组
//            NSMutableArray *argumentTypeArray = [NSMutableArray arrayWithCapacity:3];
//            
//            Method originMethod = class_getInstanceMethod(cls, originSelector);
//            NSInteger argumentsNum = method_getNumberOfArguments(originMethod);
//            for(int k = 2 ; k < argumentsNum; k ++) {
//                char argument[250];
//                memset(argument, 0, sizeof(argument));
//                method_getArgumentType(originMethod, k, argument, sizeof(argument));
//                NSString *argumentString = [NSString stringWithUTF8String:argument];
//                [argumentTypeArray addObject:argumentString];
//            }
//            
//            int index = 2;
//            va_list argumentList;
//            va_start(argumentList, target);
//            while (index < argumentsNum) {
//                NSString *argumentType = argumentTypeArray[index-2];
//                char *typeChar = [argumentType cStringUsingEncoding:NSUTF8StringEncoding];
//                BOOL argumentSet = setMethodArguments(argumentList, invocation, index, typeChar);
//                index ++;
//            }
//            va_end(argumentList);
//            
//            [invocation invokeWithTarget:target];
//            _deep --;
//            
//            if (_deep == -1) {
//                CJLNSLog(@"\n");
//            }
//            return getReturnValue(invocation);
//        }), originTypes);
    }
    return YES;
}

BOOL shouldInterceptMessage(Class cls, SEL selector) {
    NSArray *methodList = [_classMethodMap objectForKey:NSStringFromClass(cls)];
    return ([methodList containsObject:NSStringFromSelector(selector)]);
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
        _classMethodMap = [NSMutableDictionary dictionary];
    });
    [_hookedClassList removeAllObjects];
    [_classMethodMap removeAllObjects];
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
    Class superClass = class_getSuperclass(hookClass);
    [self hookClassMethod:superClass config:NO];
}

+ (void)enumerateClassMethods:(Class)hookClass {
    
    NSString *hookClassName = NSStringFromClass(hookClass);
    
    NSArray *hookClassMethodList = [_classMethodMap objectForKey:hookClassName];
    NSMutableArray *methodList = [NSMutableArray arrayWithArray:hookClassMethodList];
    
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
        free(returnType);
        
        [methodList addObject:NSStringFromSelector(selector)];
    }
    free(methods);
    
    [_hookedClassList addObject:hookClassName];
    [_classMethodMap setObject:methodList forKey:hookClassName];
}

@end


