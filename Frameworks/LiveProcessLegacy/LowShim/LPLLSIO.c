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
  - 1.0.0 (2026-11-09): network permission: with NYXIAN_NETWORK=blocked
    (set by Nyxian's kernel at spawn, Management → Permissions) socket()
    and connect() for IPv4/IPv6 fail with EPERM ("Operation not
    permitted"); local sockets (AF_UNIX) keep working.
*/

#include <LiveProcessLegacy/LPLShim.h>
#include <Broadpatch/Broadpatch.h>
#include <sys/ioccom.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

LIBKERN_PATCH(int, access, (const char *path,
                            int mode),
{
    if(mode & X_OK)
    {
        struct stat sb;
        if(stat(path, &sb) == 0)
        {
            if(sb.st_mode & S_IXUSR)
            {
                if(mode == X_OK)
                {
                    return 0;
                }
                return LIBKERN_ORIG(access)(path, mode & ~X_OK);
            }
        }
    }
    return LIBKERN_ORIG(access)(path, mode);
});


LIBKERN_PATCH(int, faccessat, (int dirfd,
                               const char *path,
                               int mode,
                               int flags),
{
    if(mode & X_OK)
    {
        struct stat sb;
        int stat_flags = (flags & AT_SYMLINK_NOFOLLOW) ? AT_SYMLINK_NOFOLLOW : 0;
        if(fstatat(dirfd, path, &sb, stat_flags) == 0)
        {
            if(sb.st_mode & S_IXUSR)
            {
                if(mode == X_OK)
                {
                    return 0;
                }
                return LIBKERN_ORIG(faccessat)(dirfd, path, mode & ~X_OK, flags);
            }
        }
    }
    return LIBKERN_ORIG(faccessat)(dirfd, path, mode, flags);
});

/* fork: decided when the program starts (LPLNetworkPolicyApply); unsetting the variable later changes nothing */
static bool g_network_blocked = false;

static bool lpl_network_family(int domain)
{
    return domain == AF_INET || domain == AF_INET6;
}

LIBKERN_PATCH(int, socket, (int domain,
                            int type,
                            int protocol),
{
    if(g_network_blocked && lpl_network_family(domain))
    {
        errno = EPERM;
        return -1;
    }
    return LIBKERN_ORIG(socket)(domain, type, protocol);
});

LIBKERN_PATCH(int, connect, (int fd,
                             const struct sockaddr *address,
                             socklen_t length),
{
    if(g_network_blocked && address != NULL && length >= (socklen_t)sizeof(sa_family_t) && lpl_network_family(address->sa_family))
    {
        errno = EPERM;
        return -1;
    }
    return LIBKERN_ORIG(connect)(fd, address, length);
});

/* called by LiveProcessMain once the environment Nyxian passed is set, before the program's own code */
void LPLNetworkPolicyApply(void)
{
    static bool applied = false;
    if(applied) return;
    applied = true;
    const char *network = getenv("NYXIAN_NETWORK");
    g_network_blocked = network != NULL && strcmp(network, "blocked") == 0;
    if(g_network_blocked)
    {
        LIBKERN_INSTALL_PATCH(socket);
        LIBKERN_INSTALL_PATCH(connect);
    }
}

__attribute__((constructor))
static void InstallPatches(void)
{
    LIBKERN_INSTALL_PATCH(access);
    LIBKERN_INSTALL_PATCH(faccessat);
}
