//
//  TestViewController.m
//  YCMethodLogHelper
//
//  Created by ChiJinLian on 2018/1/9.
//  Copyright © 2018年 ChiJinLian. All rights reserved.
//

#import "TestViewController.h"

@interface TestViewController ()
@property (nonatomic, strong)IBOutlet UILabel *label;

@end

@implementation TestViewController

+ (BOOL)resolveClassMethod:(SEL)sel {
    BOOL result = [super resolveClassMethod:sel];
    return result;
}

+ (BOOL)resolveInstanceMethod:(SEL)sel {
    BOOL result = [super resolveInstanceMethod:sel];
    return result;
}

//备援接收者
- (id)forwardingTargetForSelector:(SEL)aSelector {
    return [super forwardingTargetForSelector: aSelector];
}

//完整消息转发机制
//封装转发消息
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
//    NSLog(@"封装转发消息 aSelector = %@", NSStringFromSelector(aSelector));
    NSMethodSignature *signature = [super methodSignatureForSelector:aSelector];
    
    if (!signature) {
        signature = [NSMethodSignature signatureWithObjCTypes:"v@:"];
    }
    return signature;
}

//转发消息
- (void)forwardInvocation:(NSInvocation *)anInvocation {
    NSLog(@"转发消息 target = %@，selector = %@",anInvocation.target,NSStringFromSelector(anInvocation.selector));
}

- (void)doesNotRecognizeSelector:(SEL)aSelector {
    [super doesNotRecognizeSelector:aSelector];
}

- (void)dealloc {

}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self refreshUI];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (void)refreshUI {
    self.label.text = @"这是一个测试页面";
}

- (IBAction)clickTestMethod1:(id)sender {
    
    self.label.backgroundColor = [UIColor grayColor];
    self.label.text = @"更改了文字";
}

- (IBAction)clickTestMethod2:(id)sender {
    [self test:CGRectZero];
}

- (IBAction)clickManagerTest:(id)sender {
    [TestViewController managerTest];
}

- (CGRect)test:(CGRect)rect {
    return CGRectMake(2, 7, 199, 3);
}

+ (void)managerTest {
    
}

@end
