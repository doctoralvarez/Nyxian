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
 Fork doctoralvarez/Nyxian — version 1.1.0
 Changelog:
  - 1.1.0 (2026-11-08): closeOnExit, fontSize and fontSizeDefaultsKey.
  - 1.0.0 (2026-11-07): optional arguments, extra environment, working
    directory and window title (used to run python3 with PYTHONHOME and a
    script).
*/

#ifndef NXWINDOWSESSIONTERMINAL_H
#define NXWINDOWSESSIONTERMINAL_H

#import <LindChain/WindowServer/Window/NXWindowSession.h>
#import <LindChain/ProcEnvironment/PEProcess.h>

@interface NXWindowSessionTerminal : NXWindowSession <PEProcessObserver>

@property (nonatomic,strong) NSString *utilityPath;

@property (nonatomic,weak) PEProcess *process;

- (instancetype)initWithUtilityPath:(NSString*)utilityPath;

/* fork: argv (default: the utility path alone), environment added to HOME/TMPDIR, working directory (default: HOME), title */
@property (nonatomic,copy) NSArray<NSString*> *arguments;
@property (nonatomic,copy) NSDictionary<NSString*,NSString*> *extraEnvironment;
@property (nonatomic,copy) NSString *workingDirectory;
@property (nonatomic,copy) NSString *title;
/* fork: close the window as soon as the process exits (default: wait for a key) */
@property (nonatomic) BOOL closeOnExit;
/* fork: font size of the terminal (0: Nyxian's default) and the UserDefaults key A−/A+ save it to */
@property (nonatomic) CGFloat fontSize;
@property (nonatomic,copy) NSString *fontSizeDefaultsKey;

@end

#endif /* NXWINDOWSESSIONTERMINAL_H */
