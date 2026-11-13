/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab
 Copyright (C) 2026 semvis123

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
 Fork doctoralvarez/Nyxian — version 1.2.0
 Changelog:
  - 1.2.0 (2026-11-13): NXForkPermissionICloudSimulated.
  - 1.1.0 (2026-11-12): NXForkPermissionStoreKitSimulated.
  - 1.0.0 (2026-11-09): per-program permissions (NXForkPermission…).
*/

#ifndef TRUST_TRUST_H
#define TRUST_TRUST_H

/* ----------------------------------------------------------------------
 *  System Headers
 * -------------------------------------------------------------------- */
#include <CoreFoundation/CoreFoundation.h>
#include <sys/param.h>

/* ----------------------------------------------------------------------
 *  Project Headers
 * -------------------------------------------------------------------- */
#include <LindChain/ProcEnvironment/Surface/trust/apple.h>
#include <LindChain/ProcEnvironment/Surface/trust/cdhash.h>
#include <LindChain/ProcEnvironment/Surface/trust/entitlement.h>
#include <LindChain/ProcEnvironment/Surface/trust/signing.h>
#include <LindChain/ProcEnvironment/Surface/trust/presets.h>
#include <LindChain/ProcEnvironment/Surface/trust/keychain.h>
#if __OBJC__
#import <LindChain/ProcEnvironment/Surface/trust/summary.h>
#endif /* __OBJC__ */

/* ----------------------------------------------------------------------
 *  Types
 * -------------------------------------------------------------------- */
typedef enum: UInt8 {
    kPETrustLevelFallback = 0,  /* no trust */
    kPETrustLevelSignature = 1, /* signature trust */
    kPETrustLevelTrusted = 2,   /* system trust */
} PETrustLevel;

typedef CF_ENUM(UInt32, PEEnforcementMode) {
    kPEEnforcementModeEnforcing = 0,
    kPEEnforcementModePermissive = 1,
    kPEEnforcementModeDisabled = 2,
};

typedef struct {
    char path[MAXPATHLEN];
    char cdhash[USER_FSIGNATURES_CDHASH_LEN];
    CFDictionaryRef entitlements;
    CFArrayRef filePermissions;
    PETrustLevel trustLevel;
} ksurface_trust_identity_t;

/* ----------------------------------------------------------------------
 *  Function Prototype
 * -------------------------------------------------------------------- */
bool trust_enforcement_set_mode(PEEnforcementMode mode);
PEEnforcementMode trust_enforcement_mode(void);
bool trust_enforcement_should_deny(pid_t pid, PEEntitlementFlags missing, const char *operation);
bool trust_enforcement_overrides(pid_t pid, PEEntitlementFlags missing, const char *operation);

ksurface_trust_identity_t *trust_identity_get_kernel(void);

/* they are immutable, except for maxLegacyEntitlements! */
ksurface_trust_identity_t *trust_identity_create_from_path(const char *path);
ksurface_trust_identity_t *trust_identity_create_from_path_with_parent_identity(const char *path, ksurface_trust_identity_t *parentIdentity);

void trust_identity_destroy(ksurface_trust_identity_t *identity);

PEEntitlementFlags trust_identity_entitlement_flags_from_entitlements(CFDictionaryRef entitlements);

/* fork: per-program permissions (Management → Permissions), stored in NSUserDefaults under
   fork.permissions.v1: @{ key: @{ @"name", @"files": default|declared|full, @"read": @[paths],
   @"readWrite": @[paths], @"network": @(BOOL) } }, key "bundle:<id>" or "path:<executable>" */
bool NXForkPermissionNetworkBlocked(const char *executablePath);
/* fork: StoreKit simulation for apps run inside Nyxian (@"storekit": @(BOOL), default YES): the program
   starts with NYXIAN_STOREKIT=simulate, so an app can use its own simulated store instead of the App Store */
bool NXForkPermissionStoreKitSimulated(const char *executablePath);
/* fork: iCloud simulation (@"icloud": @(BOOL), default YES): the program starts with NYXIAN_ICLOUD=simulate,
   so an app can back up to a local folder instead of iCloud (Nyxian has no iCloud entitlement of its own) */
bool NXForkPermissionICloudSimulated(const char *executablePath);
#if __OBJC__
extern NSString *const NXForkPermissionsDefaultsKey;
NSString *NXForkPermissionKeyForExecutable(NSString *executablePath);
NSDictionary *NXForkPermissionPolicyForExecutable(NSString *executablePath);
#endif /* __OBJC__ */

#endif /* TRUST_TRUST_H */
