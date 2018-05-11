//
//  FLOWorkListViewController.m
//  FLOAPP
//
//  Created by 沈敏 on 2018/5/8.
//  Copyright © 2018年 Flolangka. All rights reserved.
//

#import "FLOWorkListViewController.h"
#import "FLOWorkListViewModel.h"
#import "UIView+FLOUtil.h"
#import "UIImage+FLOUtil.h"
#import "FLOWorkListCell.h"
#import "FLOWorkItemEditViewController.h"

#import <UIView+YYAdd.h>

@interface FLOWorkListViewController ()

{
    UIImageView *backgroundImageView;
    UIView *backgroundMaskView;
    UIScrollView *backgroundScrollView;
    
    UIView *contentView;
    float contentViewHeight;
}

@property (nonatomic, strong, readwrite) FLOWorkListViewModel *viewModel;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;

@end

@implementation FLOWorkListViewController
@dynamic viewModel;

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    contentViewHeight = MYAPPConfig.screenHeight-MYAPPConfig.statusBarHeight;
    [self createBackgroundView];
    [self createBackgroundScrollView];
    [self createContentView];
    [self createTitleView];
    
    self.tableView.frame = CGRectMake(0, 49, MYAPPConfig.screenWidth, contentViewHeight-49);
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 30, 0);
    [contentView addSubview:self.tableView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationController setNavigationBarHidden:YES animated:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [backgroundScrollView setContentOffset:CGPointMake(0, contentViewHeight) animated:YES];
}

- (void)createBackgroundView {
    //滑动时伸缩的view
    backgroundImageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    UIImage *snapshot = [[UIApplication sharedApplication].keyWindow snapshotImageAfterScreenUpdates:NO];
    backgroundImageView.image = snapshot;
    [self.view addSubview:backgroundImageView];
    
    //滑动时黑色透明的view
    backgroundMaskView = [[UIView alloc] initWithFrame:self.view.bounds];
    backgroundMaskView.backgroundColor = COLOR_HEXAlpha(0x000000, 0);
    [self.view addSubview:backgroundMaskView];
}

//用于向下滑动返回上一页
- (void)createBackgroundScrollView {
    backgroundScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, MYAPPConfig.statusBarHeight, MYAPPConfig.screenWidth, contentViewHeight)];
    backgroundScrollView.showsVerticalScrollIndicator = NO;
    backgroundScrollView.showsHorizontalScrollIndicator = NO;
    backgroundScrollView.pagingEnabled = YES;
    backgroundScrollView.bounces = NO;
    backgroundScrollView.delegate = self;
    backgroundScrollView.contentSize = CGSizeMake(MYAPPConfig.screenWidth, contentViewHeight*2);
    [self.view addSubview:backgroundScrollView];
    
    if (@available(iOS 11.0, *)) {
        backgroundScrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    } else {
        [self setAutomaticallyAdjustsScrollViewInsets:NO];
    }
}

- (void)createContentView {
    contentView = [[UIView alloc] initWithFrame:CGRectMake(0, contentViewHeight, MYAPPConfig.screenWidth, contentViewHeight)];
    [backgroundScrollView addSubview:contentView];
    
    [contentView flo_setCornerRadius:10 roundingCorners:UIRectCornerTopLeft | UIRectCornerTopRight];
    contentView.backgroundColor = COLOR_RGB(56, 64, 79);
}

- (void)createTitleView {
    [contentView addSubview:self.segmentedControl];
    
    //新建按钮
    UIButton *addBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [addBtn addTarget:self action:@selector(addButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    addBtn.frame = CGRectMake(MYAPPConfig.screenWidth-44-5, 3, 44, 44);
    [addBtn setTintColor:COLOR_HEX(0xffffff)];
    [addBtn setImageEdgeInsets:UIEdgeInsetsMake(10, 10, 10, 10)];
    [addBtn setImage:[[UIImage imageNamed:@"icon_write"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    [contentView addSubview:addBtn];
    
    //分割线
    [contentView flo_addLineMarginTop:48.5 left:0 right:0];
}

#pragma mark - get/set
- (UISegmentedControl *)segmentedControl {
    if (_segmentedControl == nil) {
        _segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Todo", @"Undo", @"Done"]];
        _segmentedControl.frame = CGRectMake((MYAPPConfig.screenWidth - 180)/2, 10, 180, 29);
        _segmentedControl.tintColor = COLOR_HEX(0xffffff);
        
        //切换数据源，刷新页面
        @weakify(self);
        [RACObserve(_segmentedControl, selectedSegmentIndex) subscribeNext:^(NSNumber *index) {
            @strongify(self);
            
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                NSArray *arr = [self.viewModel workItemViewModelsAtStatus:index.integerValue];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.viewModel.dataArr = [NSMutableArray arrayWithArray:@[arr]];
                    [self.tableView reloadData];
                });
            });
        }];
        _segmentedControl.selectedSegmentIndex = 0;
    }
    return _segmentedControl;
}

#pragma mark - UIScrollViewDelegate
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (scrollView == backgroundScrollView && scrollView.contentOffset.y == 0) {
        [self close];
    }
}

//called when setContentOffset/scrollRectVisible:animated: finishes
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    if (scrollView == backgroundScrollView && scrollView.contentOffset.y == 0) {
        [self close];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == backgroundScrollView) {
        float y = scrollView.contentOffset.y;
        backgroundMaskView.backgroundColor = COLOR_HEXAlpha(0x000000, y/contentViewHeight);
        
        float s = y/contentViewHeight*40;
        backgroundImageView.transform = CGAffineTransformMakeScale((MYAPPConfig.screenWidth-s)/MYAPPConfig.screenWidth, (contentViewHeight-s)/contentViewHeight);
    }
}

#pragma mark - action
- (void)close {
    [self dismissViewControllerAnimated:NO completion:^{
        
    }];
}

- (void)addButtonAction:(UIButton *)sender {
    FLOWorkItemEditViewController *editVC = [[FLOWorkItemEditViewController alloc] init];
    FLOWeakObj(self);
    editVC.editCompletion = ^(WorkList *item) {
        if (item) {
            [weakself showNewWorkItem:item];
        }
    };
    
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;    
    self.navigationController.interactivePopGestureRecognizer.delegate = nil;
    [self.navigationController pushViewController:editVC animated:YES];
}

- (void)showNewWorkItem:(WorkList *)item {
    if (_segmentedControl.selectedSegmentIndex == 0) {
        NSMutableArray *muarr = [NSMutableArray arrayWithArray:self.viewModel.dataArr.firstObject];
        [muarr insertObject:item atIndex:0];
        
        self.viewModel.dataArr = [NSMutableArray arrayWithArray:@[muarr]];
        [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:UITableViewRowAnimationBottom];
    }
}

#pragma mark - UITableView

- (UITableViewCell *)tableView:(UITableView *)tableView dequeueReusableCellForIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellid = @"FLOWorkListCellID";
    FLOWorkListCell *cell = [tableView dequeueReusableCellWithIdentifier:cellid];
    if (!cell) {
        cell = [[FLOWorkListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellid];
    }
    return cell;
}

- (void)configCell:(FLOWorkListCell *)cell atIndexPath:(NSIndexPath *)indexPath withObject:(FLOWorkItemViewModel *)object {
    [cell bindViewModel:object];
}

- (float)heightForRowAtIndexPath:(NSIndexPath *)indexPath withObject:(FLOWorkItemViewModel *)object {
    return object.cellHeight;
}

@end
