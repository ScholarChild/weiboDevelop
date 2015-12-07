//
//  InfoManager.m
//  DZWeibo
//
//  Created by Ibokan on 15/10/15.
//  Copyright (c) 2015年 Zero. All rights reserved.
//

#import "WBURLAnalyser.h"
#import "WBUser.h"
#import "WBStatus.h"
#import "WBURL.h"
#import "WBComment.h"

#import "MJExtension.h"
#import "AFNetworking.h"


@interface WBURLAnalyser()
{
    NSMutableArray* _infoList;
}
@end

@implementation WBURLAnalyser
#pragma mark 初始化
- (instancetype)init
{
    if (self = [super init]) {
        [self setReplaceKey];
    }
    return self;
}

- (void)setReplaceKey
{
    [WBStatus mj_setupReplacedKeyFromPropertyName:^NSDictionary*{
        return @{
                 @"statusID" : @"id"
                 };
    }];
    [WBComment mj_setupReplacedKeyFromPropertyName:^NSDictionary*{
        return @{
                 @"ID" : @"id"
                 };
    }];
    [WBUser mj_setupReplacedKeyFromPropertyName:^NSDictionary*{
        return @{
                 @"descriptionText" :@"description"
                 };
    }];
}
#pragma mark 同步请求处理，返回对象

- (NSArray *)latestHomeStatusesWithCount:(NSInteger)count;
{
    NSString* request = [NSString stringWithFormat:
                         @"https://api.weibo.com/2/statuses/home_timeline.json?%@&count=%lu",
                         [self requestKey],count];
    return [self statusesWithRequest:request];
}

- (NSArray*)lastestPersonalStatus
{
    NSString* request = [NSString stringWithFormat:
                         @"https://api.weibo.com/2/statuses/user_timeline.json?%@&screen_name=%@",
                         [self requestKey],PersonalUserName];
    return [self statusesWithRequest:request];
}

- (WBUser*)personalInfoOfCurrentUser
{
    return [self personalInfoWithUserName:PersonalUserName];
}

- (WBUser*)personalInfoWithUserName:(NSString*)userName
{
    NSURL* request = [self personalRequestWithUserName:userName];
    NSDictionary* jsonDic = [self jsonDicWithURL:request];
    WBUser* user = [WBUser mj_objectWithKeyValues:jsonDic];
    return user;
}

#pragma mark 请求构建

- (NSURL*)personalRequestWithUserName:(NSString*)userName
{
    NSString* requestString =  [NSString stringWithFormat:
                                @"https://api.weibo.com/2/users/show.json?%@&screen_name=%@",
                                [self requestKey],userName];
    return [self requestURLFromString:requestString];
}

- (NSURL*)topicSearchRequestWithSearchKeyword:(NSString*)keyWord
{
    NSString* requestString =  [NSString stringWithFormat:
                                @"https://api.weibo.com/2/search/topics.json?%@&q=%@",
                                [self requestKey],keyWord];
    return [self requestURLFromString:requestString];
}

- (NSURL*)longURLFromShortURLString:(NSString*)shortURLString
{
    NSString* requestString =  [NSString stringWithFormat:
                                @"https://api.weibo.com/2/short_url/expand.json?%@&url_short=%@",
                                [self requestKey],shortURLString];
    NSURL* shortURL =  [self requestURLFromString:requestString];
    NSDictionary* jsonDic = [self jsonDicWithURL:shortURL];
    NSDictionary* objDic = [[jsonDic  objectForKey:@"urls"] objectAtIndex:0];
    WBURL* URL = [WBURL mj_objectWithKeyValues:objDic];
    NSString* longURLString = URL.url_long;
    return [self requestURLFromString:longURLString];
}

#pragma mark 异步请求


- (void)latestHomeStatusesWithCount:(NSInteger)count didReiceverStatus:(void (^)(WBStatus*))handleStatus
                             finish:(void(^)())finishHandle  fail:(void(^)(NSError*))failHandle
{
    NSString* request = @"https://api.weibo.com/2/statuses/home_timeline.json";
    NSMutableDictionary* parametersTmp = [NSMutableDictionary dictionaryWithCapacity:3];
    [parametersTmp setDictionary:[self tokenDic]];
    [parametersTmp setObject:[NSNumber numberWithInteger:count] forKey:@"count"];
    NSDictionary* parameters = [NSDictionary dictionaryWithDictionary:parametersTmp];
    
    AFHTTPSessionManager* manager = [AFHTTPSessionManager manager];
    [manager GET:request parameters:parameters
         success:^(NSURLSessionDataTask* task ,id responseObeject){
             NSArray* stuatusDataArr = [responseObeject objectForKey:@"statuses"];
             NSArray* statuses = [self statusesFromDicArray:stuatusDataArr];
             if (handleStatus) {
                 for (WBStatus* status in statuses) {
                     handleStatus(status);
                 }
             }
             if (finishHandle) {
                 finishHandle();
             }
         }
         failure:^(NSURLSessionDataTask* task ,NSError* error){
             if (failHandle) {
                 failHandle(error);
             }
         }
     ];
}

- (NSDictionary*)tokenDic
{
    NSDictionary* tokenDic = @{};
    BOOL hasToken = (access_token != NULLString);
    BOOL hasSource = (appKey != NULLString);
    
    if (hasToken) {
        tokenDic = @{@"access_token":access_token};
    }else if (hasSource) {
        tokenDic = @{@"source":appKey};
    }else if (hasSource&&hasToken) {
        tokenDic = @{@"access_token":access_token,
                     @"source":appKey};
    }
    return tokenDic;
}


#pragma mark 内部公用函数

- (NSArray *)statusesWithRequest:(NSString*)requestString
{
    NSURL* requestURL = [self requestURLFromString:requestString];
    NSDictionary* jsonDic = [self jsonDicWithURL:requestURL];
    NSArray* stuatusDataArr = [jsonDic objectForKey:@"statuses"];
    NSArray* statuses = [self statusesFromDicArray:stuatusDataArr];
    return statuses;
}

- (NSURL*)requestURLFromString:(NSString*)requestString
{
    return [NSURL URLWithString:[requestString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
}

- (NSDictionary*)jsonDicWithURL:(NSURL*)url
{
    NSError *error;
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSData *response = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    NSDictionary *weiboDic = [NSJSONSerialization JSONObjectWithData:response
                                                             options:NSJSONReadingMutableLeaves error:&error];
    NSAssert(error == nil,@"json anaysic fail,some error happen");
    
    return weiboDic;
}

- (NSArray*)statusesFromDicArray:(NSArray*)dicArr
{
    NSMutableArray* stuatues = [[NSMutableArray alloc]initWithCapacity:1];
    for (NSDictionary* stuatusDataDic in dicArr) {
        WBStatus* aStatus = [WBStatus mj_objectWithKeyValues:stuatusDataDic];
        [stuatues addObject:aStatus];
    }
    return stuatues;
}

- (NSString*)requestKey
{
    NSString* key = @"";
    BOOL hasToken = (access_token != NULLString);
    BOOL hasSource = (appKey != NULLString);
    
    if (hasToken) {
        key = [NSString stringWithFormat:@"access_token=%@",access_token];
    }else if (hasSource) {
        key = [NSString stringWithFormat:@"source=%@",appKey];
    }else if (hasSource&&hasToken) {
        key = [NSString stringWithFormat:@"access_token=%@&source=%@",access_token,appKey];
    }
    return key;
}

@end
