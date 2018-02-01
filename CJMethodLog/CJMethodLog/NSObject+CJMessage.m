//
//  NSObject+CJMessage.m
//  CJMethodLog
//
//  Created by ChiJinLian on 2018/2/1.
//  Copyright © 2018年 ChiJinLian. All rights reserved.
//

#import "NSObject+CJMessage.h"
#import <objc/runtime.h>
#import "CJMethodLog.h"

SEL cj_createNewSelector(SEL originalSelector) {
    NSString *oldSelectorName = NSStringFromSelector(originalSelector);
    NSString *newSelectorName = [NSString stringWithFormat:@"cjlMethod_%@",oldSelectorName];
    SEL newSelector = NSSelectorFromString(newSelectorName);
    return newSelector;
}

#pragma mark - WZQMessageStub
@interface WZQMessageStub : NSObject

- (instancetype)initWithTarget:(id)target selector:(SEL)temporarySEL;

@end

@interface WZQMessageStub()
@property (nonatomic, unsafe_unretained) id target;
@property (nonatomic) SEL selector;
@end

@implementation WZQMessageStub

- (instancetype)initWithTarget:(id)target selector:(SEL)temporarySEL
{
    self = [super init];
    if (self) {
        _target = target;
        _selector = cj_createNewSelector(temporarySEL);
        
//        NSString *finalSELStr = [NSStringFromSelector(temporarySEL) stringByReplacingOccurrencesOfString:@"__WZQMessageTemporary_" withString:@"__WZQMessageFinal_"];
//        _selector = NSSelectorFromString(finalSELStr);
    }
    return self;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    Method m = class_getInstanceMethod(object_getClass(self.target), self.selector);
    assert(m);
    return [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(m)];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    anInvocation.target = self.target;
    anInvocation.selector = self.selector;
    
    NSLog(@"target = %@, selector = %@",self.target,NSStringFromSelector(self.selector));
    
    [anInvocation invoke];
}

@end

bool should_intercept_message(Class cls, SEL sel)
{
    return [NSStringFromSelector(sel) hasPrefix:@"cjlMethod_"];
}

void method_swizzle(Class cls, SEL origSEL, SEL newSEL)
{
    Method origMethod = class_getInstanceMethod(cls, origSEL);
    Method newMethod = class_getInstanceMethod(cls, newSEL);
    
    if (class_addMethod(cls, origSEL, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(cls, newSEL, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    } else {
        method_exchangeImplementations(origMethod, newMethod);
    }
}


@implementation NSObject (CJMessage)

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        method_swizzle(self, @selector(forwardingTargetForSelector:), @selector(wzq_forwardingTargetForSelector:));
    });
}

- (id)wzq_forwardingTargetForSelector:(SEL)temporarySEL
{
    if (shouldInterceptMessage(object_getClass(self), temporarySEL) && ![self isKindOfClass:[WZQMessageStub class]]) {
//    if (![self isKindOfClass:[WZQMessageStub class]]) {
        return [[WZQMessageStub alloc] initWithTarget:self selector:temporarySEL];
    }
    
    return [self wzq_forwardingTargetForSelector:temporarySEL];
}

@end
