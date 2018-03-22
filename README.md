# CJMethodLog
### 功能
`CJMethodLog`对于Objective-C中的任意类、任意方法，均可监听其调用日志。
### 应用场景
1. 还原用户操作对应的函数调用堆栈
2. 分析各函数执行时的性能消耗情况
3. 一些难以重现bug（非crash）的分析

### 示例
下图展示了hook `TestViewController`类之后的函数调用情况
<center>
 <img src="https://upload-images.jianshu.io/upload_images/1429982-7560f633f2727ec3.gif?imageMogr2/auto-orient/strip" width="100%"/>
</center>

日志格式说明：

    - <TestViewController>  begin:  -clickManagerTest:
    -- <TestViewController>  begin:  +managerTest
    -- <TestViewController>  finish: +managerTest ; time=0.000110
    - <TestViewController>  finish: -clickManagerTest: ; time=0.000416
* 最开始的`-` 表示函数调用层级；
* `<TestViewController>` 表示当前调用函数的类名；
* `begin:` `finish:` 分别表示函数执行起始阶段（只会在设置了**CJLogMethodTimer**选项的时候出现）；
* `-clickManagerTest:` 表示实例方法，`+managerTest` 表示类方法；
* `time=0.000110` 表示函数耗时
* 之后会补充函数参数以及返回结果说明

### 使用
在 `main.m` 文件中设置需要监听的类名配置，理论上任意时刻都可以重设监听配置，但不建议这么做！！因为每次重设监听配置都会修改监听类的methodLists中方法的IMP实现，另外 `main.m`中配置可以确保所有hook类都生效，例如如果你hook的是 `AppDelegate` 类。

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
                                logOptions:CJLogDefault|CJLogMethodTimer
                                logEnabled:YES];
            return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
        }
    }
    
### 日志数据
获取日志数据使用`+ (void)syncLogData:(SyncDataBlock)finishBlock` ，你可以根据需要获取。比如这里在app启动的时候获取，判断当数据量大于10*1024的时候上传服务器并删除客户端数据。

    - (void)applicationDidBecomeActive:(UIApplication *)application {
        [CJMethodLog syncLogData:^void(NSData *logData) {
            NSLog(@"CJMethodLog: logData = %@",@([logData length]));
            if ([logData length] > 10*1024) {
                // TODO: 上传到服务器等自定义处理
                // 删除日志数据
                [CJMethodLog clearLogData];
            }
        }];
    }
    
### 实现
`CJMethodLog `调用方式如下：

	 + (void)forwardingClasses:(NSArray <NSString *>*)classNameList logOptions:(CJLogOptions)options logEnabled:(BOOL)value;
 

#### forwardingClassMethod
基于runtime的消息转发机制实现，当一个方法进入消息转发会存在以下步骤：
<table><tr><td bgcolor=#DCDCDC><font color=#3a3b3a>

1. `+resolveInstanceMethod:` (或`+resolveClassMethod:`)。允许用户在此时为该Class动态添加实现。如果有实现，并返回YES，那么重新开始`objc_msgSend`流程。同时对象会响应这个选择器，一般是因为它已经调用过class_addMethod。如果仍没实现，继续下面的动作。

2. `-forwardingTargetForSelector:`方法，尝试找到一个能响应该消息的对象。如果获取到，则直接把消息转发给它，返回非 nil 对象。否则返回 nil ，继续下面的动作。注意，这里不要返回 self ，否则会形成死循环。

3. `-methodSignatureForSelector:`方法，尝试获得一个方法签名。如果获取不到，则直接调用`-doesNotRecognizeSelector`抛出异常。如果能获取，则返回非nil：创建一个 NSlnvocation 并传给`-forwardInvocation:`。

4. `-forwardInvocation:`方法，将第3步获取到的方法签名包装成 Invocation 传入，如何处理就在这里面了，并返回非ni。

5. `-doesNotRecognizeSelector:` ，默认的实现是抛出异常。如果第3步没能获得一个方法签名，执行该步骤。
</font></td></tr></table>

*forwardingClassMethod* 运用了消息转发机制，在app启动的时候hook方法，具体流程如下：
<table><tr><td bgcolor=#DCDCDC><font color=#3a3b3a>

1. 根据`class_copyMethodList`遍历获取到指定类`aClass`的所有方法
2. 获取当前方法`originMethod`的IMP，同时把`originMethod`的IMP替换为`_objc_msgForward`，使得调用该方法的时候自动触发消息转发机制
3. 新增规定前缀开头的方法`newMethod`到`aClass`类中，`newMethod`的IMP为第2步中获取到的IMP
4. 重写当前类`-forwardInvocation:`方法的IMP为自定义的`imp_implementationWithBlock`，最后在自定义block里注入方法调用日志，同时使用`NSInvocation`调用第三步中新增的方法`newMethod`，从而还原当前方法本来的实现
</font></td></tr></table>

**不足，子类父类不能同时hook同名方法！！！**

**原因：** 当hook的类存在继承关系时，由于对于父类、子类同名的方法都换成了相同的IMP即`_objc_msgForward`，在执行父类方法时，虽然触发的是`objc_msgSendSuper`，但获取到的IMP却是同一个，会形成死循环。而在Hook之前，`objc_msgSendSuper`拿到的是`super_imp`, `objc_msgSend`拿到是`imp`，从而不会有问题

### 更多
* 解决`self` `super` 上下文调用的问题
* 解决`CJLogMethodArgs`(函数参数) `CJLogMethodReturnValue`(函数返回值) 选项的实现
* 欢迎各位大神`star` `issue`，帮忙解决难题

### 许可证
CJMethodLog 使用 MIT 许可证，详情见 LICENSE 文件

### 相关介绍
[CJMethodLog（一）Runtime原理：从监控还原APP运行的每一行代码说起](https://www.jianshu.com/p/9838c7d93087)<br>
[CJMethodLog 二：从监控还原APP运行的每一行代码说起](https://www.jianshu.com/p/f35024d1be05)
