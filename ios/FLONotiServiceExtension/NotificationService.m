//
//  NotificationService.m
//  FLONotiServiceExtension
//
//  Created by 沈敏 on 2017/2/12.
//  Copyright © 2017年 Flolangka. All rights reserved.
//

#import "NotificationService.h"

@interface NotificationService ()

@property (nonatomic, strong) void (^contentHandler)(UNNotificationContent *contentToDeliver);
@property (nonatomic, strong) UNMutableNotificationContent *bestAttemptContent;

@end

@implementation NotificationService

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler {
    self.contentHandler = contentHandler;
    self.bestAttemptContent = [request.content mutableCopy];
    
    // Modify the notification content here...
    NSDictionary *userInfo = self.bestAttemptContent.userInfo;
    if (userInfo[@"PicUrl"] || userInfo[@"AudioUrl"]) {
        NSURLRequest * urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:userInfo[@"PicUrl"] ? : userInfo[@"AudioUrl"]] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:5];
        //注意使用DownloadTask
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
        NSURLSessionDownloadTask *task = [session downloadTaskWithRequest:urlRequest completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (!error) {
                NSString *path = [location.path stringByAppendingString:userInfo[@"PicUrl"] ? @".png" : @".mp3"];
                NSError *err = nil;
                NSURL * pathUrl = [NSURL fileURLWithPath:path];
                [[NSFileManager defaultManager] moveItemAtURL:location toURL:pathUrl error:nil];
                //下载完毕生成附件，添加到内容中
                UNNotificationAttachment *resource_attachment = [UNNotificationAttachment attachmentWithIdentifier:@"attachment" URL:pathUrl options:nil error:&err];
                if (resource_attachment) {
                    self.bestAttemptContent.attachments = @[resource_attachment];
                }
                if (error) {
                    NSLog(@"%@", error);
                }
                //设置为@""以后，进入app将没有启动页
                self.bestAttemptContent.launchImageName = @"";
                //回调给系统
                self.contentHandler(self.bestAttemptContent);
            } else  {
                self.contentHandler(self.bestAttemptContent);
            }
        }];
        [task resume];
    } else {
        self.contentHandler(self.bestAttemptContent);
    }
}

- (void)serviceExtensionTimeWillExpire {
    // Called just before the extension will be terminated by the system.
    // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
    self.contentHandler(self.bestAttemptContent);
}

@end