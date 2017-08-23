//
//  MSApiClient.h
//  MSWireless
//
//  Created by 菅帅博 on 2017/7/30.
//  Copyright © 2017年 菅帅博. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <AFNetworking/AFNetworking.h>
#import <AliyunOSSiOS/OSSService.h>
#import "MSReachability.h"
#import "MJExtension.h"

#pragma mark - ApiErrorResponse
@interface ApiErrorResponse : NSObject

@property (nonatomic, assign) NSInteger code;
@property (nonatomic, strong) NSString *msg;

@end

#pragma mark - ApiCache
@interface MSApiCache : NSObject

/**
 *  缓存网络数据,根据请求的 URL与parameters
 *  做KEY存储数据, 这样就能缓存多级页面的数据
 *
 *  @param apiCache   服务器返回的数据
 *  @param URL        请求的URL地址
 *  @param parameters 请求的参数
 */
+ (void)setApiCache:(id)apiCache URL:(NSString *)URL parameters:(NSDictionary *)parameters;

/**
 *  根据请求的 URL与parameters 取出缓存数据
 *
 *  @param URL        请求的URL
 *  @param parameters 请求的参数
 *
 *  @return 缓存的服务器数据
 */
+ (id)apiCacheForURL:(NSString *)URL parameters:(NSDictionary *)parameters;


/**
 *  获取网络缓存的总大小 bytes(字节)
 */
+ (NSInteger)getAllApiCacheSize;


/**
 *  删除所有网络缓存,
 */
+ (void)removeAllApiCache;

@end


#pragma mark - ApiRequest
/** 请求成功的Block */
typedef void(^ApiSuccess)(id responseObject);

/** 缓存的Block */
typedef void(^ApiCache)(id responseCache);

/** 请求失败的Block */
typedef void(^ApiFailed)(ApiErrorResponse *error);

/** 上传或者下载的进度, Progress.completedUnitCount:当前大小 - Progress.totalUnitCount:总大小*/
typedef void (^ApiProgress)(NSProgress *progress);


#pragma mark - 枚举
typedef NS_ENUM(NSInteger, MSBucketType) {
    /**
     *  SmartHR公开Bucket
     */
    MS_Public_Bucket = 0,
    /**
     *  SmartHR私有Bucket
     */
    MS_Private_Bucket = 1,
    /**
     *  Moa公开BUcket
     */
    Moa_Public_Bucket = 2
};


@interface MSApiClient : AFHTTPSessionManager

@property (nonatomic, strong) NSString *MS_API_ROOTURL;         //默认：开发环境
@property (nonatomic, strong) NSString *MS_API_APIKEY;          //默认：
@property (nonatomic, strong) NSString *MS_API_APISECURITY;     //默认：
@property (nonatomic, strong) NSString *MS_API_DEVICETOKEN;     //默认：@""
@property (nonatomic, assign) double MS_API_VALIDITYTIME;       //默认：60*30

+ (instancetype)shareClient;

//网络状态
- (MSNetworkStatus)networkStatus;

//取消网络请求
- (void)cancelAllRequest;

- (void)cancelRequestWithURL:(NSString *)URL;

#pragma mark - Request
/**
 *  GET请求,自动缓存
 *
 *  @param URL           请求地址
 *  @param parameters    请求参数
 *  @param responseCache 缓存数据的回调
 *  @param success       请求成功的回调
 *  @param failure       请求失败的回调
 *
 *  @return 返回的对象可取消请求,调用cancle方法
 */
- (__kindof NSURLSessionTask *)GET:(NSString *)URL parameters:(NSDictionary *)parameters responseCache:(ApiCache)responseCache success:(ApiSuccess)success failure:(ApiFailed)failure;

/**
 *  POST请求,自动缓存
 *
 *  @param URL           请求地址
 *  @param parameters    请求参数
 *  @param responseCache 缓存数据的回调
 *  @param success       请求成功的回调
 *  @param failure       请求失败的回调
 *
 *  @return 返回的对象可取消请求,调用cancle方法
 */
- (__kindof NSURLSessionTask *)POST:(NSString *)URL parameters:(NSDictionary *)parameters responseCache:(ApiCache)responseCache success:(ApiSuccess)success failure:(ApiFailed)failure;

/**
 *  PUT请求,自动缓存
 *
 *  @param URL           请求地址
 *  @param parameters    请求参数
 *  @param responseCache 缓存数据的回调
 *  @param success       请求成功的回调
 *  @param failure       请求失败的回调
 *
 *  @return 返回的对象可取消请求,调用cancle方法
 */

- (__kindof NSURLSessionTask *)PUT:(NSString *)URL  parameters:(NSDictionary *)parameters responseCache:(ApiCache)responseCache success:(ApiSuccess)success failure:(ApiFailed)failure;


/**
 *  上传图片文件
 *
 *  @param filePath   文件路径
 *  @param progress   上传进度信息
 *  @param success    请求成功的回调
 *  @param failure    请求失败的回调
 */
- (void)UPLOAD_FilePath:(NSString *)filePath appCode:(NSString *)appCode bucketType:(MSBucketType)bucketType progress:(ApiProgress)progress success:(ApiSuccess)success failure:(ApiFailed)failure;



- (void)UPLOAD_Data:(NSData *)fileData appCode:(NSString *)appCode bucketType:(MSBucketType)bucketType progress:(ApiProgress)progress success:(ApiSuccess)success failure:(ApiFailed)failure;


/**
 *  下载文件
 *
 *  @param URL          请求地址
 *  @param fileDir      文件存储目录(默认存储目录为Tmp)
 *  @param progress     文件下载的进度信息
 *  @param success      下载成功的回调(回调参数filePath:文件的路径)
 *  @param failure      下载失败的回调
 *
 *  @return 返回NSURLSessionDownloadTask实例，可用于暂停继续，暂停调用suspend方法，开始下载调用resume方法
 */
- (__kindof NSURLSessionTask *)DOWNLOAD:(NSString *)URL fileDir:(NSString *)fileDir progress:(ApiProgress)progress success:(ApiSuccess)success failure:(ApiFailed)failure;


@end
