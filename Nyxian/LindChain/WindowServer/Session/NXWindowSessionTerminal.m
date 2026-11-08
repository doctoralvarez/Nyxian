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
 Fork doctoralvarez/Nyxian — version 1.2.0
 Changelog:
  - 1.2.0 (2026-11-08): closeOnExit (the window closes when its process
    ends, e.g. Ctrl-D in the Python console), the key bar's ✕ closes the
    window, font size per window; otherwise "[process exited]" now says
    how to close it.
  - 1.1.0 (2026-11-08): the terminal ends above the keyboard (it used to
    run behind it, so what you typed was hidden and nothing scrolled), and
    8-bit input is kept (ISTRIP off: ñ, accents, ¿ ¡ were mangled).
  - 1.0.0 (2026-11-07): optional arguments, extra environment, working
    directory and window title (used to run python3 with PYTHONHOME and a
    script).
*/

#import <LindChain/WindowServer/Session/NXWindowSessionTerminal.h>
#import <LindChain/ProcEnvironment/PEProcessManager.h>
#import <Frameworks/LiveProcessLegacy/LindChain/Services/bootstrapd/LDEApplicationWorkspace.h>
#import <LindChain/ProcEnvironment/Surface/tty/tty.h>
#import <Nyxian-Swift.h>

@interface NXWindowSessionTerminal () <TerminalViewDelegateObjC>

@property (nonatomic,strong) TerminalViewObjC *terminal;
@property (nonatomic) bool focused;
@property (nonatomic) bool atExit;
@property (nonatomic) id_t identifier;
@property (nonatomic) ksurface_tty_t *tty;

@end

@implementation NXWindowSessionTerminal

- (instancetype)initWithUtilityPath:(NSString*)utilityPath
{
    self = [super init];
    _utilityPath = utilityPath;
    return self;
}

- (BOOL)openWindow
{
    if(![super openWindow])
    {
        return NO;
    }
    
    self.focused = NO;
    self.atExit = NO;
    
    /* using NSPipe, because file descriptors are automatically closed */

    
    /*
     * in theory creating it before the process exists,
     * to have pipes to handoff.
     */
    ksurface_tty_t *tty = kvo_alloc_fastpath(tty);
    
    if(tty == NULL)
    {
        return NO;
    }
    
    /* setting tty properties */
    kvo_wrlock(tty);
    tty->t.c_iflag = ICRNL | INPCK /*| IXON | BRKINT*/; /* fork: no ISTRIP, UTF-8 needs the 8th bit */
    tty->t.c_oflag = OPOST | ONLCR;
    /*tty->t.c_cflag = CS8 | CREAD | CLOCAL;*/
    tty->t.c_lflag = /*ICANON | ECHO | ECHOE | ECHOK |*/ ISIG /*| IEXTEN*/;
    tty->t.c_cc[VINTR]  = 0x03;
    tty->t.c_cc[VQUIT]  = 0x1C;
    /*tty->t.c_cc[VERASE] = 0x7F;*/
    tty->t.c_cc[VKILL]  = 0x15;
    /*tty->t.c_cc[VEOF]   = 0x04;*/
    tty->t.c_cc[VSUSP]  = 0x1A;
    /*tty->t.c_cc[VSTART] = 0x11;
    tty->t.c_cc[VSTOP]  = 0x13;
    tty->t.c_cc[VMIN]   = 1;
    tty->t.c_cc[VTIME]  = 0;*/
    kvo_unlock(tty);
    
    kvo_retain(tty);
    _tty = tty;
    
    PEFileTable *fileTable = [PEFileTable emptyTable];
    if(fileTable == nil)
    {
        kvo_release(tty);
        return NO;
    }
    
    [fileTable appendFileDescriptor:tty->userspacefd[SLAVEFD] withMappingToLoc:STDIN_FILENO];
    [fileTable appendFileDescriptor:tty->userspacefd[SLAVEFD] withMappingToLoc:STDOUT_FILENO];
    [fileTable appendFileDescriptor:tty->userspacefd[SLAVEFD] withMappingToLoc:STDERR_FILENO];
    
    NSString *homePath = [[LDEApplicationWorkspace shared] utilityHomePath];
    if(homePath == nil)
    {
        kvo_release(tty);
        return NO;
    }
    
    /* fork: caller-provided argv, environment and working directory */
    NSMutableDictionary *environment = [@{
        @"HOME": homePath,
        @"CFFIXED_USER_HOME": homePath,
        @"TMPDIR": [homePath stringByAppendingPathComponent:@"/Tmp"]
    } mutableCopy];
    if(self.extraEnvironment) [environment addEntriesFromDictionary:self.extraEnvironment];
    
    pid_t pid = [[PEProcessManager shared] spawnProcessWithItems:@{
        @"PEExecutablePath": _utilityPath,
        @"PEArguments": self.arguments.count ? self.arguments : @[self.utilityPath],
        @"PEEnvironment": environment,
        @"PEWorkingDirectory": self.workingDirectory.length ? self.workingDirectory : homePath,
        @"PEFileTable": fileTable
    } withKernelSurfaceProcess:kernel_proc_];
    PEProcess *process = [[PEProcessManager shared] processForProcessIdentifier:pid];
    
    if(process == nil)
    {
        kvo_release(tty);
        return NO;
    }
    
    _process = process;
    
    /* attaching tty to process lifecycle */
    kern_return_t kr = tty_attach_proc(_process.proc, tty);
    if(kr != KERN_SUCCESS)
    {
        [process forceTerminate];
        kvo_release(tty);
        return NO;
    }
    
    /* finally starting terminal */
    _terminal = [[TerminalViewObjC alloc] initWithFrame:self.startWindowRect masterFD:tty->userspacefd[MASTERFD]];
    
    if(_terminal == nil)
    {
        [process forceTerminate];
        kvo_release(tty);
        return NO;
    }
    
    _terminal.objcDelegate = self;
    
    /* fork: font size, ✕ in the key bar */
    if(self.fontSize > 0)
    {
        [_terminal forkApplyFontSize:self.fontSize];
    }
    _terminal.forkFontSizeDefaultsKey = self.fontSizeDefaultsKey;
    __weak typeof(self) weakSelf = self;
    _terminal.forkCloseWindow = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if(strongSelf == nil) return;
        [[NXWindowServer shared] closeWindowWithIdentifier:strongSelf.windowIdentifier withCompletion:nil];
    };
    [_process addObserver:self];
    
    _terminal.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_terminal];
    
    /* fork: the bottom follows the keyboard (TerminalViewObjC sets its constant) */
    NSLayoutConstraint *bottom = [self.terminal.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor];
    [NSLayoutConstraint activateConstraints:@[
        [self.terminal.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.terminal.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.terminal.widthAnchor constraintEqualToAnchor:self.view.widthAnchor],
        bottom,
    ]];
    self.terminal.forkKeyboardConstraint = bottom;
    
    return YES;
}

- (BOOL)closeWindow
{
    [super closeWindow];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL succeeded __attribute__((unused)) = [self.terminal resignFirstResponder];
    });
    self.terminal.ttyHandle = nil;
    [_process forceTerminate];
    
    return YES;
}

- (BOOL)activateWindow
{
    [super activateWindow];
    
    //[_process resume];
    self.focused = YES;
    (void)[_terminal becomeFirstResponder];
    return YES;
}

- (BOOL)deactivateWindow
{
    [super deactivateWindow];
    
    self.focused = NO;
    
    if(self.atExit)
    {
        [[NXWindowServer shared] closeWindowWithIdentifier:self.windowIdentifier withCompletion:nil];
        return YES;
    }
    
    //[_process suspend];
    return YES;
}

- (NSString*)getWindowName
{
    NSString *windowName = [super getWindowName];
    return windowName ?: (self.title.length ? self.title : [self.utilityPath lastPathComponent]);
}

- (void)sendWithSource:(TerminalView * _Nonnull)source data:(NSData * _Nonnull)data
{
    if(self.atExit)
    {
        [[NXWindowServer shared] closeWindowWithIdentifier:self.windowIdentifier withCompletion:nil];
    }
    
    write(self.terminal.ttyHandle.fileDescriptor, data.bytes, data.length);
}

- (void)setTerminalTitleWithSource:(TerminalView * _Nonnull)source title:(NSString * _Nonnull)title
{
    self.windowName = title;
}

- (void)sizeChangedWithSource:(TerminalView * _Nonnull)source newCols:(NSInteger)newCols newRows:(NSInteger)newRows
{
    /* updating window size */
    kvo_wrlock(_tty);
    _tty->ws.ws_col = newCols;
    _tty->ws.ws_row = newRows;
    kvo_unlock(_tty);
    
    /* notifying child process */
    [self.process sendSignal:SIGWINCH];
}

- (void)process:(PEProcess *)process didExitWithWait4Code:(int)code
{
    if(!self)
    {
        return;
    }
    
    if(self.focused && !self.closeOnExit)
    {
        static const char message[] = "\n[process exited — press any key or \xE2\x9C\x95 to close]\n";
        write(_tty->userspacefd[SLAVEFD], message, sizeof(message) - 1);
        
        self.atExit = YES;
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NXWindowServer shared] closeWindowWithIdentifier:self.windowIdentifier withCompletion:nil];
        });
    }
}

- (void)dealloc
{
    if(_tty != NULL)
    {
        kvo_release(_tty);
    }

#if DEBUG
    NSLog(@"deallocated %@", self);
#endif /* DEBUG */
}

@end
