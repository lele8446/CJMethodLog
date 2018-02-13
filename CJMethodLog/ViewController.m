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
#import <mach/mach_time.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
//    [self test:CGRectMake(2, 2, 2, 2)];
    
    getTickCount();
    CFTimeInterval timeInterval1 = CACurrentMediaTime();
    CFTimeInterval timeInterval2 = CACurrentMediaTime();
    NSLog(@"timeInterval1 = %@",@(timeInterval1));
    NSLog(@"timeInterval2 = %@",@(timeInterval2));
}

- (void)test:(CGRect )arg {
    NSLog(@"arg = %@",NSStringFromCGRect(arg));
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)clickTestView:(id)sender {
    UIStoryboard *story = [UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]];
    TestViewController *aViewCtr = [story instantiateViewControllerWithIdentifier:@"TestViewController"];
    [self.navigationController pushViewController:aViewCtr animated:YES];
}

- (IBAction)clickTestTableView:(id)sender {
    UIStoryboard *story = [UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]];
    TestTableViewController *aViewCtr = [story instantiateViewControllerWithIdentifier:@"TestTableViewController"];
    [self.navigationController pushViewController:aViewCtr animated:YES];
}

uint64_t getTickCount(void) {
    static mach_timebase_info_data_t sTimebaseInfo;
    uint64_t machTime = mach_absolute_time();
    
    // Convert to nanoseconds - if this is the first time we've run, get the timebase.
    if (sTimebaseInfo.denom == 0 )
    {
        (void) mach_timebase_info(&sTimebaseInfo);
    }
    // Convert the mach time to milliseconds
    uint64_t millis = ((machTime / 1000000) * sTimebaseInfo.numer) / sTimebaseInfo.denom;
    NSLog(@"millis = %@",@(millis));
    return millis;

}

@end
