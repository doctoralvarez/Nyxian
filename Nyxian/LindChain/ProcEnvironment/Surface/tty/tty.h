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
  - 1.0.0 (2026-11-09): tty_ldisc_mode_changed().
*/

#ifndef TTY_TTY_H
#define TTY_TTY_H

#import <LindChain/ProcEnvironment/Surface/tty/def.h>
#import <LindChain/ProcEnvironment/Surface/tty/attach.h>
#import <LindChain/ProcEnvironment/Surface/tty/lookup.h>

void tty_kill(ksurface_tty_t *tty, int sig);

/* fork: after TIOCSETA*: a line typed so far is handed over when ICANON goes off; flush drops it */
void tty_ldisc_mode_changed(ksurface_tty_t *tty, const struct termios *old, int flush);

DEFINE_KVOBJECT_MAIN_EVENT_HANDLER(tty);

#endif /* TTY_TTY_H */
