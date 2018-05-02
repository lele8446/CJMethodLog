//
//  CJMethodLog+CJMessage.m
//  CJMethodLog
//
//  Created by ChiJinLian on 2018/2/8.
//  Copyright © 2018年 ChiJinLian. All rights reserved.
//

#import "CJMethodLog+CJMessage.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

@implementation CJMethodLog (CJMessage)

FOUNDATION_EXPORT BOOL isStructType(const char *encoding) {
    return encoding[0] == _C_STRUCT_B;
}

FOUNDATION_EXPORT NSString *structName(const char *argumentType) {
    NSString *typeString = [NSString stringWithUTF8String:argumentType];
    NSUInteger start = [typeString rangeOfString:@"{"].location;
    NSUInteger end = [typeString rangeOfString:@"="].location;
    if (end > start) {
        return [typeString substringWithRange:NSMakeRange(start + 1, end - start - 1)];
    } else {
        return nil;
    }
}

FOUNDATION_EXPORT SEL createNewSelector(SEL originalSelector) {
    NSString *oldSelectorName = NSStringFromSelector(originalSelector);
    NSString *newSelectorName = [NSString stringWithFormat:@"%@%@",_CJMethodPrefix,oldSelectorName];
    SEL newSelector = NSSelectorFromString(newSelectorName);
    return newSelector;
}

FOUNDATION_EXPORT BOOL isInstanceType(Class cls) {
    return !(cls == [cls class]);
}


BOOL isCGRect           (const char *type) {return [structName(type) isEqualToString:@"CGRect"];}
BOOL isCGPoint          (const char *type) {return [structName(type) isEqualToString:@"CGPoint"];}
BOOL isCGSize           (const char *type) {return [structName(type) isEqualToString:@"CGSize"];}
BOOL isCGVector         (const char *type) {return [structName(type) isEqualToString:@"CGVector"];}
BOOL isNSRange          (const char *type) {return [structName(type) isEqualToString:@"NSRange"];}
BOOL isUIOffset         (const char *type) {return [structName(type) isEqualToString:@"UIOffset"];}
BOOL isUIEdgeInsets     (const char *type) {return [structName(type) isEqualToString:@"UIEdgeInsets"];}
BOOL isCGAffineTransform(const char *type) {return [structName(type) isEqualToString:@"CGAffineTransform"];}

/**
 获取调用方法的参数

 @param invocation 调用方法的NSInvocation实例
 @return 方法参数结果
 */
FOUNDATION_EXPORT NSDictionary *CJMethodArguments(NSInvocation *invocation) {
    NSMethodSignature *methodSignature = [invocation methodSignature];
//    NSMutableArray *argList = (methodSignature.numberOfArguments > 2 ? [NSMutableArray array] : @[]);
    NSMutableArray *argList = [NSMutableArray array];
    BOOL getSuccess = YES;
    
    for (NSUInteger i = 2; i < methodSignature.numberOfArguments; i++) {
        const char *argumentType = [methodSignature getArgumentTypeAtIndex:i];
        id arg = nil;
        
        if (isStructType(argumentType)) {
            #define GET_STRUCT_ARGUMENT(_type)\
                if (is##_type(argumentType)) {\
                    _type arg_temp;\
                    [invocation getArgument:&arg_temp atIndex:i];\
                    arg = NSStringFrom##_type(arg_temp);\
                }
            
            GET_STRUCT_ARGUMENT(CGRect)
            else GET_STRUCT_ARGUMENT(CGPoint)
            else GET_STRUCT_ARGUMENT(CGSize)
            else GET_STRUCT_ARGUMENT(CGVector)
            else GET_STRUCT_ARGUMENT(UIOffset)
            else GET_STRUCT_ARGUMENT(UIEdgeInsets)
            else GET_STRUCT_ARGUMENT(CGAffineTransform)
                
            if (arg == nil) {
                arg = @"{unknown struct}";
                if (getSuccess) {
                    getSuccess = NO;
                }
            }
        }
        
        #define GET_ARGUMENT(_type)\
            if (0 == strcmp(argumentType, @encode(_type))) {\
                _type arg_temp;\
                [invocation getArgument:&arg_temp atIndex:i];\
                arg = @(arg_temp);\
            }
        else GET_ARGUMENT(char)
        else GET_ARGUMENT(int)
        else GET_ARGUMENT(short)
        else GET_ARGUMENT(long)
        else GET_ARGUMENT(long long)
        else GET_ARGUMENT(unsigned char)
        else GET_ARGUMENT(unsigned int)
        else GET_ARGUMENT(unsigned short)
        else GET_ARGUMENT(unsigned long)
        else GET_ARGUMENT(unsigned long long)
        else GET_ARGUMENT(float)
        else GET_ARGUMENT(double)
        else GET_ARGUMENT(BOOL)
        else if (0 == strcmp(argumentType, @encode(id))) {
            __unsafe_unretained id arg_temp;
            [invocation getArgument:&arg_temp atIndex:i];
            arg = arg_temp;
        }
        else if (0 == strcmp(argumentType, @encode(SEL))) {
            SEL arg_temp;
            [invocation getArgument:&arg_temp atIndex:i];
            arg = NSStringFromSelector(arg_temp);
        }
        else if (0 == strcmp(argumentType, @encode(char *))) {
            char *arg_temp;
            [invocation getArgument:&arg_temp atIndex:i];
            arg = [NSString stringWithUTF8String:arg_temp];
        }
        else if (0 == strcmp(argumentType, @encode(void *))) {
            void *arg_temp;
            [invocation getArgument:&arg_temp atIndex:i];
            arg = (__bridge id _Nonnull)arg_temp;
        }
        else if (0 == strcmp(argumentType, @encode(Class))) {
            Class arg_temp;
            [invocation getArgument:&arg_temp atIndex:i];
            arg = arg_temp;
        }
        
        if (!arg) {
            arg = @"unknown argument";
            if (getSuccess) {
                getSuccess = NO;
            }
        }
        [argList addObject:arg];
    }
    return @{_CJMethodArgsResult:@(getSuccess),_CJMethodArgsListKey:argList};
}

/**
 获取方法返回值

 @param invocation 调用方法的NSInvocation实例
 @return 返回结果
 */
FOUNDATION_EXPORT id getReturnValue(NSInvocation *invocation) {
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

FOUNDATION_EXPORT NSInvocation *cjlMethodInvocation(Class cls, SEL originSelector, id target) {
    NSString *originSelectorStr = NSStringFromSelector(originSelector);
    SEL newSelecotr = createNewSelector(originSelector);
    
    NSMethodSignature *signature = [cls instanceMethodSignatureForSelector:originSelector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = target;
    invocation.selector = newSelecotr;
    
    BOOL isInstance = isInstanceType(cls)?YES:NO;
    Class targetClass = isInstance?[target class]:object_getClass(target);
    _CJDeep ++;
    NSMutableString *methodlog = [[NSMutableString alloc]initWithCapacity:3];
    for (NSInteger deepLevel = 0; deepLevel <= _CJDeep; deepLevel ++) {
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


FOUNDATION_EXPORT BOOL cjlHookMethod(Class cls, SEL originSelector, char *returnType) {
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
    
    __block BOOL result = YES;
    // 无返回值的方法
    if (strcmp(returnType, @encode(void)) == 0) {
        
        class_replaceMethod(cls, originSelector, imp_implementationWithBlock(^(id target, ...){
            
            NSInvocation *invocation = cjlMethodInvocation(cls,originSelector,target);
            
            //参数数组
            NSDictionary *methodArguments = CJMethodArguments(invocation);
            result = [methodArguments[_CJMethodArgsResult] boolValue];
            NSArray *argumentArray = methodArguments[_CJMethodArgsListKey];
            
            for (NSInteger i = 0; i < argumentArray.count; i++) {
                id arg = argumentArray[i];
               [invocation setArgument:&arg atIndex:i];
            }
            
            [invocation invokeWithTarget:target];
            _CJDeep --;
            
            if (_CJDeep == -1) {
                CJLNSLog(@"\n");
            }
            
        }), originTypes);
        
    }else{
//        class_replaceMethod(cls, originSelector, imp_implementationWithBlock(^(id target, ...){
//            
//            NSInvocation *invocation = cjlMethodInvocation(cls,originSelector,target);
//            
//            //参数数组
//            NSDictionary *methodArguments = CJMethodArguments(invocation);
//            result = [methodArguments[_CJMethodArgsResult] boolValue];
//            NSArray *argumentArray = methodArguments[_CJMethodArgsListKey];
//            
//            for (NSInteger i = 0; i < argumentArray.count; i++) {
//                id arg = argumentArray[i];
//                [invocation setArgument:&arg atIndex:i];
//            }
//            
//            [invocation invokeWithTarget:target];
//            _CJDeep --;
//            
//            if (_CJDeep == -1) {
//                CJLNSLog(@"\n");
//            }
//            
//            id returnValue = getReturnValue(invocation);
//            return returnValue;
//            
//        }), originTypes);
    }
    return result;
}

@end
