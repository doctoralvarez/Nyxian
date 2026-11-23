/*
 Fork doctoralvarez/Nyxian — version 1.0.0
 Changelog:
  - 1.0.0 (2026-11-22): App Store signing (declarations of zsignAppStore, zsignMakeCSR, zsignMakeP12).
*/
//
//  zsign.hpp
//  feather
//
//  Created by HAHALOSAH on 5/22/24.
//

#ifndef zsign_hpp
#define zsign_hpp

#include <stdio.h>
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

bool InjectDyLib(NSString *filePath,
				 NSString *dylibPath,
				 bool weakInject,
				 bool bCreate);

bool ChangeDylibPath(NSString *filePath,
					 NSString *oldPath,
					 NSString *newPath);

bool ListDylibs(NSString *filePath, NSMutableArray *dylibPathsArray);
bool UninstallDylibs(NSString *filePath, NSArray<NSString *> *dylibPathsArray);

void zsign(NSString *appPath,
          NSData *prov,
          NSData *key,
          NSString *pass,
          NSProgress* progress,
          void(^completionHandler)(BOOL success, NSError *error)
          );

bool adhocSignMachO(NSString *machoPath, NSString *bundleId, NSData* entitlementData);

bool zsignMachO(NSString *machoPath,
                NSData *prov,
                NSData *key,
                NSString *pass);

NSString* getTeamId(NSData *prov,
                    NSData *key,
                    NSString *pass);
int checkCert(NSData *prov,
              NSData *key,
              NSString *pass,
              void(^completionHandler)(int status, NSString *error));

/* fork doctoralvarez/Nyxian: App Store signing. `profiles` maps each bundle ID
   (the app and every .appex) to its App Store provisioning profile. */
void zsignAppStore(NSString *appPath,
                   NSDictionary<NSString *, NSData *> *profiles,
                   NSData *key,
                   NSString *pass,
                   NSProgress *progress,
                   void(^completionHandler)(BOOL success, NSError *error));

/* fork: a new RSA 2048 key and its certificate signing request:
   @{@"csr": base64 DER (no PEM header), @"key": PEM private key (NSData)} or nil */
NSDictionary *zsignMakeCSR(NSString *commonName);

/* fork: a .p12 (3DES, SHA1 MAC) from a DER certificate and a PEM private key */
NSData *zsignMakeP12(NSData *certificateDER, NSData *privateKeyPEM, NSString *password, NSString *name);
#ifdef __cplusplus
}
#endif

#endif /* zsign_hpp */
