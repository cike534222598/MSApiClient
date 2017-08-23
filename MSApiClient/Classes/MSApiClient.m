//
//  MSApiClient.m
//  MSWireless
//
//  Created by 菅帅博 on 2017/7/30.
//  Copyright © 2017年 菅帅博. All rights reserved.
//
#import "MSApiClient.h"
#import "YYCache.h"
#import "AFNetworkActivityIndicatorManager.h"
#import <CommonCrypto/CommonDigest.h>

#define MSLog(_content_) NSLog(@"\n**************** Start Log ****************\n%@\n**************** End Log ****************",_content_);

#pragma mark - ApiErrorResponse
@implementation ApiErrorResponse

@end

#pragma mark - ApiCache
@implementation MSApiCache

static NSString *const NetworkResponseCache = @"NetworkResponseCache";
static YYCache *_dataCache;


+ (void)initialize {
    
    _dataCache = [YYCache cacheWithName:NetworkResponseCache];
    
}

+ (void)setApiCache:(id)apiCache URL:(NSString *)URL parameters:(NSDictionary *)parameters {
    
    NSString *cacheKey = [self cacheKeyWithURL:URL parameters:parameters];
    //异步缓存,不会阻塞主线程
    [_dataCache setObject:apiCache forKey:cacheKey withBlock:nil];
    
}

+ (id)apiCacheForURL:(NSString *)URL parameters:(NSDictionary *)parameters {
    
    NSString *cacheKey = [self cacheKeyWithURL:URL parameters:parameters];
    return [_dataCache objectForKey:cacheKey];
    
}

+ (NSInteger)getAllApiCacheSize {
    
    return [_dataCache.diskCache totalCost];
    
}

+ (void)removeAllApiCache {
    
    [_dataCache.diskCache removeAllObjects];
    
}

+ (NSString *)cacheKeyWithURL:(NSString *)URL parameters:(NSDictionary *)parameters {
    
    if(!parameters){return URL;};
    
    // 将参数字典转换成字符串
    NSData *stringData = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:nil];
    NSString *paraString = [[NSString alloc] initWithData:stringData encoding:NSUTF8StringEncoding];
    
    // 将URL与转换好的参数字符串拼接在一起,成为最终存储的KEY值
    NSString *cacheKey = [NSString stringWithFormat:@"%@%@",URL,paraString];
    
    return cacheKey;
    
}

@end


#pragma mark - ApiRequest
static MSApiClient *_shareClient = nil;
static OSSClient *_aliyunClient = nil;
static NSMutableArray *_allSessionTask;

NSString *const MS_API_ENDPOINT = @"oss-cn-hangzhou.aliyuncs.com";
NSString * const MS_API_PUBLIC_BUCKET = @"mobile-pub";
NSString * const MS_API_PRIVATE_BUCKET = @"mobile-pri";
NSString * const MS_API_MOAPUBLIC_BUCKET = @"weizhimoa";

@implementation MSApiClient

+ (instancetype)shareClient {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shareClient = [[MSApiClient alloc] init];
        _shareClient.MS_API_ROOTURL = @"http://192.168.2.227:8888";
        _shareClient.MS_API_APIKEY = @"anon_viphrm_com";
        _shareClient.MS_API_APISECURITY = @"5941A997F4684889A2BD57C4D3AF05F65EA56F2C7EBC4466B2DF2335934474DC";
        _shareClient.MS_API_DEVICETOKEN = @"";
        _shareClient.MS_API_VALIDITYTIME = 60 * 30;
        
        //https
        NSSet *certificates = [AFSecurityPolicy certificatesInBundle:[NSBundle mainBundle]];
        AFSecurityPolicy *policy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate withPinnedCertificates:certificates];
        [policy setValidatesDomainName:YES];
        [policy setAllowInvalidCertificates:YES];
        _shareClient.securityPolicy = policy;

        //请求、返回值 配置
        _shareClient.requestSerializer = [AFJSONRequestSerializer serializer];
        _shareClient.responseSerializer = [AFJSONResponseSerializer serializer];
        _shareClient.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/html", @"text/json", @"text/plain", @"text/javascript", @"text/xml", @"image/*", nil];
        _shareClient.requestSerializer.timeoutInterval = 30.f;
        _shareClient.securityPolicy.allowInvalidCertificates = NO;
        [AFNetworkActivityIndicatorManager sharedManager].enabled = YES;
    });
    return _shareClient;
    
}


- (MSNetworkStatus)networkStatus {
    
    MSReachability *reachability = [MSReachability reachabilityForInternetConnection];
    return [reachability currentReachabilityStatus];
    
}


- (NSMutableArray *)allSessionTask {
    
    if (!_allSessionTask) {
        _allSessionTask = @[].mutableCopy;
    }
    return _allSessionTask;
    
}

- (void)cancelAllRequest {
    
    @synchronized(self)
    {
        [[self allSessionTask] enumerateObjectsUsingBlock:^(NSURLSessionTask  *_Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
            [task cancel];
        }];
        [[self allSessionTask] removeAllObjects];
    }
    
}

- (void)cancelRequestWithURL:(NSString *)URL {
    
    if (!URL) { return; }
    @synchronized (self)
    {
        [[self allSessionTask] enumerateObjectsUsingBlock:^(NSURLSessionTask  *_Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
            
            if ([task.currentRequest.URL.absoluteString hasPrefix:URL]) {
                [task cancel];
                [[self allSessionTask] removeObject:task];
                *stop = YES;
            }
        }];
    }
    
}

#pragma mark - Request
- (NSURLSessionTask *)GET:(NSString *)URL parameters:(NSDictionary *)parameters responseCache:(ApiCache)responseCache success:(ApiSuccess)success failure:(ApiFailed)failure {
    
    //读取缓存
    responseCache ? responseCache([MSApiCache apiCacheForURL:URL parameters:parameters]) : nil;
    
    NSURLSessionTask *sessionTask = [_shareClient GET:[self disposeURL:URL parameters:parameters] parameters:parameters progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        //对数据进行异步缓存
        responseCache ? [MSApiCache setApiCache:responseObject URL:URL parameters:parameters] : nil;

        [[self allSessionTask] removeObject:task];
        success ? success(responseObject) : nil;
#ifdef DEBUG
        NSString *content = [NSString stringWithFormat:@"URL = %@\nHeader = %@\nParameters = %@\nResponseObject = %@",[NSString stringWithFormat:@"%@/%@",self.MS_API_ROOTURL,URL],task.currentRequest.allHTTPHeaderFields,parameters?parameters:@"无参数",responseObject];
        MSLog(content);
#endif
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        ApiErrorResponse *errorResponse = [self handlerApiTask:task error:error];
        [[self allSessionTask] removeObject:task];
        failure ? failure(errorResponse) : nil;
#ifdef DEBUG
        NSString *content = [NSString stringWithFormat:@"URL = %@\nHeader = %@\nParameters = %@\nErrorCode = %ld\nErrorMsg = %@",[NSString stringWithFormat:@"%@/%@",self.MS_API_ROOTURL,URL],task.currentRequest.allHTTPHeaderFields,parameters?parameters:@"无参数",errorResponse.code,errorResponse.msg];
        MSLog(content);
#endif
    }];
    
    sessionTask ? [[self allSessionTask] addObject:sessionTask] : nil ;
    return sessionTask;
    
}


- (NSURLSessionTask *)POST:(NSString *)URL parameters:(NSDictionary *)parameters responseCache:(ApiCache)responseCache success:(ApiSuccess)success failure:(ApiFailed)failure {
    
    //读取缓存
    responseCache ? responseCache([MSApiCache apiCacheForURL:URL parameters:parameters]) : nil;
    
    NSURLSessionTask *sessionTask = [_shareClient POST:[self disposeURL:URL parameters:parameters] parameters:parameters progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        //对数据进行异步缓存
        responseCache ? [MSApiCache setApiCache:responseObject URL:URL parameters:parameters] : nil;
        
        [[self allSessionTask] removeObject:task];
        success ? success(responseObject) : nil;
#ifdef DEBUG
        NSString *content = [NSString stringWithFormat:@"URL = %@\nHeader = %@\nParameters = %@\nResponseObject = %@",[NSString stringWithFormat:@"%@/%@",self.MS_API_ROOTURL,URL],task.currentRequest.allHTTPHeaderFields,parameters?parameters:@"无参数",responseObject];
        MSLog(content);
#endif
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        ApiErrorResponse *errorResponse = [self handlerApiTask:task error:error];
        [[self allSessionTask] removeObject:task];
        failure ? failure(errorResponse) : nil;
#ifdef DEBUG
        NSString *content = [NSString stringWithFormat:@"URL = %@\nHeader = %@\nParameters = %@\nErrorCode = %ld\nErrorMsg = %@",[NSString stringWithFormat:@"%@/%@",self.MS_API_ROOTURL,URL],task.currentRequest.allHTTPHeaderFields,parameters?parameters:@"无参数",errorResponse.code,errorResponse.msg];
        MSLog(content);
#endif
    }];
    
    sessionTask ? [[self allSessionTask] addObject:sessionTask] : nil ;
    return sessionTask;

}


- (NSURLSessionTask *)PUT:(NSString *)URL parameters:(NSDictionary *)parameters responseCache:(ApiCache)responseCache success:(ApiSuccess)success failure:(ApiFailed)failure {
    
    //读取缓存
    responseCache ? responseCache([MSApiCache apiCacheForURL:URL parameters:parameters]) : nil;
    
    NSURLSessionTask *sessionTask = [_shareClient PUT:[self disposeURL:URL parameters:parameters] parameters:parameters success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        //对数据进行异步缓存
        responseCache ? [MSApiCache setApiCache:responseObject URL:URL parameters:parameters] : nil;
        
        [[self allSessionTask] removeObject:task];
        success ? success(responseObject) : nil;
#ifdef DEBUG
        NSString *content = [NSString stringWithFormat:@"URL = %@\nHeader = %@\nParameters = %@\nResponseObject = %@",[NSString stringWithFormat:@"%@/%@",self.MS_API_ROOTURL,URL],task.currentRequest.allHTTPHeaderFields,parameters?parameters:@"无参数",responseObject];
        MSLog(content);
#endif
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        ApiErrorResponse *errorResponse = [self handlerApiTask:task error:error];
        [[self allSessionTask] removeObject:task];
        failure ? failure(errorResponse) : nil;
#ifdef DEBUG
        NSString *content = [NSString stringWithFormat:@"URL = %@\nHeader = %@\nParameters = %@\nErrorCode = %ld\nErrorMsg = %@",[NSString stringWithFormat:@"%@/%@",self.MS_API_ROOTURL,URL],task.currentRequest.allHTTPHeaderFields,parameters?parameters:@"无参数",errorResponse.code,errorResponse.msg];
        MSLog(content);
#endif
    }];
    
    sessionTask ? [[self allSessionTask] addObject:sessionTask] : nil ;
    return sessionTask;

}

- (void)UPLOAD_FilePath:(NSString *)filePath appCode:(NSString *)appCode bucketType:(MSBucketType)bucketType progress:(ApiProgress)progress success:(ApiSuccess)success failure:(ApiFailed)failure {
    
    _aliyunClient = [[OSSClient alloc] initWithEndpoint:MS_API_ENDPOINT credentialProvider:[self getCredentialWithBucketType:bucketType]];
    
    NSString *bucketName = @"";
    switch (bucketType) {
        case MS_Public_Bucket:
            bucketName = MS_API_PUBLIC_BUCKET;
            break;
        case MS_Private_Bucket:
            bucketName = MS_API_PRIVATE_BUCKET;
            break;
        case Moa_Public_Bucket:
            bucketName = MS_API_MOAPUBLIC_BUCKET;
            break;
            
        default:
            break;
    }
    
    NSString *objectKey = [OSSUtil fileMD5String:filePath];
    NSString *fileExtenion = [self fileSuffixWithFileData:[NSData dataWithContentsOfFile:filePath]];
    if (fileExtenion) {
        objectKey = [objectKey stringByAppendingString:fileExtenion];
    }
    
    OSSPutObjectRequest *request = [OSSPutObjectRequest new];
    request.bucketName = bucketName;
    request.objectKey = objectKey;
    request.uploadingFileURL = [NSURL fileURLWithPath:filePath];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSProgress *uploadProgress = [[NSProgress alloc] init];
        uploadProgress.totalUnitCount = totalBytesExpectedToSend;
        uploadProgress.completedUnitCount = totalByteSent;
        dispatch_sync(dispatch_get_main_queue(), ^{
            progress ? progress(uploadProgress) : nil;
        });
    };
    
    OSSTask * putTask = [_aliyunClient putObject:request];
    [putTask continueWithBlock:^id(OSSTask *task) {
        if (bucketType == MS_Private_Bucket) {
            task = [_aliyunClient presignConstrainURLWithBucketName:bucketName withObjectKey:objectKey withExpirationInterval:self.MS_API_VALIDITYTIME];
        }else{
            task = [_aliyunClient presignPublicURLWithBucketName:bucketName withObjectKey:objectKey];
        }
        
        if (!task.error) {
            [self uploadStatisticsWithAppCode:appCode bucket:bucketName URL:task.result];
            success ? success(task.result) : nil;
#ifdef DEBUG
            NSString *content = [NSString stringWithFormat:@"上传成功\nURL = %@",task.result];
            MSLog(content);
#endif
        } else {
            ApiErrorResponse *errorResponse = [self handlerApiError:task.error];
            failure ? failure(errorResponse) : nil;
#ifdef DEBUG
            NSString *content = [NSString stringWithFormat:@"上传失败\nErrorCode = %ld\nErrorMsg = %@",errorResponse.code,errorResponse.msg];
            MSLog(content);
#endif
        }
        return nil;
    }];

}

- (void)UPLOAD_Data:(NSData *)fileData appCode:(NSString *)appCode bucketType:(MSBucketType)bucketType progress:(ApiProgress)progress success:(ApiSuccess)success failure:(ApiFailed)failure {
    
    _aliyunClient = [[OSSClient alloc] initWithEndpoint:MS_API_ENDPOINT credentialProvider:[self getCredentialWithBucketType:bucketType]];
    
    NSString *bucketName = @"";
    switch (bucketType) {
        case MS_Public_Bucket:
            bucketName = MS_API_PUBLIC_BUCKET;
            break;
        case MS_Private_Bucket:
            bucketName = MS_API_PRIVATE_BUCKET;
            break;
        case Moa_Public_Bucket:
            bucketName = MS_API_MOAPUBLIC_BUCKET;
            break;
            
        default:
            break;
    }
    NSString *objectKey = [[OSSUtil dataMD5String:fileData] stringByAppendingString:[self fileSuffixWithFileData:fileData]];
    
    OSSPutObjectRequest *request = [OSSPutObjectRequest new];
    request.bucketName = bucketName;
    request.objectKey = objectKey;
    request.uploadingData = fileData;
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSProgress *uploadProgress = [[NSProgress alloc] init];
        uploadProgress.totalUnitCount = totalBytesExpectedToSend;
        uploadProgress.completedUnitCount = totalByteSent;
        dispatch_sync(dispatch_get_main_queue(), ^{
            progress ? progress(uploadProgress) : nil;
        });
    };
    
    OSSTask * putTask = [_aliyunClient putObject:request];
    [putTask continueWithBlock:^id(OSSTask *task) {
        if (bucketType == MS_Private_Bucket) {
            task = [_aliyunClient presignConstrainURLWithBucketName:bucketName withObjectKey:objectKey withExpirationInterval:self.MS_API_VALIDITYTIME];
        }else{
            task = [_aliyunClient presignPublicURLWithBucketName:bucketName withObjectKey:objectKey];
        }
        
        if (!task.error) {
            [self uploadStatisticsWithAppCode:appCode bucket:bucketName URL:task.result];
            success ? success(task.result) : nil;
#ifdef DEBUG
            NSString *content = [NSString stringWithFormat:@"上传成功\nURL = %@",task.result];
            MSLog(content);
#endif
        } else {
            ApiErrorResponse *errorResponse = [self handlerApiError:task.error];
            failure ? failure(errorResponse) : nil;
#ifdef DEBUG
            NSString *content = [NSString stringWithFormat:@"上传失败\nErrorCode = %ld\nErrorMsg = %@",errorResponse.code,errorResponse.msg];
            MSLog(content);
#endif
        }
        return nil;
    }];

}

- (NSURLSessionTask *)DOWNLOAD:(NSString *)URL fileDir:(NSString *)fileDir progress:(ApiProgress)progress success:(ApiSuccess)success failure:(ApiFailed)failure {
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[self disposeURL:URL parameters:nil]]];
    __block NSURLSessionDownloadTask *downloadTask = [_shareClient downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            progress ? progress(downloadProgress) : nil;
        });
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        NSString *downloadDir = [NSTemporaryDirectory() stringByAppendingPathComponent:fileDir ? fileDir : @""];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        [fileManager createDirectoryAtPath:downloadDir withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *filePath = [downloadDir stringByAppendingPathComponent:response.suggestedFilename];
        return [NSURL fileURLWithPath:filePath];
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        [[self allSessionTask] removeObject:downloadTask];
        if(failure && error) {
            ApiErrorResponse *errorResponse = [self handlerApiError:error];
            failure(errorResponse);
#ifdef DEBUG
            NSString *content = [NSString stringWithFormat:@"下载失败\nErrorCode = %ld\nErrorMsg = %@",errorResponse.code,errorResponse.msg];
            MSLog(content);
#endif
            return;
        };
        success ? success([filePath.absoluteString substringFromIndex:7] /** NSURL->NSString*/) : nil;
#ifdef DEBUG
        NSString *content = [NSString stringWithFormat:@"下载成功\nFilePath = %@",[filePath.absoluteString substringFromIndex:7]];
        MSLog(content);
#endif
    }];
    
    [downloadTask resume];
    downloadTask ? [[self allSessionTask] addObject:downloadTask] : nil ;
    return downloadTask;

}


#pragma mark - Aliyun
- (id<OSSCredentialProvider>)getCredentialWithBucketType:(MSBucketType)bucketType {
    
    NSString *path = @"system/aliyun/sts";
    
    id<OSSCredentialProvider> credential = [[OSSFederationCredentialProvider alloc] initWithFederationTokenGetter:^OSSFederationToken * {
        
        OSSTaskCompletionSource * taskSource = [OSSTaskCompletionSource taskCompletionSource];
        
        [self GET:path parameters:nil responseCache:nil success:^(id responseObject) {
            [taskSource setResult:responseObject];
        } failure:^(ApiErrorResponse *error) {
            NSError *taskError = [[NSError alloc] initWithDomain:error.msg code:error.code userInfo:nil];
            [taskSource setError:taskError];
        }];
        
        [taskSource.task waitUntilFinished];
        
        if (taskSource.task.error) {
            return nil;
        } else {
            NSDictionary * object = taskSource.task.result;
            OSSFederationToken * token = [OSSFederationToken new];
            token.tAccessKey = [object objectForKey:@"accessKeyId"];
            token.tSecretKey = [object objectForKey:@"accessKeySecret"];
            token.tToken = [object objectForKey:@"securityToken"];
            token.expirationTimeInGMTFormat = [object objectForKey:@"expiration"];
            return token;
        }
    }];
    return credential;
}


#pragma mark - Method
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    
    [_shareClient.requestSerializer setValue:value forHTTPHeaderField:field];
    
}


- (NSString *)fileSuffixWithFileData:(NSData *)fileData
{
    if (fileData.length < 2) {
        NSLog(@"文件损坏");
        return nil;
    }
    
    int char1 = 0 ,char2 = 0 ;
    [fileData getBytes:&char1 range:NSMakeRange(0, 1)];
    [fileData getBytes:&char2 range:NSMakeRange(1, 1)];
    NSString *fileType = [NSString stringWithFormat:@"%i%i",char1,char2];
    
    if ([fileType isEqualToString:@"255216"]) {
        return @".jpg";
    }else if ([fileType isEqualToString:@"13780"]){
        return @".png";
    }else if ([fileType isEqualToString:@"7173"]){
        return @".gif";
    }else if ([fileType isEqualToString:@"6677"]){
        return @".bmp";
    }else if ([fileType isEqualToString:@"6787"]){
        return @".swf";
    }else if ([fileType isEqualToString:@"102100"]){
        return @".txt";
    }else if ([fileType isEqualToString:@"6033"]){
        return @".html";
    }else if ([fileType isEqualToString:@"8297"]){
        return @".rar";
    }else if ([fileType isEqualToString:@"8075"]){
        return @".zip";
    }else if ([fileType isEqualToString:@"6063"]){
        return @".xml";
    }else if ([fileType isEqualToString:@"117115"]){
        return @".cs";
    }else if ([fileType isEqualToString:@"119105"]){
        return @".js";
    }
    return nil;
}


- (NSString *)md5String:(NSString *)string {
    if (string == nil || string.length == 0) {
        return nil;
    }
    
    const char *value = [string UTF8String];
    unsigned char outputBuffer[CC_MD5_DIGEST_LENGTH];
    CC_MD5(value, (CC_LONG)strlen(value), outputBuffer);
    
    NSMutableString *outputString = [[NSMutableString alloc] initWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    
    for (NSInteger i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [outputString appendFormat:@"%02x",outputBuffer[i]];
    }
    
    return outputString;
}


#pragma mark - 内外部URL处理
- (NSString *)disposeURL:(NSString *)URL parameters:(NSDictionary *)parameters {
    
    if ([URL rangeOfString:@"http://"].location != NSNotFound || [URL rangeOfString:@"https://"].location != NSNotFound) {
        return URL;
    }
    
    [self signWithParameters:parameters];
    return [NSString stringWithFormat:@"%@/%@",self.MS_API_ROOTURL,URL];
    
}


#pragma mark - 签名处理
- (void)signWithParameters:(NSDictionary *)parameters {
    
    
    NSString *apiKey = self.MS_API_APIKEY;
    NSString *apiSecurity = self.MS_API_APISECURITY;
    NSString *deviceType = @"1";
    NSString *deviceToken = self.MS_API_DEVICETOKEN;
    NSString *appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *timestamp = [NSString stringWithFormat:@"%ld",(NSInteger)ceilf([[NSDate date] timeIntervalSince1970] * 1000.f)];

    NSMutableDictionary *signDictionary = parameters ? parameters.mutableCopy : @{}.mutableCopy;
    
    [signDictionary setValue:timestamp forKey:@"timestamp"];
    
    NSArray *keyArray = [[signDictionary allKeys] sortedArrayUsingSelector:@selector(compare:)];
    
    NSMutableArray *sortArray = @[].mutableCopy;
    
    for (NSString *key in keyArray) {
        [sortArray addObject:[NSString stringWithFormat:@"%@=%@",key,signDictionary[key]]];
    }
    
    NSString *sign = [NSString stringWithFormat:@"%@%@",[sortArray componentsJoinedByString:@"&"],[NSString stringWithFormat:@"&apiSecurity=%@",apiSecurity]];
    
    [self setValue:apiKey forHTTPHeaderField:@"apiKey"];
    [self setValue:deviceType forHTTPHeaderField:@"deviceType"];
    [self setValue:deviceToken forHTTPHeaderField:@"deviceToken"];
    [self setValue:appVersion forHTTPHeaderField:@"appVersion"];
    [self setValue:timestamp forHTTPHeaderField:@"timestamp"];
    [self setValue:[self md5String:sign] forHTTPHeaderField:@"sign"];
    
}


#pragma mark - 上传统计
- (void)uploadStatisticsWithAppCode:(NSString *)appCode bucket:(NSString *)bucketName URL:(NSString *)URL {
    
    NSString *path = @"system/attachment/reg";
    
    NSMutableDictionary *parameters = @{}.mutableCopy;
    [parameters setObject:appCode forKey:@"appCode"];
    [parameters setObject:bucketName forKey:@"bucket"];
    [parameters setObject:URL forKey:@"url"];
    [parameters setObject:@"0" forKey:@"type"];
    
    [self POST:path parameters:parameters responseCache:nil success:^(id responseObject) {
        
    } failure:^(ApiErrorResponse *error) {
        
    }];
}



#pragma mark - 错误处理
- (ApiErrorResponse *)handlerApiTask:(NSURLSessionTask *)task error:(NSError *)error {
    
    ApiErrorResponse *ret = [[ApiErrorResponse alloc] init];
    
    NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
    
    if(response != nil){
        
        ret.code = response.statusCode;
        ret.msg = [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode];
        
        if(response.statusCode == 400){
            NSData *responseData = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
            
            NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData: responseData ? responseData : [NSData new] options:kNilOptions error:nil];
            
            ret = [ApiErrorResponse mj_objectWithKeyValues:responseDict];
            
            if(ret == nil || responseData == nil){
                ret.code = 400;
                ret.msg = @"抱歉，服务器发生错误";
            }
        }
        
        if([[NSString stringWithFormat:@"%ld",ret.code] isEqualToString:@"103015"] || [[NSString stringWithFormat:@"%ld",ret.code] isEqualToString:@"103016"] || [[NSString stringWithFormat:@"%ld",ret.code] isEqualToString:@"103017"] || [[NSString stringWithFormat:@"%ld",ret.code] isEqualToString:@"103026"]){

            [self cancelAllRequest];
            
        }
        
    }else{
        
        if ([self networkStatus] == MS_NotReachable) {
            ret.code = 10000;
            ret.msg = @"请检查您的网络是否正常";
        }else{
            ret.code = 10001;
            ret.msg = @"抱歉，请求超时";
        }
    }
    
    return ret;

}

- (ApiErrorResponse *)handlerApiError:(NSError *)error {
    
    ApiErrorResponse *ret = [[ApiErrorResponse alloc] init];
    ret.code = error.code;
    ret.msg = error.localizedDescription;
    return ret;
}


@end
