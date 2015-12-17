//
//  FLOWeiboTableViewController.m
//  XMPPChat
//
//  Created by admin on 15/12/16.
//  Copyright © 2015年 Flolangka. All rights reserved.
//

#import "FLOWeiboTableViewController.h"
#import "FLOWeiboAuthorization.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AFHTTPSessionManager.h>
#import "FLOWeiboStatusModel.h"
#import "FLOWeiboStatusTableViewCell.h"
#import "FLOWeiboStatusFoolerTableViewCell.h"
#import "FLODataBaseEngin.h"

//登录认证
static NSString * const appKey = @"1780554149";
static NSString * const redirectURLStr = @"https://api.weibo.com/oauth2/default.html";
static NSString * const appSecret = @"d367d14ab1f48620350e005ff2f5290b";
static NSString * const kAccessTokenURL = @"https://api.weibo.com/oauth2/access_token";

//请求数据
static NSString * const kLoadNew      = @"loadNew";
static NSString * const kLoadMore     = @"loadMore";
static NSString * const kUsersShowURL = @"https://api.weibo.com/2/users/show.json";
static NSString * const kHomeStatusesURL = @"https://api.weibo.com/2/statuses/home_timeline.json";

//Cell标识
static NSString * const kStatusCellID = @"statusCell";
static NSString * const kFooterCellID = @"footerCell";

@interface FLOWeiboTableViewController ()<UIWebViewDelegate>

{
    AFHTTPSessionManager *sessionManager;
    FLOWeiboAuthorization *authorization;
    NSString *requestDataType;
}

@property (nonatomic, strong) NSMutableArray *dataArr;

// 声明一个存计算cell高度的实例变量
@property (nonatomic, strong) FLOWeiboStatusTableViewCell *prototypeCell;
@property (nonatomic) BOOL requestLock;//yes 加锁

@end

@implementation FLOWeiboTableViewController

- (void)awakeFromNib
{
    self.dataArr = [NSMutableArray array];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    sessionManager = [AFHTTPSessionManager manager];
    authorization = [FLOWeiboAuthorization sharedAuthorization];
    
    // 初始化prototypeCell
    self.prototypeCell = [self.tableView dequeueReusableCellWithIdentifier:kStatusCellID];
    self.requestLock = NO;
    
    [self setTitle];
    [self loadLocalData];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if ([authorization isLogin]) {
        requestDataType = kLoadNew;
        [self requestData];
    } else {
        [self showAuthorizationView];
    }
}

- (void)setTitle
{
    if ([authorization isLogin]) {
        // 第一次需要请求用户信息获取用户名，以UID_userName保存在NSUserdefaults中
        NSUserDefaults *UD = [NSUserDefaults standardUserDefaults];
        NSString *weiboUserName = [UD objectForKey:@"WeiboUserName"];
        if (weiboUserName && [weiboUserName hasPrefix:authorization.UID]) {
            self.title = [weiboUserName substringFromIndex:authorization.UID.length+1];
        } else {
            NSDictionary *parameters = @{kAccessToken:authorization.token,
                                         kUID:authorization.UID};
            [sessionManager GET:kUsersShowURL parameters:parameters progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                NSDictionary *result = (NSDictionary *)responseObject;
                self.title = result[@"screen_name"];
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                NSLog(@"请求用户信息错误>>>>%@",error.localizedDescription);
                self.title = @"微博";
            }];
        }
    } else {
        self.title = @"微博";
    }
}

#pragma mark - 进入登录页
- (void)showAuthorizationView
{
    CGSize size = [UIScreen mainScreen].bounds.size;
    UIWebView *authorizationWebView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height-64)];
    authorizationWebView.delegate = self;
    
    NSString *urlString = [NSString stringWithFormat:@"https://api.weibo.com/oauth2/authorize?client_id=%@&redirect_uri=%@&response_type=code",appKey,redirectURLStr];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
    [authorizationWebView loadRequest:request];

    [self.view addSubview:authorizationWebView];
}

#pragma mark - 注销
- (void)loginOutAction
{
    [[FLOWeiboAuthorization sharedAuthorization] logout];
    [self showAuthorizationView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - 加载数据
- (void)loadLocalData
{
    //加载数据库中数据
//    [self.dataArr addObjectsFromArray:[[FLODataBaseEngin shareInstance] selectWeiboStatus]];
    [self.tableView reloadData];
}

//请求网络数据
- (void)requestData
{
    if (!self.requestLock) {
        self.requestLock= YES;
    }else{
        return;
    }
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    [parameters setObject:authorization.token forKey:kAccessToken];
    
    // 根据不同请求类型构造参数
    if ([requestDataType isEqualToString:kLoadNew] && self.dataArr.count != 0) {
        [parameters setObject:[self.dataArr.firstObject statusID] forKey:@"since_id"];
    } else if ([requestDataType isEqualToString:kLoadMore] && self.dataArr.count != 0){
        NSInteger statusID = [[self.dataArr.lastObject statusID] integerValue];
        statusID -= 1;
        NSNumber *statusIDObj = [NSNumber numberWithInteger:statusID];
        [parameters setObject:statusIDObj forKey:@"max_id"];
    }
    
    [sessionManager GET:kHomeStatusesURL parameters:parameters progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSDictionary *result = (NSDictionary *)responseObject;
        NSArray *status = result[@"statuses"];
        
        NSMutableArray *statusModels = [NSMutableArray arrayWithCapacity:status.count];
        for (NSDictionary *statusInfo in status) {
            // 初始化model
            FLOWeiboStatusModel *statusModel = [[FLOWeiboStatusModel alloc] initWithDictionary:statusInfo];
            [statusModels addObject:statusModel];
        }
        
        if ([requestDataType isEqualToString:kLoadNew]){
            //将原有的追加到新的数组中
            [statusModels addObjectsFromArray:self.dataArr];
            self.dataArr = statusModels;
            
            // 显示更新提示框
            [self playSoundAndShowPromptViewWithStateNumber:status.count];
        } else if ([requestDataType isEqualToString:kLoadMore]){
            //追加到原有数组中
            NSMutableArray *array = [NSMutableArray arrayWithArray:self.dataArr];
            [array addObjectsFromArray:statusModels];
            self.dataArr = array;
        }
        
        //更新UI
        [self.tableView reloadData];
        
        //解锁
        self.requestLock= NO;
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"首页请求微博错误>>>>%@",error.localizedDescription);
        self.requestLock = NO;
    }];
    
}

#pragma mark - Action
- (IBAction)reportStatusAction:(UIButton *)sender {
    
}

- (IBAction)commentStatusAction:(UIButton *)sender {
    
}

- (IBAction)restatusAction:(UIControl *)sender {
    
}

- (void)goStatusDetailVCWithStatus:(FLOWeiboStatusModel *)status
{
//    FloStatusDetailVC *statusDetailVC = [storyboard instantiateViewControllerWithIdentifier:kStatusDetailVC];
//    statusDetailVC.status = status;
//
//    [self.navigationController pushViewController:statusDetailVC animated:YES];
}

#pragma mark - Table view data source delegate
-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _dataArr.count;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;
    if (indexPath.row == 0) {
        FLOWeiboStatusTableViewCell *statusCell = [tableView dequeueReusableCellWithIdentifier:kStatusCellID forIndexPath:indexPath];
        [statusCell setContentWithStatus:_dataArr[indexPath.section]];
        cell = statusCell;
    } else {
        FLOWeiboStatusFoolerTableViewCell *footerCell = [tableView dequeueReusableCellWithIdentifier:kFooterCellID forIndexPath:indexPath];
        [footerCell setValueWithStatus:_dataArr[indexPath.section]];
        cell = footerCell;
    }
    return cell;
}

-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath{
    //根据将要显示的cell，判断剩余的未刷新的cell个数
    NSInteger count =  self.dataArr.count - (indexPath.section + 1);
    if (count == 2) {
        //满足加载更多的条件
        requestDataType = kLoadMore;
        [self requestData];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    FLOWeiboStatusModel *status = _dataArr[indexPath.section];
    [self goStatusDetailVCWithStatus:status];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 2;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat height;
    if (indexPath.row == 0) {
        FLOWeiboStatusTableViewCell *cell = self.prototypeCell;
        height = [cell cellHeight4StatusModel:_dataArr[indexPath.section]]+5;
    } else {
        height = 25;
    }
    return height;
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 5;
}

-(CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 5;
}

#pragma mark - 更新数据提示框
- (void)playSoundAndShowPromptViewWithStateNumber:(NSUInteger)number
{
    AudioServicesPlaySystemSound(1302);
    
    CATextLayer *textLayer = [[CATextLayer alloc] init];
    textLayer.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 24);
    textLayer.backgroundColor = [UIColor orangeColor].CGColor;
    textLayer.foregroundColor = [UIColor whiteColor].CGColor;
    textLayer.alignmentMode = @"center";
    textLayer.fontSize = 16;
    textLayer.string = [NSString stringWithFormat:@"%lu 条新微博", number];
    
    [self.view.layer addSublayer:textLayer];
    [self performSelector:@selector(removeFromSelfLayer:) withObject:textLayer afterDelay:2];
}

- (void)removeFromSelfLayer:(CALayer *)layer
{
    [layer removeFromSuperlayer];
}

#pragma mark - 退出时将最新的20条数据保存数据库
- (void)dealloc
{
    if ([authorization isLogin] && _dataArr.count > 0) {
        if (_dataArr.count < 20) {
            [[FLODataBaseEngin shareInstance] resetWeiboDataWithStatus:_dataArr];
        } else {
            [[FLODataBaseEngin shareInstance] resetWeiboDataWithStatus:[_dataArr subarrayWithRange:NSMakeRange(0, 20)]];
        }
        
    }
}

#pragma mark - authorization Delegate
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSString *urlStr = [[request URL] absoluteString];
    if ([urlStr hasPrefix:redirectURLStr]) {
        // 取出回调url中的code值
        NSArray *result = [urlStr componentsSeparatedByString:@"code="];
        NSString *code = [result lastObject];
        
        // access_token请求
        NSDictionary *parameters = @{@"client_id":appKey,
                                     @"client_secret":appSecret,
                                     @"grant_type":kGrantType,
                                     @"code":code,
                                     @"redirect_uri":redirectURLStr};
        AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
        
        // MIMEType:媒体类型
        manager.responseSerializer.acceptableContentTypes = [NSSet setWithObject:@"text/plain"];
        [manager POST:kAccessTokenURL parameters:parameters progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            NSDictionary *result = (NSDictionary *)responseObject;
            
            // 更新授权信息
            [[FLOWeiboAuthorization sharedAuthorization] loginSuccess:result];
            
            //请求微博数据
            requestDataType = kLoadNew;
            [self requestData];
            [self setTitle];
            
            UIWebView *webView = [self.view.subviews lastObject];
            [webView removeFromSuperview];
            
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            NSLog(@"登录失败>>>>%@",error.localizedDescription);
        }];
    }
    return YES;
}


@end
