//
//  UTAArticleContentFetch.h
//  UTANews
//
//  Created by David on 16/8/19.
//  Copyright © 2016年 UTA. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^CompletionBlock)(NSString *content, NSURL *baseURL);


/**
 UTA 主机分类

 - UTAHostDoome: UTAHostDoome description
 - UTAHostSundaily: UTAHostSundaily description
 - UTAHostYesdaily: UTAHostYesdaily description
 */
typedef NS_ENUM(NSInteger, UTAHost) {
    UTAHostUnknow,
    UTAHostDoome,
    UTAHostSundaily,
    UTAHostYesdaily,
    UTAHostMovie // 电影域名
};

/*!
 *  自带带缓存功能，文章内容缓存7天
 */
@interface UTAArticleContentFetch : NSObject

+ (instancetype)shareInstance;

/**
 获取文章内容，默认请求超时时间为30s

 @param artId artId description
 @param host host description
 @param completionBlock completionBlock description
 */
- (void)getContentWithArtId:(NSInteger)artId host:(UTAHost)host completionBlock:(CompletionBlock)completionBlock;


/**
 获取文章内容，默认请求超时时间为30s

 @param artId artId description
 @param host host description
 @param completionBlock completionBlock description
 @param timeout timeout description
 */
- (void)getContentWithArtId:(NSInteger)artId host:(UTAHost)host completionBlock:(CompletionBlock)completionBlock timeout:(NSTimeInterval)timeout;


/**
 通过下载码获取下载信息

 @param link 下载码
 @param completionBlock completionBlock description
 @param timeout timeout description
 */
- (void)getConentWithDownloadLink:(NSString *)link completionBlock:(CompletionBlock)completionBlock timeout:(NSTimeInterval)timeout;


@end
