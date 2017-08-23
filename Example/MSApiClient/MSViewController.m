//
//  MSViewController.m
//  MSApiClient
//
//  Created by cike534222598 on 08/23/2017.
//  Copyright (c) 2017 cike534222598. All rights reserved.
//

#import "MSViewController.h"
#import "MSApiClient.h"
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonCryptor.h>

NSString *const MS_AES_KEY = @"16BytesWeiZhiKey";
NSString *const MS_AES_VECTOR = @"16-Bytes--String";
size_t const MS_AES_KEYSIZE = kCCKeySizeAES128;

@interface MSViewController ()

@end

@implementation MSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    
    NSString *path = @"account/pwd";
    
    NSMutableDictionary *parameters = @{}.mutableCopy;
    [parameters setObject:@"17612180205" forKey:@"phone"];
    [parameters setObject:[self encryptAES:@"12345678"] forKey:@"pwd"];
    
    [[MSApiClient shareClient] POST:path parameters:parameters responseCache:nil success:^(id responseObject) {
        NSLog(@"登录成功");
    } failure:^(ApiErrorResponse *error) {
        NSLog(@"登录失败");
    }];
    
}


- (NSString *)encryptAES:(NSString *)string {
    
    NSData *contentData = [string dataUsingEncoding:NSUTF8StringEncoding];
    NSUInteger dataLength = contentData.length;
    
    char keyPtr[MS_AES_KEYSIZE + 1];
    memset(keyPtr, 0, sizeof(keyPtr));
    [MS_AES_KEY getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    
    size_t encryptSize = dataLength + kCCBlockSizeAES128;
    void *encryptedBytes = malloc(encryptSize);
    size_t actualOutSize = 0;
    
    NSData *initVector = [MS_AES_VECTOR dataUsingEncoding:NSUTF8StringEncoding];
    
    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt,
                                          kCCAlgorithmAES,
                                          kCCOptionPKCS7Padding,
                                          keyPtr,
                                          MS_AES_KEYSIZE,
                                          initVector.bytes,
                                          contentData.bytes,
                                          dataLength,
                                          encryptedBytes,
                                          encryptSize,
                                          &actualOutSize);
    
    if (cryptStatus == kCCSuccess) {
        return [[NSData dataWithBytesNoCopy:encryptedBytes length:actualOutSize] base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    }
    free(encryptedBytes);
    return nil;
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
