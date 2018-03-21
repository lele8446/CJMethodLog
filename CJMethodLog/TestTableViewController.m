//
//  TestTableViewController.m
//  YCMethodLogHelper
//
//  Created by ChiJinLian on 2018/1/9.
//  Copyright © 2018年 ChiJinLian. All rights reserved.
//

#import "TestTableViewController.h"
#import "CJMethodLog.h"

@interface TestTableViewController ()<UITableViewDelegate,UITableViewDataSource>
@property (nonatomic, weak) IBOutlet UITableView *tableView;
@end

@implementation TestTableViewController

- (void)dealloc {
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    static NSString *TableViewCellIdentifier = @"TableViewCellIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:TableViewCellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:TableViewCellIdentifier];
    }
    cell.textLabel.text = [NSString stringWithFormat:@"NO. %@",@(indexPath.row + 1)];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"子标题第 %@ 行",@(indexPath.row + 1)];
    return cell;
}

- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 10;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [CJMethodLog syncLogData:^void(NSData *logData) {
        NSLog(@"CJMethodLog: logData = %@",@([logData length]));
        [CJMethodLog clearLogData];
    }];
}


@end
