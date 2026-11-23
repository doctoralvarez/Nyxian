/*
 Fork doctoralvarez/Nyxian — version 1.0.0
 Changelog:
  - 1.0.0 (2026-11-22): App Store signing (zsignAppStore, zsignMakeCSR, zsignMakeP12).
*/
#include "zsign.hpp"
#include "common/common.h"
#include "common/json.h"
#include "openssl.h"
#include "macho.h"
#include "bundle.h"
#include <libgen.h>
#include <dirent.h>
#include <getopt.h>
#include <stdlib.h>
#include <openssl/ocsp.h>
#include <openssl/x509.h>
#include <openssl/pem.h>
#include <openssl/bio.h>
#include <openssl/ssl.h>
#include <openssl/err.h>
#include <openssl/asn1.h>
#import <openssl/cms.h>
#include "timer.h"
#include "common/log.h"


NSString* getTmpDir() {
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	return [[[paths objectAtIndex:0] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"tmp"];
}

extern "C" {

NSError* makeErrorFromLog(const std::vector<std::string>& vec) {
    NSMutableString *result = [NSMutableString string];
    
    for (size_t i = 0; i < vec.size(); ++i) {
        // Convert each std::string to NSString
        NSString *str = [NSString stringWithUTF8String:vec[i].c_str()];
        [result appendString:str];
        
        // Append newline if it's not the last element
        if (i != vec.size() - 1) {
            [result appendString:@"\n"];
        }
    }
    
    NSDictionary* userInfo = @{
        NSLocalizedDescriptionKey : result
    };
    return [NSError errorWithDomain:@"Failed to Sign" code:-1 userInfo:userInfo];
}

void zsign(NSString *appPath,
           NSData *prov,
           NSData *key,
           NSString *pass,
           NSProgress* progress,
           void(^completionHandler)(BOOL success, NSError *error))
{
    ZTimer gtimer;
    ZTimer timer;
    timer.Reset();
    
	bool bForce = false;
	bool bWeakInject = false;
	bool bDontGenerateEmbeddedMobileProvision = YES;
	
	string strPassword;

	string strDyLibFile;
	string strOutputFile;

	string strEntitlementsFile;

    const char* strPKeyFileData = (const char*)[key bytes];
    const char* strProvFileData = (const char*)[prov bytes];
	strPassword = [pass cStringUsingEncoding:NSUTF8StringEncoding];
	
	
	string strPath = [appPath cStringUsingEncoding:NSUTF8StringEncoding];
    
    ZLog::logs.clear();

	__block ZSignAsset zSignAsset;
	
    if (!zSignAsset.InitSimple(strPKeyFileData, (int)[key length], strProvFileData, (int)[prov length], strPassword)) {
        completionHandler(NO, makeErrorFromLog(ZLog::logs));
        ZLog::logs.clear();
		return;
	}
    
	bool bEnableCache = false;
	string strFolder = strPath;
	
	__block ZBundle bundle;
	bool success = bundle.ConfigureFolderSign(&zSignAsset, strFolder, "", "", "", strDyLibFile, bForce, bWeakInject, bEnableCache, bDontGenerateEmbeddedMobileProvision);

    if(!success) {
        completionHandler(NO, makeErrorFromLog(ZLog::logs));
        ZLog::logs.clear();
        return;
    }
    
    int filesNeedToSign = bundle.GetSignCount();
    [progress setTotalUnitCount:filesNeedToSign];
    bundle.progressHandler = [&progress] {
        [progress setCompletedUnitCount:progress.completedUnitCount + 1];
    };

    ZLog::PrintV(">>> Files Need to Sign: \t%d\n", filesNeedToSign);
    bool bRet = bundle.StartSign(bEnableCache);
    timer.PrintResult(bRet, ">>> Signed %s!", bRet ? "OK" : "Failed");
    gtimer.Print(">>> Done.");
    NSError* signError = nil;
    if(!bundle.signFailedFiles.empty()) {
        NSDictionary* userInfo = @{
            NSLocalizedDescriptionKey : [NSString stringWithUTF8String:bundle.signFailedFiles.c_str()]
        };
        signError = [NSError errorWithDomain:@"Failed to Sign" code:-1 userInfo:userInfo];
    }
    
    completionHandler(YES, signError);
    ZLog::logs.clear();
    
	return;
}

bool zsignMachO(NSString *machoPath,
                NSData *prov,
                NSData *key,
                NSString *pass)
{
    ZTimer gtimer;
    ZTimer timer;
    timer.Reset();

    string strPassword;
    const char* strPKeyFileData = (const char*)[key bytes];
    const char* strProvFileData = (const char*)[prov bytes];
    strPassword = [pass cStringUsingEncoding:NSUTF8StringEncoding];

    ZLog::logs.clear();
    
    __block ZSignAsset zSignAsset;
    
    if (!zSignAsset.InitSimple(strPKeyFileData, (int)[key length], strProvFileData, (int)[prov length], strPassword)) {
        ZLog::logs.clear();
        return NO;
    }

    __block ZMachO* macho = new ZMachO();
    if (!macho->Init(machoPath.UTF8String)) {
        delete macho;
        ZLog::logs.clear();
        return NO;
    }
    
    string strInfoSHA1;
    string strInfoSHA256;
    string strCodeResourcesData;
    bool bRet = macho->Sign(&zSignAsset, true,
                            [[[NSBundle mainBundle] bundleIdentifier] UTF8String],
                            strInfoSHA1, strInfoSHA256, strCodeResourcesData);

    delete macho;

    timer.PrintResult(bRet, ">>> Mach-O Signed %s!", bRet ? "OK" : "Failed");
    gtimer.Print(">>> Done.");

    NSError* signError = nil;
    if (!bRet) {
        NSDictionary* userInfo = @{
            NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Failed to sign Mach-O at path: %@", machoPath]
        };
        signError = [NSError errorWithDomain:@"MachOSignError" code:-1 userInfo:userInfo];
    }

    ZLog::logs.clear();
    return bRet;
}

bool adhocSignMachO(NSString *machoPath, NSString *bundleId, NSData* entitlementData) {
    ZSignAsset zSignAsset;
    zSignAsset.InitAdhoc([entitlementData bytes], (int)[entitlementData length]);
    
    ZMachO* macho = new ZMachO();
    if (!macho->Init(machoPath.UTF8String)) {
        ZLog::ErrorV(">>> Invalid mach-o file! %s\n", machoPath.UTF8String);
        return false;
    }

    string strInfoSHA1;
    string strInfoSHA256;
    string strCodeResourcesData;
    string strBundleId(bundleId.UTF8String);
    bool bRet = macho->Sign(&zSignAsset, true, strBundleId, strInfoSHA1, strInfoSHA256, strCodeResourcesData);
    return bRet;
}

NSString* getTeamId(NSData *prov,
                    NSData *key,
                    NSString *pass) {
    string strPassword;

    const char* strPKeyFileData = (const char*)[key bytes];
    const char* strProvFileData = (const char*)[prov bytes];
    strPassword = [pass cStringUsingEncoding:NSUTF8StringEncoding];
    
    ZLog::logs.clear();

    __block ZSignAsset zSignAsset;
    
    if (!zSignAsset.InitSimple(strPKeyFileData, (int)[key length], strProvFileData, (int)[prov length], strPassword)) {
        ZLog::logs.clear();
        return nil;
    }
    NSString* teamId = [NSString stringWithUTF8String:zSignAsset.m_strTeamId.c_str()];
    return teamId;
}

static NSDictionary *DecodeProvisioningProfile(NSData *prov,
                                               NSString **errorOut)
{
    if(!prov || prov.length == 0)
    {
        if(errorOut)
        {
            *errorOut = @"Provisioning profile is empty.";
        }
        return nil;
    }
    
    const unsigned char *bytes = (const unsigned char *)prov.bytes;
    CMS_ContentInfo *cms = d2i_CMS_ContentInfo(NULL, &bytes, (long)prov.length);
    if(!cms)
    {
        if(errorOut)
        {
            *errorOut = @"Unable to decode provisioning profile CMS.";
        }
        return nil;
    }
    
    BIO *output = BIO_new(BIO_s_mem());
    if(!output)
    {
        CMS_ContentInfo_free(cms);
        if(errorOut)
        {
            *errorOut = @"Unable to allocate provisioning profile buffer.";
        }
        return nil;
    }
    
    unsigned int flags = CMS_BINARY | CMS_NO_SIGNER_CERT_VERIFY | CMS_NO_ATTR_VERIFY | CMS_NO_CONTENT_VERIFY;
    int result = CMS_verify(cms, NULL, NULL, NULL, output, flags);
    if(result != 1)
    {
        BIO_free(output);
        CMS_ContentInfo_free(cms);
        if(errorOut)
        {
            *errorOut = @"Unable to extract provisioning profile payload.";
        }
        return nil;
    }
    
    BUF_MEM *buffer = NULL;
    BIO_get_mem_ptr(output, &buffer);
    if(!buffer || !buffer->data || buffer->length == 0)
    {
        BIO_free(output);
        CMS_ContentInfo_free(cms);
        if(errorOut)
        {
            *errorOut = @"Provisioning profile contains no payload.";
        }
        return nil;
    }
    
    NSData *plistData = [NSData dataWithBytes:buffer->data length:buffer->length];
    NSError *plistError = nil;
    
    id plist = [NSPropertyListSerialization propertyListWithData:plistData options:NSPropertyListImmutable format:NULL error:&plistError];
    
    BIO_free(output);
    CMS_ContentInfo_free(cms);
    
    if(![plist isKindOfClass:[NSDictionary class]])
    {
        if(errorOut)
        {
            *errorOut = plistError.localizedDescription ?: @"Invalid provisioning profile property list.";
        }
        return nil;
    }
    
    return (NSDictionary *)plist;
}

static BOOL ProvisionContainsCertificate(NSData *prov,
                                         X509 *certificate,
                                         NSString **errorOut)
{
    if(!certificate)
    {
        if(errorOut)
        {
            *errorOut = @"Certificate is missing.";
        }
        return NO;
    }
    
    NSDictionary *profile = DecodeProvisioningProfile(prov, errorOut);
    
    if(!profile)
    {
        return NO;
    }
    
    NSArray *developerCertificates = profile[@"DeveloperCertificates"];
    
    if(![developerCertificates isKindOfClass:[NSArray class]])
    {
        if(errorOut)
        {
            *errorOut = @"Provisioning profile does not contain DeveloperCertificates.";
        }
        
        return NO;
    }
    
    int derLength = i2d_X509(certificate, NULL);
    
    if(derLength <= 0)
    {
        if(errorOut)
        {
            *errorOut = @"Unable to encode certificate.";
        }
        return NO;
    }
    
    NSMutableData *certificateData = [NSMutableData dataWithLength:derLength];
    
    unsigned char *der = (unsigned char *)certificateData.mutableBytes;
    
    int written = i2d_X509(certificate, &der);
    if(written != derLength)
    {
        if(errorOut)
        {
            *errorOut = @"Unable to encode certificate.";
        }
        return NO;
    }
    
    for(id item in developerCertificates)
    {
        if(![item isKindOfClass:[NSData class]])
        {
            continue;
        }
        NSData *profileCertificate = (NSData *)item;
        if([profileCertificate isEqualToData:certificateData])
        {
            return YES;
        }
    }
    
    if(errorOut)
    {
        *errorOut = @"The provisioning profile Nyxian was signed with does not include this certificate, make sure you use the same certificate Nyxian was signed with.";
    }
    
    return NO;
}

int checkCert(NSData *prov,
              NSData *key,
              NSString *pass,
              void(^completionHandler)(int status, NSString *error)) {
    const char* strPKeyFileData = (const char*)[key bytes];
    const char* strProvFileData = (const char*)[prov bytes];
    
    if(pass == nil)
    {
        pass = @"";
    }
    
    string strPassword = [pass cStringUsingEncoding:NSUTF8StringEncoding];
    
    ZLog::logs.clear();

    __block ZSignAsset zSignAsset;
    
    if (!zSignAsset.InitSimple(strPKeyFileData, (int)[key length], strProvFileData, (int)[prov length], strPassword)) {
        ZLog::logs.clear();
        completionHandler(2, @"Unable to initialize certificate. Please check your password.");
        return -1;
    }
    
    X509* cert = (X509*)zSignAsset.m_x509Cert;
    BIO *brother1;
    unsigned long issuerHash = X509_issuer_name_hash((X509*)cert);
    if (0x9b16b75c == issuerHash) {
        brother1 = BIO_new_mem_buf(ZSignAsset::s_szAppleDevCACertG3, (int)strlen(ZSignAsset::s_szAppleDevCACertG3));
    } else {
        completionHandler(2, @"Unable to determine issuer of the certificate. It is signed by Apple Developer?");
        return -2;
    }
    
    if (!brother1)
    {
        completionHandler(2, @"Unable to initialize issuer certificate.");
        return -3;
    }
    
    X509 *issuer = PEM_read_bio_X509(brother1, NULL, 0, NULL);
    
    if (!cert || !issuer) {
        completionHandler(2, @"Error loading cert or issuer");
        return -4;
    }

    
    // Extract OCSP URL from cert
    STACK_OF(ACCESS_DESCRIPTION)* aia = (STACK_OF(ACCESS_DESCRIPTION)*)X509_get_ext_d2i((X509*)cert, NID_info_access, 0, 0);
    if (!aia) {
        completionHandler(2, @"No AIA (OCSP) extension found in certificate");
        return -5;
    }
    
    ASN1_IA5STRING* uri = nullptr;
    for (int i = 0; i < sk_ACCESS_DESCRIPTION_num(aia); i++) {
        ACCESS_DESCRIPTION* ad = sk_ACCESS_DESCRIPTION_value(aia, i);
        if (OBJ_obj2nid(ad->method) == NID_ad_OCSP &&
            ad->location->type == GEN_URI) {
            uri = ad->location->d.uniformResourceIdentifier;
            
            break;
        }
    }

    
    if (!uri) {
        completionHandler(2, @"No OCSP URI found in certificate.");
        return -6;
    }

    OCSP_REQUEST* req = OCSP_REQUEST_new();
    OCSP_CERTID* cert_id = OCSP_cert_to_id(nullptr, (X509*)cert, issuer);
    OCSP_request_add0_id(req, cert_id);  // Ownership transferred to request
    cert_id = OCSP_cert_to_id(nullptr, (X509*)cert, issuer);
    unsigned char* der = 0;
    
    OPENSSL_free(der);
    if (aia) {
        sk_ACCESS_DESCRIPTION_pop_free(aia, ACCESS_DESCRIPTION_free);
    }
    OCSP_REQUEST_free(req);
    X509_free(issuer);
    BIO_free(brother1);
    
    NSString *profileError = nil;
    if(!ProvisionContainsCertificate(prov, cert, &profileError))
    {
        completionHandler(777, profileError ?: @"Certificate does not match provisioning profile.");
    }
    else
    {
        completionHandler(0, nil);
    }
    
    return 1;
}

}

// MARK: - fork doctoralvarez/Nyxian: App Store signing

#include <openssl/evp.h>
#include <openssl/pkcs12.h>
#include <openssl/rsa.h>

void zsignAppStore(NSString *appPath,
                   NSDictionary<NSString *, NSData *> *profiles,
                   NSData *key,
                   NSString *pass,
                   NSProgress *progress,
                   void(^completionHandler)(BOOL success, NSError *error))
{
    ZLog::logs.clear();
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[appPath stringByAppendingPathComponent:@"Info.plist"]];
    NSString *mainID = info[@"CFBundleIdentifier"];
    NSData *mainProfile = mainID ? profiles[mainID] : nil;
    if (mainProfile == nil) {
        completionHandler(NO, [NSError errorWithDomain:@"Failed to Sign" code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"No App Store profile for %@", mainID ?: @"the app"]}]);
        return;
    }
    string strPassword = [pass cStringUsingEncoding:NSUTF8StringEncoding] ?: "";

    ZSignAsset mainAsset;
    if (!mainAsset.InitSimple([key bytes], (int)[key length], [mainProfile bytes], (int)[mainProfile length], strPassword)) {
        completionHandler(NO, makeErrorFromLog(ZLog::logs));
        ZLog::logs.clear();
        return;
    }

    std::vector<ZSignAsset *> owned;
    std::map<string, ZSignAsset *> assets;
    assets[[mainID UTF8String]] = &mainAsset;
    for (NSString *bundleID in profiles) {
        if ([bundleID isEqualToString:mainID]) continue;
        NSData *prov = profiles[bundleID];
        ZSignAsset *asset = new ZSignAsset();
        owned.push_back(asset);
        if (!asset->InitSimple([key bytes], (int)[key length], [prov bytes], (int)[prov length], strPassword)) {
            for (ZSignAsset *a : owned) delete a;
            completionHandler(NO, makeErrorFromLog(ZLog::logs));
            ZLog::logs.clear();
            return;
        }
        assets[[bundleID UTF8String]] = asset;
    }

    ZBundle bundle;
    bundle.m_bAppStore = true;
    bundle.m_mapAssets = assets;
    string strDyLibFile;
    bool configured = bundle.ConfigureFolderSign(&mainAsset, [appPath UTF8String], "", "", "", strDyLibFile, true, false, false, false);
    if (!configured) {
        for (ZSignAsset *a : owned) delete a;
        completionHandler(NO, makeErrorFromLog(ZLog::logs));
        ZLog::logs.clear();
        return;
    }
    [progress setTotalUnitCount:bundle.GetSignCount()];
    bundle.progressHandler = [&progress] {
        [progress setCompletedUnitCount:progress.completedUnitCount + 1];
    };
    bool ok = bundle.StartSign(false);
    for (ZSignAsset *a : owned) delete a;
    if (!ok || !bundle.signFailedFiles.empty()) {
        NSString *failed = [NSString stringWithUTF8String:bundle.signFailedFiles.c_str()];
        NSError *error = ok ? [NSError errorWithDomain:@"Failed to Sign" code:-1 userInfo:@{NSLocalizedDescriptionKey: [@"Not signed:\n" stringByAppendingString:failed]}]
                            : makeErrorFromLog(ZLog::logs);
        completionHandler(NO, error);
    } else {
        completionHandler(YES, nil);
    }
    ZLog::logs.clear();
}

static NSData *zsignBIOData(BIO *bio)
{
    char *bytes = NULL;
    long length = BIO_get_mem_data(bio, &bytes);
    return (length > 0 && bytes != NULL) ? [NSData dataWithBytes:bytes length:(NSUInteger)length] : nil;
}

NSDictionary *zsignMakeCSR(NSString *commonName)
{
    EVP_PKEY *pkey = NULL;
    EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new_id(EVP_PKEY_RSA, NULL);
    if (ctx == NULL) return nil;
    if (EVP_PKEY_keygen_init(ctx) <= 0 || EVP_PKEY_CTX_set_rsa_keygen_bits(ctx, 2048) <= 0 || EVP_PKEY_keygen(ctx, &pkey) <= 0) {
        EVP_PKEY_CTX_free(ctx);
        return nil;
    }
    EVP_PKEY_CTX_free(ctx);

    X509_REQ *req = X509_REQ_new();
    X509_REQ_set_version(req, 0);
    X509_NAME *name = X509_REQ_get_subject_name(req);
    const char *cn = [commonName UTF8String] ?: "Apple Distribution";
    X509_NAME_add_entry_by_txt(name, "CN", MBSTRING_UTF8, (const unsigned char *)cn, -1, -1, 0);
    X509_REQ_set_pubkey(req, pkey);
    if (X509_REQ_sign(req, pkey, EVP_sha256()) <= 0) {
        X509_REQ_free(req);
        EVP_PKEY_free(pkey);
        return nil;
    }

    BIO *csrBio = BIO_new(BIO_s_mem());
    i2d_X509_REQ_bio(csrBio, req);
    NSData *csrDER = zsignBIOData(csrBio);
    BIO_free(csrBio);

    BIO *keyBio = BIO_new(BIO_s_mem());
    PEM_write_bio_PrivateKey(keyBio, pkey, NULL, NULL, 0, NULL, NULL);
    NSData *keyPEM = zsignBIOData(keyBio);
    BIO_free(keyBio);

    X509_REQ_free(req);
    EVP_PKEY_free(pkey);
    if (csrDER == nil || keyPEM == nil) return nil;
    return @{@"csr": [csrDER base64EncodedStringWithOptions:0], @"key": keyPEM};
}

NSData *zsignMakeP12(NSData *certificateDER, NSData *privateKeyPEM, NSString *password, NSString *name)
{
    const unsigned char *certBytes = (const unsigned char *)[certificateDER bytes];
    X509 *cert = d2i_X509(NULL, &certBytes, (long)[certificateDER length]);
    if (cert == NULL) return nil;
    BIO *keyBio = BIO_new_mem_buf([privateKeyPEM bytes], (int)[privateKeyPEM length]);
    EVP_PKEY *pkey = PEM_read_bio_PrivateKey(keyBio, NULL, NULL, NULL);
    BIO_free(keyBio);
    if (pkey == NULL) {
        X509_free(cert);
        return nil;
    }
    PKCS12 *p12 = PKCS12_create([password UTF8String] ?: "", [name UTF8String] ?: "Apple Distribution", pkey, cert, NULL,
                                NID_pbe_WithSHA1And3_Key_TripleDES_CBC, NID_pbe_WithSHA1And3_Key_TripleDES_CBC,
                                PKCS12_DEFAULT_ITER, 1, 0);
    NSData *result = nil;
    if (p12 != NULL) {
        BIO *out = BIO_new(BIO_s_mem());
        i2d_PKCS12_bio(out, p12);
        result = zsignBIOData(out);
        BIO_free(out);
        PKCS12_free(p12);
    }
    EVP_PKEY_free(pkey);
    X509_free(cert);
    return result;
}
