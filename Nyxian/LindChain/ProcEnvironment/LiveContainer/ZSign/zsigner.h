/*
 Fork doctoralvarez/Nyxian — version 1.0.0
 Changelog:
  - 1.0.0 (2026-11-22): App Store signing (signAppStoreWithAppPath, makeCSRWithCommonName, makeP12WithCertificate).
*/
//
//  zsigner.h
//  LiveContainer
//
//  Created by s s on 2024/11/10.
//
#import <Foundation/Foundation.h>

#if defined(BOOT)
#define ZSigner NXBootZSigner
#endif
@interface ZSigner : NSObject
+ (NSProgress*)signWithAppPath:(NSString *)appPath prov:(NSData *)prov key:(NSData *)key pass:(NSString *)pass completionHandler:(void (^)(BOOL success, NSError *error))completionHandler;
+ (BOOL)adhocSignMachOAtPath:(NSString *)path bundleId:(NSString*)bundleId entitlementData:(NSData *)entitlementData;
+ (BOOL)signMachOAtPath:(NSString *)path prov:(NSData *)prov key:(NSData *)key pass:(NSString *)pass;
// this method is used to get teamId for ADP/Enterprise certs ,don't use it in normal jitless
+ (NSString*)getTeamIdWithProv:(NSData *)prov key:(NSData *)key pass:(NSString *)pass;
+ (int)checkCertWithProv:(NSData *)prov key:(NSData *)key pass:(NSString *)pass completionHandler:(void(^)(int status, NSString *error))completionHandler;
// fork doctoralvarez/Nyxian: App Store signing, one profile per bundle ID (app and each extension)
+ (NSProgress*)signAppStoreWithAppPath:(NSString *)appPath profiles:(NSDictionary<NSString *, NSData *> *)profiles key:(NSData *)key pass:(NSString *)pass completionHandler:(void (^)(BOOL success, NSError *error))completionHandler;
// fork: @{@"csr": base64 DER, @"key": PEM NSData} for a new RSA 2048 key, or nil
+ (NSDictionary *)makeCSRWithCommonName:(NSString *)commonName;
// fork: a .p12 from the certificate Apple returns (DER) and the PEM key
+ (NSData *)makeP12WithCertificate:(NSData *)certificateDER privateKey:(NSData *)privateKeyPEM password:(NSString *)password name:(NSString *)name;
@end
