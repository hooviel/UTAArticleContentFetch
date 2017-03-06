//
//  UTAArticleContentFetch.m
//  UTANews
//
//  Created by David on 16/8/19.
//  Copyright © 2016年 UTA. All rights reserved.
//

#import "UTAArticleContentFetch.h"

#import "API+Doome.h"
#import "API+Sundaily.h"
#import "API+Yesdaily.h"
#import "API+Movie.h"
#import "YYCache.h"
#import "YYDiskCache.h"

@import UIKit;

@interface UTAArticleContentFetch () <UIWebViewDelegate>

@property (nonatomic, copy) CompletionBlock completionBlock;
@property (nonatomic, copy) NSString *link;
@property (nonatomic, assign) UTAHost host;

@end

@implementation UTAArticleContentFetch {
    UIWebView *_webView;
    YYCache *_cacheDoome;
    YYCache *_cacheSundaily;
    YYCache *_cacheYesdaily;
    // 下载码的缓存
    YYCache *_cacheDownloadCode;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _cacheDoome = [YYCache cacheWithName:@"com.doome.article"];
        _cacheDoome.diskCache.ageLimit = 7*24*3600;

        _cacheSundaily = [YYCache cacheWithName:@"com.sundaily.article"];
        _cacheSundaily.diskCache.ageLimit = 7*24*3600;

        _cacheYesdaily = [YYCache cacheWithName:@"com.yesdaily.article"];
        _cacheYesdaily.diskCache.ageLimit = 7*24*3600;

        _cacheDownloadCode = [YYCache cacheWithName:@"com.1115hd.downloadcode"];
        _cacheDownloadCode.diskCache.ageLimit = 3600;
    }
    return self;
}

+ (instancetype)shareInstance {
    static UTAArticleContentFetch *fetch;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fetch = [[UTAArticleContentFetch alloc] init];
    });
    return  fetch;
}

/**
 获取文章内容，默认请求超时时间为30s

 @param artId artId description
 @param host host description
 @param completionBlock completionBlock description
 */
- (void)getContentWithArtId:(NSInteger)artId host:(UTAHost)host completionBlock:(CompletionBlock)completionBlock {
    [self getContentWithArtId:artId host:host completionBlock:completionBlock timeout:30];
}


/**
 获取文章内容，默认请求超时时间为30s

 @param artId artId description
 @param host host description
 @param completionBlock completionBlock description
 @param timeout timeout description
 */
- (void)getContentWithArtId:(NSInteger)artId host:(UTAHost)host completionBlock:(CompletionBlock)completionBlock timeout:(NSTimeInterval)timeout {
    if (_webView) {
        _webView.delegate = nil;
        [_webView loadHTMLString:@"" baseURL:nil];
        _webView = nil;
    }
    if (_completionBlock) {
        _completionBlock(@"", nil);
        _completionBlock = nil;
    }

    _host = host;

    YYCache *cache = nil;
    NSString *api = @"";
    switch (_host) {
        case UTAHostDoome:
            api = API_DMArticleDetail;
            cache = _cacheDoome;
            break;
        case UTAHostSundaily:
            api = API_SDArticleDetail;
            cache = _cacheSundaily;
            break;
        case UTAHostYesdaily:
            api = API_YDArticleDetail;
            cache = _cacheYesdaily;
            break;
        default:
            break;
    }

    NSString *link = [api stringByAppendingString:[@(artId) stringValue]];
    self.completionBlock = completionBlock;
    self.link = link;
    NSString *content = (id)[cache objectForKey:link];
    if (content) {
        _completionBlock(content, [NSURL URLWithString:link]);
        _completionBlock = nil;
    }
    else {
        _webView = [UIWebView new];
        _webView.delegate = self;

        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:link]];
        req.timeoutInterval = timeout;
        [_webView loadRequest:req];
        _webView.delegate = self;
    }
}

/**
 通过下载码获取下载信息

 @param link 下载码
 @param completionBlock completionBlock description
 @param timeout timeout description
 */
- (void)getConentWithDownloadLink:(NSString *)link completionBlock:(CompletionBlock)completionBlock timeout:(NSTimeInterval)timeout {
    if (_webView) {
        _webView.delegate = nil;
        [_webView loadHTMLString:@"" baseURL:nil];
        _webView = nil;
    }

    _host = UTAHostMovie;

    self.completionBlock = completionBlock;
    self.link = link;
    NSString *content = (id)[_cacheDownloadCode objectForKey:link];
    if (content) {
        _completionBlock(content, [NSURL URLWithString:link]);
    }
    else {
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:link]];
        req.timeoutInterval = timeout;
        NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        NSURLSessionDataTask *task = [session dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSRange begin = [string rangeOfString:@"<br />"];
            NSRange end = [string rangeOfString:@"</div>"];
            string = [string substringWithRange:NSMakeRange(begin.location+begin.length, end.location-(begin.location+begin.length))];
            [_cacheDownloadCode setObject:string forKey:self.link];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (_completionBlock) {
                    _completionBlock(string, [NSURL URLWithString:self.link]);
                    _completionBlock = nil;
                }
            });
        }];
        [task resume];
    }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    NSString *content;
    if (_host==UTAHostMovie) {
        content = [_webView stringByEvaluatingJavaScriptFromString:@"document.getElementsByTagName('div')[0].innerHTML"];
        NSRange begin = [content rangeOfString:@"{"];
        content = [content substringFromIndex:begin.location];
    }
    else {
        NSString *js = @"function rmAllStyle(){removeChildrenAttrs(document.body);} function removeChildrenAttrs(nd) {nd.removeAttribute('style');nd.removeAttribute('class');for (var i=0; i<nd.children.length;i++) {removeChildrenAttrs(nd.children[i]);}} rmAllStyle();";
        [_webView stringByEvaluatingJavaScriptFromString:js];
        content = [_webView stringByEvaluatingJavaScriptFromString:@"document.body.innerHTML"];

        if (content.length) {
            YYCache *cache = nil;
            switch (_host) {
                case UTAHostDoome:
                    cache = _cacheDoome;
                    break;
                case UTAHostSundaily:
                    cache = _cacheSundaily;
                    break;
                case UTAHostYesdaily:
                    cache = _cacheYesdaily;
                    break;
                default:
                    break;
            }
            
            [cache setObject:content forKey:self.link];
        }
    }

    if (self.completionBlock) {
        self.completionBlock(content?:@"", _webView.request.URL);
        _completionBlock = nil;
    }
    _webView.delegate = nil;
    [_webView loadHTMLString:@"" baseURL:nil];
    _webView = nil;
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    switch (error.code) {
        case NSURLErrorTimedOut: {
            /*
             如果网页获取不到主机地址，说明从来没有加载成功过，可以认为是当前网页超时
             如果超时的主机地址和当前网页的主机地址相同，则认为是网页超时
             */
            NSURL *urlError = error.userInfo[NSURLErrorFailingURLErrorKey];
            if (webView.request.URL.host && ![urlError.host isEqualToString:webView.request.URL.host]) break;
        }
        case NSURLErrorNotConnectedToInternet: {
            if (self.completionBlock) {
                self.completionBlock(error.localizedFailureReason?:@"", _webView.request.URL);
                _completionBlock = nil;
            }
        } break;

        default:
            break;
    }
}

@end
