//
//  WebAppCleanController.m
//  CCDemo
//
//  Created by jw on 6/29/16.
//  Copyright © 2016 jw. All rights reserved.
//

#import "WebAppCleanController.h"
#import "CCCandyWebCache.h"

@interface WebAppCleanController ()<UITableViewDelegate,UITableViewDataSource>
@property (nonatomic,strong) UITableView* tableView;
@property (nonatomic,copy) NSMutableArray<CCWebAppInfo*>* webappInfos;
@end
@implementation WebAppCleanController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    _tableView = [[UITableView alloc]init];
    [self.view addSubview:_tableView];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _webappInfos = [[CCCandyWebCache defaultWebCache].cacheManager allWebAppInfos].mutableCopy;
    
}

- (void)viewWillLayoutSubviews
{
    _tableView.frame = self.view.bounds;
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _webappInfos.count + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"tableviewcell"];
    if (!cell) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"tableviewcell"];
        UIColor *randomRGBColor = [[UIColor alloc] initWithRed:arc4random()%256/256.0
                                                         green:arc4random()%256/256.0
                                                          blue:arc4random()%256/256.0
                                                         alpha:0.3];
        cell.backgroundColor = randomRGBColor;
    }
    if (indexPath.row == 0) {
        cell.textLabel.text = @"清除所有webapp";
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@字节",@([[CCCandyWebCache defaultWebCache].cacheManager diskSizeOfWebApps])];
    }else{
        cell.textLabel.text = [NSString stringWithFormat:@"webapp:%@",_webappInfos[indexPath.row - 1].name];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@字节",@(_webappInfos[indexPath.row - 1].diskSize)];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0) {
        [[CCCandyWebCache defaultWebCache].cacheManager clearCacheOfWebApps];
        _webappInfos = @[].mutableCopy;
    }else{
        [[CCCandyWebCache defaultWebCache].cacheManager clearCacheOfWebAppWithName:_webappInfos[indexPath.row - 1].name];
        [_webappInfos removeObjectAtIndex:indexPath.row - 1];
    }
    [_tableView reloadData];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return  80;
}

@end
