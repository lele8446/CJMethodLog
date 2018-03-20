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
                                         @"AppDelegate",
                                         @"TestViewController",
                                         ]
                            logOptions:CJLogDefault];
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
