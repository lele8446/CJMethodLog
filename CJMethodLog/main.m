//
//  main.m
//  CJMethodLog
//
//  Created by ChiJinLian on 2018/1/29.
//  Copyright © 2018年 ChiJinLian. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#import "CJMethodLog.h"

int main(int argc, char * argv[]) {
    @autoreleasepool {
        /*
         * 利用消息转发，hook指定类的调用方法
         */
        [CJMethodLog forwardingClasses:@[
                                         @"TestViewController",
                                         ]
                            logOptions:CJLogDefault
                            logEnabled:YES];
        
        //hook指定类的指定方法
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        [CJMethodLog forwardingInstanceMethodWithClass:@"TestTableViewController"
                                            methodList:@[
                                                         NSStringFromSelector(@selector(viewDidLoad)),
NSStringFromSelector(@selector(tableView:didSelectRowAtIndexPath:)),
                                                         ]
                                            logOptions:CJLogDefault
                                            logEnabled:YES];
#pragma clang diagnostic pop
        
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
