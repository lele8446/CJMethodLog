//
//  ViewController.m
//  YCMethodLogHelper
//
//  Created by ChiJinLian on 2018/1/9.
//  Copyright © 2018年 ChiJinLian. All rights reserved.
//

#import "ViewController.h"
#import "TestViewController.h"
#import "TestTableViewController.h"
#import "CJMethodLog.h"

@interface ViewController ()
@property (nonatomic, weak) IBOutlet UITextView *textView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)clickTestView:(id)sender {
    UIStoryboard *story = [UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]];
    TestViewController *aViewCtr = [story instantiateViewControllerWithIdentifier:@"TestViewController"];
    __weak typeof(self)wSelf = self;
    aViewCtr.disappearBlock = ^{
        [CJMethodLog syncLogData:^(NSData *logData) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *str = [[NSString alloc] initWithData:logData encoding:NSUTF8StringEncoding];
                wSelf.textView.text = str;
            });
        }];
        
    };
    [self.navigationController pushViewController:aViewCtr animated:YES];
}

- (IBAction)clickTestTableView:(id)sender {
    UIStoryboard *story = [UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]];
    TestTableViewController *aViewCtr = [story instantiateViewControllerWithIdentifier:@"TestTableViewController"];
    __weak typeof(self)wSelf = self;
    aViewCtr.disappearBlock = ^{
        [CJMethodLog syncLogData:^(NSData *logData) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *str = [[NSString alloc] initWithData:logData encoding:NSUTF8StringEncoding];
                wSelf.textView.text = str;
            });
        }];  
    };
    [self.navigationController pushViewController:aViewCtr animated:YES];
    
}

- (IBAction)clear:(id)sender {
    [CJMethodLog clearLogData];
    self.textView.text = @"";
}
@end
