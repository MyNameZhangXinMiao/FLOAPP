//
//  FLONETEASEVideoTableViewCell.h
//  FLOAPP
//
//  Created by 360doc on 2018/4/12.
//  Copyright © 2018年 Flolangka. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FLONETEASEVideoItemViewModel.h"

@interface FLONETEASEVideoTableViewCell : UITableViewCell

@property (nonatomic, strong, readonly) FLONETEASEVideoItemViewModel *viewModel;

//显示内容
- (void)bindViewModel:(FLONETEASEVideoItemViewModel *)viewModel;

//计算cell高度
+ (float)heightWithViewModel:(FLONETEASEVideoItemViewModel *)viewModel;

@end
