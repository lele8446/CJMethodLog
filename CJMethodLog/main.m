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
         * 方案一：利用消息转发，hook指定类的调用方法
         */
        [CJMethodLog forwardingClasses:@[
                                         @"TestViewController",
                                         @"TestTableViewController"
                                         ]
                            logOptions:CJLogMethodTimer|CJLogMethodArgs
                           logFileName:nil];
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
