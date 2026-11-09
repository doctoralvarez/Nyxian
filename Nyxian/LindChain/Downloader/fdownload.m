/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
*/

/*
 Fork doctoralvarez/Nyxian — version 1.0.0
 Changelog:
  - 1.0.0 (2026-11-08): downloads survive a bad connection — up to 6
    attempts with growing pauses, resuming where the last one stopped
    (resume data) instead of starting over, waiting for the network to come
    back, and only an HTTP 2xx answer counts. fdownloadWithError: tells why
    it failed.
*/

#import <LindChain/Downloader/fdownload.h>
#include <unistd.h>

static const int NXForkDownloadAttempts = 6;

BOOL fdownloadWithError(NSString *urlString,
                        NSString *destinationPath,
                        NSError **outError)
{
    NSURL *url = [NSURL URLWithString:urlString];
    if(url == nil)
    {
        if(outError) *outError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadURL userInfo:@{ NSLocalizedDescriptionKey: @"bad URL" }];
        return NO;
    }
    
    NSString *finalDestinationPath = destinationPath;
    if(![finalDestinationPath isAbsolutePath])
    {
        finalDestinationPath = [NSTemporaryDirectory() stringByAppendingPathComponent:destinationPath];
    }
    
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.timeoutIntervalForRequest = 90;          /* no data for 90 s: this attempt failed */
    configuration.timeoutIntervalForResource = 60 * 60;    /* the SDK is large */
    configuration.waitsForConnectivity = YES;              /* offline for a moment: wait instead of failing */
    configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:nil delegateQueue:nil];
    
    __block NSError *lastError = nil;
    NSData *resumeData = nil;
    BOOL didDownload = NO;
    
    for(int attempt = 1; attempt <= NXForkDownloadAttempts && !didDownload; attempt++)
    {
        __block NSData *nextResumeData = nil;
        __block BOOL ok = NO;
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        void (^completion)(NSURL*, NSURLResponse*, NSError*) = ^(NSURL *location, NSURLResponse *response, NSError *error) {
            if(error != nil)
            {
                lastError = error;
                nextResumeData = error.userInfo[NSURLSessionDownloadTaskResumeData];
                dispatch_semaphore_signal(semaphore);
                return;
            }
            NSInteger status = [response isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse*)response).statusCode : 200;
            if(status < 200 || status >= 300)
            {
                lastError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"the server answered HTTP %ld", (long)status] }];
                dispatch_semaphore_signal(semaphore);
                return;
            }
            [[NSFileManager defaultManager] removeItemAtPath:finalDestinationPath error:NULL];
            NSError *moveError = nil;
            ok = [[NSFileManager defaultManager] moveItemAtURL:location toURL:[NSURL fileURLWithPath:finalDestinationPath] error:&moveError];
            if(!ok) lastError = moveError;
            dispatch_semaphore_signal(semaphore);
        };
        
        NSURLSessionDownloadTask *task = resumeData != nil
            ? [session downloadTaskWithResumeData:resumeData completionHandler:completion]
            : [session downloadTaskWithURL:url completionHandler:completion];
        [task resume];
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        
        didDownload = ok;
        resumeData = nextResumeData;
        if(!didDownload && attempt < NXForkDownloadAttempts)
        {
            NSLog(@"[fdownload] %@ attempt %d failed (%@)%@, trying again", url.lastPathComponent, attempt, lastError.localizedDescription, resumeData ? @", resuming" : @"");
            sleep(attempt < 3 ? 3 * attempt : 15);
        }
    }
    [session finishTasksAndInvalidate];
    
    if(!didDownload && outError)
    {
        *outError = lastError ?: [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUnknown userInfo:@{ NSLocalizedDescriptionKey: @"unknown error" }];
    }
    return didDownload;
}

BOOL fdownload(NSString *urlString,
               NSString *destinationPath)
{
    return fdownloadWithError(urlString, destinationPath, NULL);
}
