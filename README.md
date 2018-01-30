# CJMethodLog
### 功能
`CJMethodLog`对于Objective-C中的任意类、任意方法，均可以监听其调用时的日志。
### 应用场景
1. 还原用户操作对应的函数调用堆栈
2. 分析各函数执行时的性能消耗情况
3. 一些难以重现bug（非crash）的分析

### 示例
下图展示了根据操作`TestViewController`类各函数的调用情况
<center>
 <img src="http://oz3eqyeso.bkt.clouddn.com/YCMethodLog.gif" width="100%"/>
</center>

### 使用
在`-application: didFinishLaunchingWithOptions:`中设置需要监听的类名，建议写在该方法的最开始位置

    - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
        
        /*
         * 方案一：利用消息转发，hook指定类的调用方法
         */
        [CJMethodLog forwardingClassMethod:@[
                                             @"TestViewController",
                                             @"TestTableViewController"
                                             ]];
        /*
         * 方案二：hook指定类的每一个方法
         */
    //    [CJMethodLog hookClassMethod:@[
    //                                   @"TestViewController",
    //                                   @"TestTableViewController"
    //                                   ]];
        return YES;
    }
    
### 实现
`CJMethodLog `包含以下两种调用方式，注意！！！！两种调用方法互斥，不可同时调用

* + (void)forwardingClassMethod:(NSArray <NSString *>*)classNameList;
* + (void)hookClassMethod:(NSArray <NSString *>*)classNameList;

#### forwardingClassMethod
方案一基于runtime的消息转发机制实现，当一个方法进入消息转发会存在以下步骤：
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

#### hookClassMethod

方案二的原理是直接替换每一个方法的IMP实现，流程如下：
<table><tr><td bgcolor=#DCDCDC><font color=#3a3b3a>

1. 根据`class_copyMethodList`遍历获取到指定类`aClass`的所有方法
2. 获取当前方法`originMethod`的IMP，同时把`originMethod`的IMP替换为自定义的`imp_implementationWithBlock`
3. 新增规定前缀开头的方法`newMethod`到`aClass`类中，`newMethod`的IMP为第2步中获取到的IMP
4. originMethod调用的时候会进入`imp_implementationWithBlock`，在该block中注入方法调用日志，同时读取当前方法的参数（注意！！这里的参数是不确定的！包括参数类型不确定以及参数个数不确定两方面），并将获取到的参数赋予`NSInvocation`，然后调用第三步中新增的方法`newMethod`，最后获取方法执行后的返回值

</font></td></tr></table>
**不足，无法hook以自定义结构体作为参数或返回值的方法！！！**

**原因：** 参数或者返回值的获取，都需要预先确定当前值的数据类型，而自定义结构体的类型是无法预知的，这个貌似无解。。。

### 更多
* 解决方案一、方案二的不足
* 日志收集。当前只是实现了函数调用日志的打印，最终应该实现日志的本地化写入
* 欢迎各位大神`star` `issue`，帮忙解决难题
