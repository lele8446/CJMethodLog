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

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
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

- (void)viewControllerTest {
    
}

@end
