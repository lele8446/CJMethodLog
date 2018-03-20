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

//获取方法参数
FOUNDATION_EXPORT BOOL setMethodArguments(va_list argList,NSInvocation *invocation,NSInteger index, char *argumentType) {
    
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

FOUNDATION_EXPORT NSInvocation *cjlMethodInvocation(Class cls, SEL originSelector, id target) {
    NSString *originSelectorStr = NSStringFromSelector(originSelector);
    SEL newSelecotr = createNewSelector(originSelector);
    
    NSMethodSignature *signature = [cls instanceMethodSignatureForSelector:originSelector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = target;
    invocation.selector = newSelecotr;
    
    NSString *targetDescription = [target description];
    BOOL isInstance = isInstanceType(targetDescription)?YES:NO;
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
            _CJDeep --;
            
            if (_CJDeep == -1) {
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

@end
