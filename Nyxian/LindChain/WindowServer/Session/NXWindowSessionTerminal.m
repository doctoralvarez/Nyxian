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
 Fork doctoralvarez/Nyxian — version 1.6.0
 Changelog:
  - 1.6.0 (2026-11-09): job control: ^Z stops the program ("[1]+ Stopped")
    and the window takes commands — fg (continue here), bg (continue in the
    background), jobs, kill [-9], help; ^Z stops a job in the background
    again. A program stopped or continued elsewhere (Processes) is noticed.
  - 1.5.0 (2026-11-09): the terminal starts in canonical mode with echo
    (ICANON, ECHO, ECHOE, ECHOKE, ECHOCTL, IEXTEN, IUTF8): what a program
    reads with scanf/fgets/readLine() is shown and can be edited (⌫, ^W, ^U),
    ^D on an empty line ends its input. Raw programs switch it off.
  - 1.4.0 (2026-11-08): forkIsRunning, forkSendText: (text typed into the
    program, for Python cells) and forkBringToFront.
  - 1.3.0 (2026-11-08): exitHandler: its text is shown when the process ends.
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
#import <LindChain/ProcEnvironment/Surface/proc/lookup.h>
#import <Nyxian-Swift.h>

/* fork: job control states of the window's program */
typedef NS_ENUM(NSInteger, NXForkJobState) {
    NXForkJobForeground = 0,    /* keys go to the program */
    NXForkJobStopped = 1,       /* ^Z: keys go to the job prompt */
    NXForkJobBackground = 2,    /* bg: runs, keys go to the job prompt */
};

@interface NXWindowSessionTerminal () <TerminalViewDelegateObjC>

@property (nonatomic,strong) TerminalViewObjC *terminal;
@property (nonatomic) bool focused;
@property (nonatomic) bool atExit;
@property (nonatomic) id_t identifier;
@property (nonatomic) ksurface_tty_t *tty;

/* fork: job control */
@property (nonatomic) NXForkJobState forkJobState;
@property (nonatomic,strong) dispatch_source_t forkJobTimer;
@property (nonatomic,strong) NSMutableData *forkJobLine;
@property (nonatomic) int forkJobEscape;

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
    tty->t.c_iflag = ICRNL | INPCK | IUTF8 /*| IXON | BRKINT*/; /* fork: no ISTRIP, UTF-8 needs the 8th bit */
    tty->t.c_oflag = OPOST | ONLCR;
    /*tty->t.c_cflag = CS8 | CREAD | CLOCAL;*/
    /* fork: a real line discipline (see tty.c), like a terminal on macOS or Linux */
    tty->t.c_lflag = ICANON | ECHO | ECHOE | ECHOK | ECHOKE | ECHOCTL | ISIG | IEXTEN;
    for(int i = 0; i < NCCS; i++) tty->t.c_cc[i] = _POSIX_VDISABLE;
    tty->t.c_cc[VINTR]    = 0x03;
    tty->t.c_cc[VQUIT]    = 0x1C;
    tty->t.c_cc[VERASE]   = 0x7F;
    tty->t.c_cc[VKILL]    = 0x15;
    tty->t.c_cc[VEOF]     = 0x04;
    tty->t.c_cc[VSUSP]    = 0x1A;
    tty->t.c_cc[VWERASE]  = 0x17;
    tty->t.c_cc[VREPRINT] = 0x12;
    tty->t.c_cc[VLNEXT]   = 0x16;
    /*tty->t.c_cc[VSTART] = 0x11;
    tty->t.c_cc[VSTOP]  = 0x13;*/
    tty->t.c_cc[VMIN]   = 1;
    tty->t.c_cc[VTIME]  = 0;
    tty->fork_llen = 0;
    tty->fork_lnext = 0;
    tty->fork_eof = 0;
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
    [self forkStartJobControl];
    
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
    
    /* fork: while the job is stopped or in the background, keys are commands */
    if(self.forkJobState != NXForkJobForeground && !self.atExit)
    {
        [self forkJobInput:data];
        return;
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
    
    /* fork: no job left to control */
    dispatch_async(dispatch_get_main_queue(), ^{
        [self forkStopJobControl];
        self.forkJobState = NXForkJobForeground;
    });
    
    /* fork: e.g. a Python run copies the files the script made into its project */
    if(self.exitHandler != nil)
    {
        NSString *note = self.exitHandler(code);
        if(note.length && !self.closeOnExit)
        {
            NSString *text = [NSString stringWithFormat:@"\n%@", note];
            const char *bytes = text.UTF8String;
            write(_tty->userspacefd[SLAVEFD], bytes, strlen(bytes));
        }
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

/* MARK: fork */

- (BOOL)forkIsRunning
{
    return self.process != nil && !self.atExit && _tty != NULL;
}

- (BOOL)forkSendText:(NSString*)text
{
    if(!self.forkIsRunning) return NO;
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    const char *bytes = data.bytes;
    size_t left = data.length;
    while(left > 0)
    {
        ssize_t written = write(_tty->userspacefd[MASTERFD], bytes, left);
        if(written <= 0) return NO;
        bytes += written;
        left -= (size_t)written;
    }
    return YES;
}

/* MARK: fork — job control */

- (NSString*)forkJobName
{
    NSString *name = self.title.length ? self.title : self.utilityPath.lastPathComponent;
    return name.length ? name : @"job";
}

/* text for the screen, through the tty's output (LF becomes CR LF) */
- (void)forkJobPrint:(NSString*)text
{
    if(_tty == NULL) return;
    const char *bytes = text.UTF8String;
    size_t left = strlen(bytes);
    while(left > 0)
    {
        ssize_t written = write(_tty->userspacefd[SLAVEFD], bytes, left);
        if(written <= 0) return;
        bytes += written;
        left -= (size_t)written;
    }
}

- (void)forkJobPrompt
{
    [self forkJobPrint:@"\033[1mjob>\033[0m "];
}

- (void)forkStartJobControl
{
    if(self.forkJobTimer != nil) return;
    self.forkJobState = NXForkJobForeground;
    self.forkJobLine = [NSMutableData data];
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 250 * NSEC_PER_MSEC), 250 * NSEC_PER_MSEC, 50 * NSEC_PER_MSEC);
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(timer, ^{
        [weakSelf forkJobTick];
    });
    self.forkJobTimer = timer;
    dispatch_resume(timer);
}

- (void)forkStopJobControl
{
    if(self.forkJobTimer != nil)
    {
        dispatch_source_cancel(self.forkJobTimer);
        self.forkJobTimer = nil;
    }
}

/* the kernel's view of the program: stopped (SSTOP) or not; -1 when it is gone */
- (int)forkJobIsStopped
{
    PEProcess *process = self.process;
    if(process == nil || self.atExit) return -1;
    ksurface_proc_t *proc = NULL;
    if(proc_for_pid(process.pid, &proc) != KERN_SUCCESS || proc == NULL) return -1;
    kvo_rdlock(proc);
    char stat = proc->bsd.kp_proc.p_stat;
    kvo_unlock(proc);
    kvo_release(proc);
    if(stat == SZOMB) return -1;
    return stat == SSTOP ? 1 : 0;
}

- (void)forkJobTick
{
    int stopped = [self forkJobIsStopped];
    if(stopped < 0) return;
    if(stopped == 1 && self.forkJobState != NXForkJobStopped)
    {
        self.forkJobState = NXForkJobStopped;
        [self.forkJobLine setLength:0];
        [self forkJobPrint:[NSString stringWithFormat:@"\n\033[33m[1]+  Stopped\033[0m                 %@\n"
                            "fg: continue here · bg: in the background · kill: end it · help\n", [self forkJobName]]];
        [self forkJobPrompt];
    }
    else if(stopped == 0 && self.forkJobState == NXForkJobStopped)
    {
        /* continued from somewhere else (Processes) */
        self.forkJobState = NXForkJobForeground;
        [self forkJobPrint:[NSString stringWithFormat:@"\n[1]+  %@ (continued)\n", [self forkJobName]]];
    }
}

- (void)forkJobInput:(NSData*)data
{
    const unsigned char *bytes = data.bytes;
    for(NSUInteger i = 0; i < data.length; i++)
    {
        unsigned char c = bytes[i];
        /* arrows, bracketed paste marks… are not commands */
        if(self.forkJobEscape == 1)
        {
            self.forkJobEscape = (c == '[' || c == 'O') ? 2 : 0;
            continue;
        }
        if(self.forkJobEscape == 2)
        {
            if(c >= 0x40 && c <= 0x7e) self.forkJobEscape = 0;
            continue;
        }
        if(c == 0x1b)
        {
            self.forkJobEscape = 1;
            continue;
        }
        if(c == '\r' || c == '\n')
        {
            [self forkJobPrint:@"\n"];
            NSString *line = [[NSString alloc] initWithData:self.forkJobLine encoding:NSUTF8StringEncoding] ?: @"";
            [self.forkJobLine setLength:0];
            [self forkJobRun:[line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]];
            if(self.forkJobState == NXForkJobForeground)
            {
                /* the rest goes to the program again */
                if(i + 1 < data.length && c == '\r' && bytes[i + 1] == '\n') i++;
                if(i + 1 < data.length)
                {
                    write(self.terminal.ttyHandle.fileDescriptor, bytes + i + 1, data.length - i - 1);
                }
                return;
            }
            continue;
        }
        if(c == 0x7f || c == 0x08)
        {
            NSString *line = [[NSString alloc] initWithData:self.forkJobLine encoding:NSUTF8StringEncoding];
            if(line.length > 0)
            {
                NSRange last = [line rangeOfComposedCharacterSequenceAtIndex:line.length - 1];
                NSData *kept = [[line substringToIndex:last.location] dataUsingEncoding:NSUTF8StringEncoding];
                self.forkJobLine = [kept mutableCopy];
                [self forkJobPrint:@"\b \b"];
            }
            continue;
        }
        if(c == 0x03)
        {
            [self.forkJobLine setLength:0];
            [self forkJobPrint:@"^C\n"];
            [self forkJobPrompt];
            continue;
        }
        if(c == 0x15)
        {
            while(self.forkJobLine.length > 0) [self forkJobInput:[NSData dataWithBytes:"\x7f" length:1]];
            continue;
        }
        if(c == 0x1a)
        {
            if(self.forkJobState == NXForkJobBackground)
            {
                [self forkJobPrint:@"^Z"];
                [self.process sendSignal:SIGTSTP];
            }
            continue;
        }
        if(c < 0x20)
        {
            continue;
        }
        [self.forkJobLine appendBytes:&c length:1];
        write(_tty->userspacefd[SLAVEFD], &c, 1);
    }
}

- (void)forkJobRun:(NSString*)line
{
    NSArray<NSString*> *words = [[line componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet]
                                 filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
    NSString *command = words.firstObject.lowercaseString ?: @"";
    NSString *name = [self forkJobName];
    NSString *status = self.forkJobState == NXForkJobStopped ? @"Stopped" : @"Running";
    
    if(command.length == 0)
    {
        [self forkJobPrompt];
    }
    else if([command isEqualToString:@"fg"] || [command isEqualToString:@"%1"] || [command isEqualToString:@"%"])
    {
        [self forkJobPrint:[NSString stringWithFormat:@"%@\n", name]];
        BOOL wasStopped = self.forkJobState == NXForkJobStopped;
        self.forkJobState = NXForkJobForeground;
        if(wasStopped) [self.process sendSignal:SIGCONT];
        /* a full-screen program draws itself again */
        [self.process sendSignal:SIGWINCH];
    }
    else if([command isEqualToString:@"bg"])
    {
        if(self.forkJobState == NXForkJobBackground)
        {
            [self forkJobPrint:@"bg: the job is already running in the background\n"];
        }
        else
        {
            self.forkJobState = NXForkJobBackground;
            [self.process sendSignal:SIGCONT];
            [self forkJobPrint:[NSString stringWithFormat:@"[1]+ %@ &\n", name]];
        }
        [self forkJobPrompt];
    }
    else if([command isEqualToString:@"jobs"])
    {
        [self forkJobPrint:[NSString stringWithFormat:@"[1]+  %@   %@ (PID %d)\n", status, name, self.process.pid]];
        [self forkJobPrompt];
    }
    else if([command isEqualToString:@"kill"])
    {
        BOOL force = [words containsObject:@"-9"] || [words containsObject:@"-KILL"] || [words containsObject:@"-SIGKILL"];
        [self.process sendSignal:force ? SIGKILL : SIGTERM];
        if(!force && self.forkJobState == NXForkJobStopped)
        {
            /* a stopped program only sees SIGTERM once it runs */
            [self.process sendSignal:SIGCONT];
        }
        [self forkJobPrint:[NSString stringWithFormat:@"[1]+  %@ %@\n", force ? @"Killed" : @"Terminated", name]];
    }
    else if([command isEqualToString:@"exit"] || [command isEqualToString:@"close"])
    {
        [[NXWindowServer shared] closeWindowWithIdentifier:self.windowIdentifier withCompletion:nil];
    }
    else
    {
        if(![command isEqualToString:@"help"]) [self forkJobPrint:[NSString stringWithFormat:@"%@: not a job command\n", words.firstObject]];
        [self forkJobPrint:[NSString stringWithFormat:
            @"Job control of this window (%@, %@):\n"
             "  fg         continue it here (keys go to it again)\n"
             "  bg         continue it in the background (its output still shows)\n"
             "  jobs       its state\n"
             "  kill [-9]  end it (-9: at once)\n"
             "  exit       close the window\n"
             "  ^Z         stops it again while it runs in the background\n", name, status.lowercaseString]];
        [self forkJobPrompt];
    }
}

- (void)forkBringToFront
{
    [[NXWindowServer shared] activateWindowForIdentifier:self.windowIdentifier animated:YES withCompletion:nil];
}

- (void)dealloc
{
    [self forkStopJobControl];
    if(_tty != NULL)
    {
        kvo_release(_tty);
    }

#if DEBUG
    NSLog(@"deallocated %@", self);
#endif /* DEBUG */
}

@end
