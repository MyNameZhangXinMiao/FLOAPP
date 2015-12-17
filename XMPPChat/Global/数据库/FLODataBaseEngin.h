//
//  FLODataBaseEngin.h
//  XMPPChat
//
//  Created by admin on 15/12/14.
//  Copyright © 2015年 Flolangka. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FLOCollectionItem;
@class FLOBookMarkModel;

@interface FLODataBaseEngin : NSObject

+ (instancetype)shareInstance;

//清除用户的数据(将应用中的数据库替换document中的数据库)
- (void)resetDatabase;

//collectionItem
- (NSArray *)selectAllCollectionItem;
- (void)insertCollectionItem:(FLOCollectionItem *)collectionItem;
- (void)deleteCollectionItem:(FLOCollectionItem *)collectionItem;

//书签
- (NSArray *)selectAllBookMark;
- (void)insertBookMark:(FLOBookMarkModel *)bookMark;
- (void)deleteBookMark:(FLOBookMarkModel *)bookMark;

//微博数据
- (void)clearWeiboData;
- (void)resetWeiboDataWithStatus:(NSArray *)status;
- (NSArray *)selectWeiboStatus;


@end
